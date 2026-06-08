import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  createJournalEntry,
  deleteJournalEntry,
  editJournalEntry,
  findJournalEntryByTitle,
  getJournalEntries,
  installJournal,
} from "../lib/journal.js";
import { createThing, deleteThing } from "../lib/manifold.js";
import { getTestBootstrap, getTestState } from "../lib/test-context.js";

const THING_NAME = "Journal Test Thing";
const ENTRY_TITLE = "Integration test entry";
const ENTRY_CONTENT = "Initial journal content.";
const UPDATED_CONTENT = "Updated journal content.";

describe("journal", () => {
  it("installs on a thing pico and supports create, edit, and delete", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const { entry, uiEci, appEci } = await createThing(state, bootstrap, THING_NAME);
    const channelEci = entry.Tx;

    await installJournal(state, uiEci);

    await createJournalEntry(state, channelEci, ENTRY_TITLE, ENTRY_CONTENT);

    const created = await findJournalEntryByTitle(state, channelEci, ENTRY_TITLE);
    assert.ok(created, "journal entry not found after create");
    assert.equal(created.title, ENTRY_TITLE);
    assert.equal(created.content, ENTRY_CONTENT);
    assert.ok(created.timestamp, "entry timestamp missing");

    await editJournalEntry(state, channelEci, created.timestamp, UPDATED_CONTENT);

    const edited = await findJournalEntryByTitle(state, channelEci, ENTRY_TITLE);
    assert.ok(edited, "journal entry missing after edit");
    assert.equal(edited.content, UPDATED_CONTENT);
    assert.equal(edited.timestamp, created.timestamp);

    await deleteJournalEntry(state, channelEci, created.timestamp);

    const remaining = await getJournalEntries(state, channelEci);
    assert.equal(
      remaining.find(entry => entry.timestamp === created.timestamp),
      undefined,
      "deleted entry still present in journal list"
    );

    await deleteThing(state, bootstrap, appEci, entry.picoID);
  });
});
