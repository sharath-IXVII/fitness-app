// Security-rule tests for Friends, run against the Firestore emulator:
//   cd firebase-tests && npm install && npm test
import assert from 'node:assert/strict';
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

const day = (over = {}) => ({ workout: true, water: 2500, steps: 9000, meals: 3, protein: 80, ...over });
const state = (over = {}) => ({
  profile: { name: 'Asha', age: 28 }, badges: { 'streak7:1': '2026-10-09' }, firstUse: '2026-10-01', waterGoal: 2800,
  updatedAt: serverTimestamp(), ...over,
});

test('progress backup: private to the owner, and the shape and sizes are checked', async () => {
  const a = as('asha');
  await assertSucceeds(setDoc(doc(a, 'users/asha/days/2026-10-02'), day()));
  await assertSucceeds(getDoc(doc(a, 'users/asha/days/2026-10-02')));
  await assertSucceeds(getDocs(collection(a, 'users/asha/days')));
  // Nobody else can read it, list it or write it, and signed-out users can't either.
  await assertFails(getDoc(doc(as('ravi'), 'users/asha/days/2026-10-02')));
  await assertFails(getDocs(collection(as('ravi'), 'users/asha/days')));
  await assertFails(setDoc(doc(as('ravi'), 'users/asha/days/2026-10-03'), day()));
  await assertFails(getDoc(doc(anon(), 'users/asha/days/2026-10-02')));
  // Bad ids, extra fields and silly numbers are refused.
  await assertFails(setDoc(doc(a, 'users/asha/days/yesterday'), day()));
  await assertFails(setDoc(doc(a, 'users/asha/days/2026-10-04'), day({ evil: 1 })));
  await assertFails(setDoc(doc(a, 'users/asha/days/2026-10-04'), day({ steps: 9999999 })));
  await assertFails(setDoc(doc(a, 'users/asha/days/2026-10-04'), day({ workout: 'yes' })));
  // The owner can delete it (account deletion).
  await assertSucceeds(deleteDoc(doc(a, 'users/asha/days/2026-10-02')));
});

test('progress backup: the state document', async () => {
  const a = as('asha');
  await assertSucceeds(setDoc(doc(a, 'users/asha/backup/state'), state()));
  const noGoal = state();
  delete noGoal.waterGoal; // the water goal is optional
  await assertSucceeds(setDoc(doc(a, 'users/asha/backup/state'), noGoal));
  await assertFails(getDoc(doc(as('ravi'), 'users/asha/backup/state')));
  await assertFails(setDoc(doc(as('ravi'), 'users/asha/backup/state'), state()));
  await assertFails(setDoc(doc(a, 'users/asha/backup/other'), state()));
  await assertFails(setDoc(doc(a, 'users/asha/backup/state'), state({ waterGoal: 99999 })));
  await assertFails(setDoc(doc(a, 'users/asha/backup/state'), state({ firstUse: 'long ago' })));
  await assertFails(setDoc(doc(a, 'users/asha/backup/state'), state({ extra: 'x' })));
  await assertFails(setDoc(doc(a, 'users/asha/backup/state'), state({ badges: 'all of them' })));
  await assertFails(setDoc(doc(a, 'users/asha/backup/state'), state({ updatedAt: 5 })));
  await assertSucceeds(deleteDoc(doc(a, 'users/asha/backup/state')));
});

// ---------------------------------------------------------- friend requests

const FR = ['asha', 'ravi', 'meena'];
const request = (over = {}) => ({ name: 'Asha', title: null, at: serverTimestamp(), ...over });

