import {
  findChildUiByName,
  getInstalledRids,
  waitForInstalledRids,
  type ManifoldBootstrapContext,
} from "./bootstrap.js";
import { query, signalWait, waitFor } from "./engine.js";
import type { RuntimeState } from "./types.js";

export interface ManifoldSubscription {
  Id: string;
  Tx: string;
  Rx: string;
  Tx_role: string;
  Rx_role: string;
  name?: string;
  description?: string;
  picoID?: string;
  id?: string;
}

export interface ManifoldThingEntry extends ManifoldSubscription {
  name: string;
  subID: string;
  picoID: string;
  color?: string;
}

export interface ManifoldCommunityEntry extends ManifoldSubscription {
  name: string;
  subID: string;
  picoID: string;
  color?: string;
}

export interface ThingCommunityContext {
  thingName: string;
  communityName: string;
  communityDescription: string;
  thingPicoId: string;
  communityPicoId: string;
  thingUiEci: string;
  communityUiEci: string;
  /** Manifold↔thing subscription channel on the thing (queryable). */
  thingQueryEci: string;
  /** Manifold↔community subscription channel on the community (queryable). */
  communityQueryEci: string;
  manifoldAppEci: string;
}

interface PicoChannel {
  id: string;
  name?: string;
  tags?: string[];
}

interface PicoDetails {
  children: string[];
  channels: PicoChannel[];
}

const MANIFOLD_APP_CHANNEL = "Manifold";
const MANIFOLD_APP_TAG = "manifold";

export async function getManifoldAppEci(
  state: RuntimeState,
  manifoldUiEci: string
): Promise<string> {
  const pico = await query<PicoDetails>(
    state,
    manifoldUiEci,
    "io.picolabs.pico-engine-ui",
    "pico"
  );
  const channel = pico.channels.find(
    c =>
      c.name === MANIFOLD_APP_CHANNEL ||
      c.tags?.includes(MANIFOLD_APP_CHANNEL) ||
      c.tags?.includes(MANIFOLD_APP_TAG)
  );
  if (!channel) {
    throw new Error(`Manifold app channel not found on ${manifoldUiEci}`);
  }
  return channel.id;
}

export async function getThings(
  state: RuntimeState,
  manifoldAppEci: string
): Promise<Record<string, ManifoldThingEntry>> {
  return query<Record<string, ManifoldThingEntry>>(
    state,
    manifoldAppEci,
    "io.picolabs.manifold_pico",
    "getThings"
  );
}

export async function getCommunities(
  state: RuntimeState,
  manifoldAppEci: string
): Promise<Record<string, ManifoldCommunityEntry>> {
  return query<Record<string, ManifoldCommunityEntry>>(
    state,
    manifoldAppEci,
    "io.picolabs.manifold_pico",
    "getCommunities"
  );
}

export async function getThingCommunities(
  state: RuntimeState,
  thingQueryEci: string
): Promise<ManifoldSubscription[]> {
  return query<ManifoldSubscription[]>(
    state,
    thingQueryEci,
    "io.picolabs.thing",
    "communities"
  );
}

export async function getCommunityThings(
  state: RuntimeState,
  communityQueryEci: string
): Promise<ManifoldSubscription[]> {
  return query<ManifoldSubscription[]>(
    state,
    communityQueryEci,
    "io.picolabs.community",
    "things"
  );
}

export async function getCommunityDescription(
  state: RuntimeState,
  communityQueryEci: string
): Promise<string | null> {
  return query<string | null>(
    state,
    communityQueryEci,
    "io.picolabs.community",
    "description"
  );
}

async function waitForThingEntry(
  state: RuntimeState,
  manifoldAppEci: string,
  name: string
): Promise<ManifoldThingEntry> {
  return waitFor(
    async () => {
      const things = await getThings(state, manifoldAppEci);
      const entry = Object.values(things).find(t => t.name === name);
      if (entry?.picoID && entry.subID && entry.Tx && entry.Id) {
        return entry;
      }
      return null;
    },
    { timeoutMs: 120_000, intervalMs: 500, label: `thing "${name}" in Manifold` }
  );
}

async function waitForCommunityEntry(
  state: RuntimeState,
  manifoldAppEci: string,
  name: string
): Promise<ManifoldCommunityEntry> {
  return waitFor(
    async () => {
      const communities = await getCommunities(state, manifoldAppEci);
      const entry = Object.values(communities).find(c => c.name === name);
      if (entry?.picoID && entry.subID && entry.Tx && entry.Id) {
        return entry;
      }
      return null;
    },
    { timeoutMs: 120_000, intervalMs: 500, label: `community "${name}" in Manifold` }
  );
}

