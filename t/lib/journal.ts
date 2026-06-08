import { flushRuleset, installRuleset, waitForInstalledRids } from "./bootstrap.js";
import { query, signalWait } from "./engine.js";
import type { RuntimeState } from "./types.js";

export const JOURNAL_RS = "io.picolabs.journal.krl";
export const JOURNAL_RID = "io.picolabs.journal";

export interface JournalEntry {
  timestamp: number;
  title: string;
  content: string;
}

export async function installJournal(
  state: RuntimeState,
  uiEci: string
): Promise<void> {
  await flushRuleset(state, JOURNAL_RS);
  await installRuleset(state, uiEci, JOURNAL_RS);
  await waitForInstalledRids(state, uiEci, [JOURNAL_RID], "Journal host pico");
}

export async function getJournalEntries(
  state: RuntimeState,
  channelEci: string
): Promise<JournalEntry[]> {
  const result = await query<JournalEntry[]>(
    state,
    channelEci,
    JOURNAL_RID,
    "getEntry"
  );
  return Array.isArray(result) ? result : [];
}

export async function findJournalEntryByTitle(
  state: RuntimeState,
  channelEci: string,
  title: string
): Promise<JournalEntry | null> {
  const entries = await getJournalEntries(state, channelEci);
  return entries.find(entry => entry.title === title) ?? null;
}

export async function createJournalEntry(
  state: RuntimeState,
  channelEci: string,
  title: string,
  content: string
): Promise<void> {
  await signalWait(state, channelEci, "journal", "new_entry", { title, content });
}

export async function editJournalEntry(
  state: RuntimeState,
  channelEci: string,
  timestamp: number | string,
  newContent: string
): Promise<void> {
  await signalWait(state, channelEci, "journal", "edit_entry", { timestamp, newContent });
}

export async function deleteJournalEntry(
  state: RuntimeState,
  channelEci: string,
  timestamp: number | string
): Promise<void> {
  await signalWait(state, channelEci, "journal", "delete_entry", { timestamp });
}
