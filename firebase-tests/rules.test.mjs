// Security-rule tests for Friends, run against the Firestore emulator:
//   cd firebase-tests && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc, query, where, getDocs, writeBatch } from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const challenge = (over = {}) => ({
  code: 'K7Q2MX', fromUid: 'asha', fromName: 'Asha', fromTitle: null, toUid: null, toName: null, toTitle: null,
  exercise: 'pushUp', reps: 10, arcLabel: 'Winter Arc 2026', status: 'open', fromDone: false, toDone: false,
  createdAt: 1, ...over,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-fit-tracker',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

test('profiles: anyone signed in reads; only you write yours', async () => {
  await assertSucceeds(setDoc(doc(as('asha'), 'users/asha'), { name: 'Asha', xp: 10 }));
  await assertFails(setDoc(doc(as('ravi'), 'users/asha'), { name: 'Hacked', xp: 99999 }));
  await assertFails(setDoc(doc(as('asha'), 'users/asha'), { name: 'x'.repeat(41), xp: 1 }));
  await assertSucceeds(getDoc(doc(as('ravi'), 'users/asha')));
  await assertFails(getDoc(doc(anon(), 'users/asha')));
});

test('the full challenge: create, join, both finish, become friends', async () => {
  const a = as('asha'), r = as('ravi');
  await assertSucceeds(setDoc(doc(a, 'challenges/c1'), challenge()));
  // Ravi finds it by code.
  await assertSucceeds(getDocs(query(collection(r, 'challenges'), where('code', '==', 'K7Q2MX'), where('status', '==', 'open'))));
  // Asha can't join her own.
  await assertFails(updateDoc(doc(a, 'challenges/c1'), { toUid: 'asha', toName: 'Asha', toTitle: null, status: 'accepted' }));
  await assertSucceeds(updateDoc(doc(r, 'challenges/c1'), { toUid: 'ravi', toName: 'Ravi', toTitle: null, status: 'accepted' }));
  // Meena can't take it over or see it now.
  await assertFails(updateDoc(doc(as('meena'), 'challenges/c1'), { toUid: 'meena', status: 'accepted' }));
  await assertFails(getDoc(doc(as('meena'), 'challenges/c1')));
  // Ravi can't tick Asha's part, or finish it alone.
  await assertFails(updateDoc(doc(r, 'challenges/c1'), { fromDone: true }));
  await assertFails(updateDoc(doc(r, 'challenges/c1'), { toDone: true, status: 'done' }));
  await assertSucceeds(updateDoc(doc(r, 'challenges/c1'), { toDone: true }));
  // Friendship before it's done: refused.
  await assertFails(setDoc(doc(a, 'users/asha/friends/ravi'), { via: 'c1', since: 1 }));
  await assertSucceeds(updateDoc(doc(a, 'challenges/c1'), { fromDone: true, status: 'done' }));
  // Now Asha writes both sides.
  const batch = writeBatch(a);
  batch.set(doc(a, 'users/asha/friends/ravi'), { via: 'c1', since: 1 });
  batch.set(doc(a, 'users/ravi/friends/asha'), { via: 'c1', since: 1 });
  await assertSucceeds(batch.commit());
  // A stranger can't fake a friendship using someone else's challenge.
  await assertFails(setDoc(doc(as('meena'), 'users/meena/friends/asha'), { via: 'c1', since: 1 }));
  // Either friend can unfriend.
  await assertSucceeds(deleteDoc(doc(r, 'users/asha/friends/ravi')));
});

test('cheating the numbers is refused', async () => {
  const a = as('asha');
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ fromUid: 'ravi' })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ reps: 5000 })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ fromDone: true })));
  await assertFails(setDoc(doc(a, 'challenges/c2'), challenge({ status: 'done' })));
});

test('direct challenges only go to friends', async () => {
  const a = as('asha');
  await assertFails(setDoc(doc(a, 'challenges/c3'), challenge({ toUid: 'ravi', toName: 'Ravi', status: 'accepted' })));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/asha/friends/ravi'), { via: 'x', since: 1 });
  });
  await assertSucceeds(setDoc(doc(a, 'challenges/c3'), challenge({ toUid: 'ravi', toName: 'Ravi', status: 'accepted' })));
});

test('blocking and reports', async () => {
  await assertSucceeds(setDoc(doc(as('ravi'), 'users/ravi/blocked/asha'), { at: 1 }));
  await assertSucceeds(getDoc(doc(as('asha'), 'users/ravi/blocked/asha')));
  await assertFails(getDoc(doc(as('meena'), 'users/ravi/blocked/asha')));
  await assertFails(setDoc(doc(as('asha'), 'users/ravi/blocked/asha'), { at: 2 }));
  await assertSucceeds(addDoc(collection(as('ravi'), 'reports'), { by: 'ravi', about: 'asha', reason: 'spam' }));
  await assertFails(addDoc(collection(as('ravi'), 'reports'), { by: 'asha', about: 'ravi', reason: 'fake' }));
  await assertFails(getDocs(collection(as('ravi'), 'reports')));
});
