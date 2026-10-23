// Security-rule tests for Friends, run against the Firestore emulator:
//   cd firebase-tests && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc, query, where, getDocs, writeBatch, serverTimestamp,
} from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const profile = (over = {}) => ({
  name: 'Asha', title: null, titleTier: null, titleSeason: null, level: 3, xp: 400, streak: 2, bestStreak: 5,
  arcLabel: 'Winter Arc 2026', arcActive: 12, workoutsWeek: 1, updatedAt: serverTimestamp(), ...over,
});
const challenge = (over = {}) => ({
  code: 'K7Q2MX', fromUid: 'asha', fromName: 'Asha', fromTitle: null, toUid: null, toName: null, toTitle: null,
  exercise: 'pushUp', reps: 10, arcLabel: 'Winter Arc 2026', status: 'open', fromDone: false, toDone: false,
  createdAt: 1, ...over,
});
// The app creates the challenge and its code in one batch.
async function openChallenge(db, id = 'c1', over = {}) {
  const b = writeBatch(db);
  b.set(doc(db, `challenges/${id}`), challenge(over));
  b.set(doc(db, `codes/${over.code ?? 'K7Q2MX'}`), { challengeId: id, fromUid: over.fromUid ?? 'asha' });
  return b.commit();
}
const asAdmin = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-fit-tracker',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

test('profiles: fetch one, never list all; only you write yours, with sane values', async () => {
  await assertSucceeds(setDoc(doc(as('asha'), 'users/asha'), profile()));
  await assertFails(setDoc(doc(as('ravi'), 'users/asha'), profile({ name: 'Hacked' })));
  await assertFails(setDoc(doc(as('asha'), 'users/asha'), profile({ name: 'x'.repeat(41) })));
  await assertFails(setDoc(doc(as('asha'), 'users/asha'), profile({ level: 'x' })));
  await assertFails(setDoc(doc(as('asha'), 'users/asha'), profile({ evil: true })));
  await assertSucceeds(getDoc(doc(as('ravi'), 'users/asha')));
  await assertFails(getDocs(collection(as('ravi'), 'users')));
  await assertFails(getDoc(doc(anon(), 'users/asha')));
});

test('XP can only grow at a believable pace', async () => {
  const a = as('asha');
  await assertFails(setDoc(doc(a, 'users/asha'), profile({ xp: 9000000 })));
  await assertSucceeds(setDoc(doc(a, 'users/asha'), profile({ xp: 400 })));
  await assertSucceeds(setDoc(doc(a, 'users/asha'), profile({ xp: 520 })));
  await assertFails(setDoc(doc(a, 'users/asha'), profile({ xp: 99999 })));
});

test('the full challenge: share a code, join, both finish, become friends', async () => {
  const a = as('asha'), r = as('ravi');
  await assertSucceeds(openChallenge(a));
  // Ravi looks the code up, then fetches that challenge.
  await assertSucceeds(getDoc(doc(r, 'codes/K7Q2MX')));
  await assertSucceeds(getDoc(doc(r, 'challenges/c1')));
  // But nobody can list open challenges to grab them.
  await assertFails(getDocs(query(collection(r, 'challenges'), where('status', '==', 'open'))));
  await assertFails(getDocs(collection(r, 'codes')));
  // Asha can't join her own; Ravi joins with a proper name.
  await assertFails(updateDoc(doc(a, 'challenges/c1'), { toUid: 'asha', toName: 'Asha', toTitle: null, status: 'accepted' }));
  await assertFails(updateDoc(doc(r, 'challenges/c1'), { toUid: 'ravi', toName: 123, toTitle: null, status: 'accepted' }));
  await assertSucceeds(updateDoc(doc(r, 'challenges/c1'), { toUid: 'ravi', toName: 'Ravi', toTitle: null, status: 'accepted' }));
  // Their own list query works.
  await assertSucceeds(getDocs(query(collection(r, 'challenges'), where('toUid', '==', 'ravi'))));
  // Meena can't take it over or see it now.
  await assertFails(updateDoc(doc(as('meena'), 'challenges/c1'), { toUid: 'meena', status: 'accepted' }));
  await assertFails(getDoc(doc(as('meena'), 'challenges/c1')));
  // Ravi can't tick Asha's part, or finish it alone.
  await assertFails(updateDoc(doc(r, 'challenges/c1'), { fromDone: true }));
  await assertFails(updateDoc(doc(r, 'challenges/c1'), { toDone: true, status: 'done' }));
  await assertSucceeds(updateDoc(doc(r, 'challenges/c1'), { toDone: true }));
  await assertFails(setDoc(doc(a, 'users/asha/friends/ravi'), { via: 'c1', since: 1 }));
  await assertSucceeds(updateDoc(doc(a, 'challenges/c1'), { fromDone: true, status: 'done' }));
  const batch = writeBatch(a);
  batch.set(doc(a, 'users/asha/friends/ravi'), { via: 'c1', since: 1 });
  batch.set(doc(a, 'users/ravi/friends/asha'), { via: 'c1', since: 1 });
  await assertSucceeds(batch.commit());
  // Writing it again (a second challenge, or a retry) is fine.
  await assertSucceeds(setDoc(doc(r, 'users/ravi/friends/asha'), { via: 'c1', since: 1 }));
  // A finished challenge can't be declined afterwards.
  await assertFails(updateDoc(doc(r, 'challenges/c1'), { status: 'declined' }));
  // A stranger can't fake a friendship using someone else's challenge.
  await assertFails(setDoc(doc(as('meena'), 'users/meena/friends/asha'), { via: 'c1', since: 1 }));
  await assertSucceeds(deleteDoc(doc(r, 'users/asha/friends/ravi')));
});

