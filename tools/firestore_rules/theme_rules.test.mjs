import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-notessync',
    firestore: { rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

test('the owner can create, read, and update a theme preference', async () => {
  const database = environment.authenticatedContext('alice').firestore();
  const preference = doc(database, 'users/alice/preferences/theme');
  await assertSucceeds(setDoc(preference, { theme: 'dark', updatedAt: 10 }));
  await assertSucceeds(getDoc(preference));
  await assertSucceeds(setDoc(preference, { theme: 'light', updatedAt: 20 }));
});

test('unauthenticated and other-account requests are denied', async () => {
  for (const context of [environment.unauthenticatedContext(), environment.authenticatedContext('bob')]) {
    const preference = doc(context.firestore(), 'users/alice/preferences/theme');
    await assertFails(getDoc(preference));
    await assertFails(setDoc(preference, { theme: 'dark', updatedAt: 10 }));
  }
});

test('invalid fields, modes, and timestamps are denied', async () => {
  const database = environment.authenticatedContext('alice').firestore();
  const preference = doc(database, 'users/alice/preferences/theme');
  for (const value of [
    { theme: 'unknown', updatedAt: 10 },
    { theme: 'dark', updatedAt: 'invalid' },
    { theme: 'dark', updatedAt: -1 },
    { theme: 'dark' },
    { theme: 'dark', updatedAt: 10, extra: true },
  ]) {
    await assertFails(setDoc(preference, value));
  }
});

test('existing note ownership permissions remain intact', async () => {
  const owner = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(owner, 'users/alice/notes/note-1'), { title: 'Test note' }));
  const other = environment.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(other, 'users/alice/notes/note-1')));
  await assertFails(setDoc(doc(owner, 'unrelated/document'), { value: true }));
});