test('friend codes: yours to create and delete, anyone can look one up, nobody can list them all', async () => {
  const a = as('asha');
  await assertSucceeds(setDoc(doc(a, 'friendCodes/K7Q2MX'), { uid: 'asha' }));
  await assertFails(setDoc(doc(as('ravi'), 'friendCodes/ABCDEF'), { uid: 'asha' })); // not their own
  await assertFails(setDoc(doc(a, 'friendCodes/abc'), { uid: 'asha' })); // wrong shape
  await assertFails(setDoc(doc(a, 'friendCodes/K7Q2M0'), { uid: 'asha' })); // 0 is not in the alphabet
  await assertFails(setDoc(doc(a, 'friendCodes/ZZZZZZ'), { uid: 'asha', extra: 1 }));
  await assertSucceeds(getDoc(doc(as('ravi'), 'friendCodes/K7Q2MX')));
  await assertFails(getDoc(doc(anon(), 'friendCodes/K7Q2MX')));
  await assertFails(getDocs(collection(as('ravi'), 'friendCodes')));
  await assertSucceeds(getDocs(query(collection(a, 'friendCodes'), where('uid', '==', 'asha'))));
  await assertFails(getDocs(query(collection(as('ravi'), 'friendCodes'), where('uid', '==', 'asha'))));
  await assertFails(deleteDoc(doc(as('ravi'), 'friendCodes/K7Q2MX')));
  await assertSucceeds(deleteDoc(doc(a, 'friendCodes/K7Q2MX')));
});

test('friend requests: only the asker sends one, only the two people can see it', async () => {
  const a = as('asha');
  await assertSucceeds(setDoc(doc(a, 'users/ravi/requests/asha'), request()));
  await assertFails(setDoc(doc(as('meena'), 'users/ravi/requests/asha'), request())); // pretending to be asha
  await assertFails(setDoc(doc(a, 'users/asha/requests/asha'), request())); // yourself
  await assertFails(setDoc(doc(a, 'users/meena/requests/asha'), request({ name: 'x'.repeat(41) })));
  await assertFails(setDoc(doc(a, 'users/meena/requests/asha'), request({ extra: true })));
  await assertFails(setDoc(doc(anon(), 'users/meena/requests/asha'), request()));
  await assertSucceeds(getDoc(doc(as('ravi'), 'users/ravi/requests/asha')));
  await assertSucceeds(getDocs(collection(as('ravi'), 'users/ravi/requests')));
  await assertSucceeds(getDoc(doc(a, 'users/ravi/requests/asha'))); // the asker can see their own
  await assertFails(getDoc(doc(as('meena'), 'users/ravi/requests/asha')));
  await assertFails(getDocs(collection(as('meena'), 'users/ravi/requests')));
  await assertFails(getDocs(collection(a, 'users/ravi/requests'))); // the asker cannot read the whole inbox
});

test('friend requests: a person who blocked you cannot be asked', async () => {
  await asAdmin((db) => setDoc(doc(db, 'users/ravi/blocked/asha'), { at: 1 }));
  await assertFails(setDoc(doc(as('asha'), 'users/ravi/requests/asha'), request()));
  await asAdmin((db) => setDoc(doc(db, 'users/asha/blocked/meena'), { at: 1 }));
  await assertFails(setDoc(doc(as('meena'), 'users/asha/requests/meena'), request()));
});

test('accepting a request makes both people friends, with no challenge needed', async () => {
  await assertSucceeds(setDoc(doc(as('asha'), 'users/ravi/requests/asha'), request()));
  const r = as('ravi');
  const b = writeBatch(r);
  b.set(doc(r, 'users/ravi/friends/asha'), { since: 5, via: 'request' });
  b.set(doc(r, 'users/asha/friends/ravi'), { since: 5, via: 'request' });
  b.delete(doc(r, 'users/ravi/requests/asha'));
  await assertSucceeds(b.commit());
  await assertSucceeds(getDoc(doc(as('asha'), 'users/asha/friends/ravi')));
  await assertSucceeds(getDoc(doc(r, 'users/ravi/friends/asha')));
  const gone = await getDoc(doc(r, 'users/ravi/requests/asha'));
  assert.equal(gone.exists(), false);
});