test('blocking sticks: no re-friending, no joining, no direct challenges', async () => {
  await asAdmin(async (db) => {
    await setDoc(doc(db, 'challenges/old'), challenge({ toUid: 'ravi', toName: 'Ravi', status: 'done', fromDone: true, toDone: true }));
    await setDoc(doc(db, 'users/asha/friends/ravi'), { via: 'old', since: 1 });
  });
  await assertSucceeds(setDoc(doc(as('asha'), 'users/asha/blocked/ravi'), { at: 1 }));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'users/asha/friends/ravi')));
  // Ravi tries to restore the friendship with the old challenge.
  await assertFails(setDoc(doc(as('ravi'), 'users/asha/friends/ravi'), { via: 'old', since: 1 }));
  await assertFails(setDoc(doc(as('ravi'), 'users/ravi/friends/asha'), { via: 'old', since: 1 }));
  // Or joins her new open challenge.
  await assertSucceeds(openChallenge(as('asha'), 'c2', { code: 'ABCDEF' }));
  await assertFails(updateDoc(doc(as('ravi'), 'challenges/c2'), { toUid: 'ravi', toName: 'Ravi', toTitle: null, status: 'accepted' }));
});

test('cheating the numbers or the shape is refused', async () => {
  const a = as('asha');
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ fromUid: 'ravi' })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ reps: 5000 })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ fromDone: true })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ status: 'done' })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ exercise: 'nap' })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ fromName: 42 })));
  // A code can only point at your own challenge.
  await asAdmin((db) => setDoc(doc(db, 'challenges/theirs'), challenge({ fromUid: 'ravi' })));
  await assertFails(setDoc(doc(a, 'codes/K7Q2MX'), { challengeId: 'theirs', fromUid: 'asha' }));
});

test('direct challenges only go to friends', async () => {
  const a = as('asha');
  await assertFails(setDoc(doc(a, 'challenges/c3'), challenge({ toUid: 'ravi', toName: 'Ravi', status: 'accepted' })));
  await asAdmin((db) => setDoc(doc(db, 'users/asha/friends/ravi'), { via: 'x', since: 1 }));
  await assertSucceeds(setDoc(doc(a, 'challenges/c3'), challenge({ toUid: 'ravi', toName: 'Ravi', status: 'accepted' })));
});

test('reports, and deleting your challenges', async () => {
  await assertSucceeds(addDoc(collection(as('ravi'), 'reports'), { by: 'ravi', about: 'asha', reason: 'spam' }));
  await assertFails(addDoc(collection(as('ravi'), 'reports'), { by: 'asha', about: 'ravi', reason: 'fake' }));
  await assertFails(getDocs(collection(as('ravi'), 'reports')));
  await assertSucceeds(openChallenge(as('asha')));
  await assertFails(deleteDoc(doc(as('ravi'), 'challenges/c1')));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'codes/K7Q2MX')));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'challenges/c1')));
});