export async function createThing(
  state: RuntimeState,
  bootstrap: ManifoldBootstrapContext,
  name: string
): Promise<{ entry: ManifoldThingEntry; uiEci: string; appEci: string }> {
  const appEci = await getManifoldAppEci(state, bootstrap.manifoldUiEci);
  await signalWait(state, appEci, "manifold", "create_thing", { name });

  const entry = await waitForThingEntry(state, appEci, name);
  const uiEci = await waitFor(
    async () => findChildUiByName(state, bootstrap.manifoldUiEci, name),
    { timeoutMs: 120_000, label: `thing child UI "${name}"` }
  );

  return { entry, uiEci, appEci };
}

export async function createCommunity(
  state: RuntimeState,
  bootstrap: ManifoldBootstrapContext,
  name: string,
  description: string
): Promise<{ entry: ManifoldCommunityEntry; uiEci: string; appEci: string }> {
  const appEci = await getManifoldAppEci(state, bootstrap.manifoldUiEci);
  await signalWait(state, appEci, "manifold", "new_community", { name, description });

  const entry = await waitForCommunityEntry(state, appEci, name);
  const uiEci = await waitFor(
    async () => findChildUiByName(state, bootstrap.manifoldUiEci, name),
    { timeoutMs: 120_000, label: `community child UI "${name}"` }
  );

  return { entry, uiEci, appEci };
}

export async function addThingToCommunity(
  state: RuntimeState,
  bootstrap: ManifoldBootstrapContext,
  thingPicoId: string,
  communityPicoId: string
): Promise<void> {
  const appEci = await getManifoldAppEci(state, bootstrap.manifoldUiEci);
  await signalWait(state, appEci, "manifold", "add_thing_to_community", {
    thingPicoID: thingPicoId,
    communityPicoID: communityPicoId,
  });
}

export async function removeThingFromCommunity(
  state: RuntimeState,
  bootstrap: ManifoldBootstrapContext,
  thingPicoId: string,
  communityPicoId: string
): Promise<void> {
  const appEci = await getManifoldAppEci(state, bootstrap.manifoldUiEci);
  await signalWait(state, appEci, "manifold", "remove_thing_from_community", {
    thingPicoID: thingPicoId,
    communityPicoID: communityPicoId,
  });
}

export async function deleteThing(
  state: RuntimeState,
  bootstrap: ManifoldBootstrapContext,
  appEci: string,
  picoId: string
): Promise<void> {
  await signalWait(state, appEci, "manifold", "remove_thing", { picoID: picoId });
  await waitFor(
    async () => {
      const things = await getThings(state, appEci);
      return things[picoId] ? null : true;
    },
    { timeoutMs: 120_000, label: `thing ${picoId} removed from Manifold` }
  );
}

export async function deleteCommunity(
  state: RuntimeState,
  bootstrap: ManifoldBootstrapContext,
  appEci: string,
  picoId: string
): Promise<void> {
  await signalWait(state, appEci, "manifold", "remove_community", { picoID: picoId });
  await waitFor(
    async () => {
      const communities = await getCommunities(state, appEci);
      return communities[picoId] ? null : true;
    },
    { timeoutMs: 120_000, label: `community ${picoId} removed from Manifold` }
  );
}

export async function waitForCommunityMembership(
  state: RuntimeState,
  thingQueryEci: string,
  communityQueryEci: string,
  expectPresent: boolean
): Promise<void> {
  await waitFor(
    async () => {
      const onThing = await getThingCommunities(state, thingQueryEci);
      const onCommunity = await getCommunityThings(state, communityQueryEci);
      if (expectPresent) {
        const thingHas = onThing.some(s => s.Tx_role === "community");
        const communityHas = onCommunity.some(s => s.Tx_role === "thing");
        return thingHas && communityHas ? true : null;
      }
      return onThing.length === 0 && onCommunity.length === 0 ? true : null;
    },
    {
      timeoutMs: 120_000,
      intervalMs: 500,
      label: expectPresent
        ? "community–thing subscription established"
        : "community–thing subscription removed",
    }
  );
}

export async function assertChildGone(
  state: RuntimeState,
  manifoldUiEci: string,
  name: string
): Promise<void> {
  const uiEci = await findChildUiByName(state, manifoldUiEci, name);
  if (uiEci) {
    throw new Error(`Expected child "${name}" to be deleted but UI ECI ${uiEci} still exists`);
  }
}

export { waitForInstalledRids, getInstalledRids };