test('nobody can make friends without a real request, or by writing for the other person', async () => {
  // No request at all.
  const r = as('ravi');
  const b0 = writeBatch(r);
  b0.set(doc(r, 'users/ravi/friends/asha'), { since: 5, via: 'request' });
  b0.set(doc(r, 'users/asha/friends/ravi'), { since: 5, via: 'request' });
  await assertFails(b0.commit());
  // The asker cannot accept their own request.
  await assertSucceeds(setDoc(doc(as('asha'), 'users/ravi/requests/asha'), request()));
  const a = as('asha');
  const b1 = writeBatch(a);
  b1.set(doc(a, 'users/asha/friends/ravi'), { since: 5, via: 'request' });
  b1.set(doc(a, 'users/ravi/friends/asha'), { since: 5, via: 'request' });
  await assertFails(b1.commit());
  // A third person cannot add anyone.
  const m = as('meena');
  await assertFails(setDoc(doc(m, 'users/ravi/friends/asha'), { since: 5, via: 'request' }));
  // Extra fields or a made-up reason are refused.
  await assertFails(setDoc(doc(r, 'users/ravi/friends/asha'), { since: 5, via: 'request', xp: 9 }));
  await assertFails(setDoc(doc(r, 'users/ravi/friends/asha'), { since: 5, via: 'whatever' }));
  // A blocked asker cannot be befriended even with a leftover request.
  await asAdmin((db) => setDoc(doc(db, 'users/ravi/blocked/asha'), { at: 1 }));
  await assertFails(setDoc(doc(r, 'users/ravi/friends/asha'), { since: 5, via: 'request' }));
});

test('declining or cancelling a request just removes it', async () => {
  await assertSucceeds(setDoc(doc(as('asha'), 'users/ravi/requests/asha'), request()));
  await assertFails(deleteDoc(doc(as('meena'), 'users/ravi/requests/asha')));
  await assertSucceeds(deleteDoc(doc(as('ravi'), 'users/ravi/requests/asha'))); // decline
  await assertSucceeds(setDoc(doc(as('asha'), 'users/ravi/requests/asha'), request()));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'users/ravi/requests/asha'))); // cancel
});

// ------------------------------------------------------------------ clubs
const club = (over = {}) => ({
  name: 'Morning Walkers', about: '6 am at the park', kind: 'walking', ownerUid: 'asha', ownerName: 'Asha',
  createdAt: serverTimestamp(), ...over,
});
const inHours = (h) => new Date(Date.now() + h * 3600 * 1000);
const msg = (over = {}) => ({
  uid: 'ravi', name: 'Ravi', text: 'Walk tomorrow?', at: serverTimestamp(), expireAt: inHours(24), ...over,
});
async function clubWithRavi() {
  await assertSucceeds(setDoc(doc(as('asha'), 'clubs/c1'), club()));
  await assertSucceeds(setDoc(doc(as('asha'), 'clubs/c1/members/asha'), { name: 'Asha', joinedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(as('ravi'), 'clubs/c1/members/ravi'), { name: 'Ravi', joinedAt: serverTimestamp() }));
}

test('clubs: anyone signed in creates and browses; no links in names', async () => {
  await assertFails(setDoc(doc(anon(), 'clubs/c1'), club()));
  await assertFails(setDoc(doc(as('ravi'), 'clubs/c1'), club())); // owner must be you
  await assertFails(setDoc(doc(as('asha'), 'clubs/c1'), club({ about: 'see fitgang.in' })));
  await assertFails(setDoc(doc(as('asha'), 'clubs/c1'), club({ name: 'www.walk' })));
  await assertSucceeds(setDoc(doc(as('asha'), 'clubs/c1'), club()));
  await assertSucceeds(getDocs(collection(as('ravi'), 'clubs')));
  await assertFails(deleteDoc(doc(as('ravi'), 'clubs/c1')));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'clubs/c1')));
});

