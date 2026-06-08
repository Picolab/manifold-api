import { query, signalWait } from "./engine.js";
import type { RuntimeState } from "./types.js";

export async function getThingWranglerId(
  state: RuntimeState,
  thingQueryEci: string
): Promise<string> {
  const myself = await query<{ id: string }>(
    state,
    thingQueryEci,
    "io.picolabs.wrangler",
    "myself"
  );
  if (!myself?.id) {
    throw new Error(`Could not resolve wrangler id on ${thingQueryEci}`);
  }
  return myself.id;
}

export interface SafeAndMineContactInfo {
  name?: string;
  email?: string;
  phone?: string;
  message?: string;
  shareName?: boolean;
  sharePhone?: boolean;
  shareEmail?: boolean;
}

/** Thing Manifold subscription channel (queryable; required for SafeAndMine events/queries). */
export async function updateContactInfo(
  state: RuntimeState,
  thingQueryEci: string,
  info: SafeAndMineContactInfo
): Promise<void> {
  await signalWait(state, thingQueryEci, "safeandmine", "update", info);
}

export async function getContactInfo(
  state: RuntimeState,
  thingQueryEci: string
): Promise<SafeAndMineContactInfo> {
  return query<SafeAndMineContactInfo>(
    state,
    thingQueryEci,
    "io.picolabs.safeandmine",
    "getInformation"
  );
}

export async function notifyTagScan(
  state: RuntimeState,
  thingQueryEci: string,
  tagID: string
): Promise<void> {
  await signalWait(state, thingQueryEci, "safeandmine", "notify", { tagID });
}