test('clubs: members chat; no links; messages must expire in a day', async () => {
  await clubWithRavi();
  const ravi = as('ravi');
  await assertSucceeds(addDoc(collection(ravi, 'clubs/c1/messages'), msg()));
  await assertFails(addDoc(collection(ravi, 'clubs/c1/messages'), msg({ text: 'join https://x.co' })));
  await assertFails(addDoc(collection(ravi, 'clubs/c1/messages'), msg({ text: 'wa.me/9198' })));
  await assertFails(addDoc(collection(ravi, 'clubs/c1/messages'), msg({ expireAt: inHours(24 * 30) })));
  await assertFails(addDoc(collection(ravi, 'clubs/c1/messages'), msg({ uid: 'asha' })));
  // Not a member: can't read or write.
  await assertFails(getDocs(collection(as('meera'), 'clubs/c1/messages')));
  await assertFails(addDoc(collection(as('meera'), 'clubs/c1/messages'), msg({ uid: 'meera' })));
  await assertSucceeds(getDocs(collection(ravi, 'clubs/c1/messages')));
});

test('clubs: the owner can delete messages and remove members for good', async () => {
  await clubWithRavi();
  const m = await addDoc(collection(as('ravi'), 'clubs/c1/messages'), msg());
  await assertFails(deleteDoc(doc(as('meera'), m.path)));
  await assertSucceeds(deleteDoc(doc(as('asha'), m.path)));
  await assertSucceeds(setDoc(doc(as('asha'), 'clubs/c1/banned/ravi'), { at: serverTimestamp() }));
  await assertSucceeds(deleteDoc(doc(as('asha'), 'clubs/c1/members/ravi')));
  await assertFails(setDoc(doc(as('ravi'), 'clubs/c1/members/ravi'), { name: 'Ravi', joinedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(as('ravi'), 'clubs/c1/banned/asha'), { at: serverTimestamp() }));
});

test('club challenges: only the admin sets them; finishes must be real and only improve', async () => {
  await clubWithRavi();
  const now = Date.now();
  const ch = {
    title: 'Run 8 km', kind: 'run', distanceM: 8000, startsAt: new Date(now - 60000), endsAt: new Date(now + 86400000),
    startName: 'Lake gate', createdBy: 'asha', createdAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(as('ravi'), 'clubs/c1/challenges/x1'), { ...ch, createdBy: 'ravi' }));
  await assertFails(setDoc(doc(as('asha'), 'clubs/c1/challenges/x1'), { ...ch, title: 'go to x.com' }));
  await assertFails(setDoc(doc(as('asha'), 'clubs/c1/challenges/x1'), { ...ch, distanceM: 200 }));
  await assertFails(setDoc(doc(as('asha'), 'clubs/c1/challenges/x0'), { ...ch, finish: 'the lake' }));
  await assertFails(setDoc(doc(as('asha'), 'clubs/c1/challenges/x2'), { ...ch, plan: 'north' }));
  await assertSucceeds(setDoc(doc(as('asha'), 'clubs/c1/challenges/x3'), { ...ch, plan: [] }));
  await assertSucceeds(setDoc(doc(as('asha'), 'clubs/c1/challenges/x1'), ch));
  await assertFails(getDoc(doc(as('meera'), 'clubs/c1/challenges/x1')));

  const res = (timeMs, distanceM = 8000) => ({ name: 'Ravi', timeMs, distanceM, at: serverTimestamp() });
  const r = doc(as('ravi'), 'clubs/c1/challenges/x1/results/ravi');
  await assertFails(setDoc(r, res(40 * 60000, 5000))); // not the full distance
  await assertFails(setDoc(r, res(10 * 60000))); // 8 km in 10 min: 48 km/h
  await assertFails(setDoc(doc(as('ravi'), 'clubs/c1/challenges/x1/results/asha'), res(45 * 60000)));
  await assertSucceeds(setDoc(r, res(45 * 60000)));
  await assertFails(setDoc(r, res(50 * 60000))); // slower doesn't replace
  await assertSucceeds(setDoc(r, res(42 * 60000)));
  await assertSucceeds(getDocs(collection(as('asha'), 'clubs/c1/challenges/x1/results')));
});
