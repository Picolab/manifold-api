import { query, signalWait, waitFor } from "./engine.js";
import type { RuntimeState } from "./types.js";

export const TAG_REGISTRY_RID = "io.picolabs.new_tag_registry";

/** SafeAndMine tag domain used in integration tests. */
export const SAFEANDMINE_TAG_DOMAIN = "sqtg";

export interface TagRegistryEntry {
  did: string;
  pico_host?: string;
  redirect_url?: string;
}

export async function getTagRegistryStore(
  state: RuntimeState,
  registrationEci: string
): Promise<Record<string, Record<string, TagRegistryEntry>>> {
  return query<Record<string, Record<string, TagRegistryEntry>>>(
    state,
    registrationEci,
    TAG_REGISTRY_RID,
    "get_tag_store"
  );
}

export async function scanRegistryTag(
  state: RuntimeState,
  registrationEci: string,
  tagID: string,
  domain: string
): Promise<TagRegistryEntry | null> {
  const result = await query<TagRegistryEntry | null>(
    state,
    registrationEci,
    TAG_REGISTRY_RID,
    "scan_tag",
    { tagID, domain }
  );
  if (result && typeof result === "object" && "error" in result) {
    return null;
  }
  return result ?? null;
}

export async function addTagToThing(
  state: RuntimeState,
  thingQueryEci: string,
  tagID: string,
  domain: string = SAFEANDMINE_TAG_DOMAIN
): Promise<void> {
  await signalWait(state, thingQueryEci, "safeandmine", "new_tag", { tagID, domain });
}

export async function removeTagFromThing(
  state: RuntimeState,
  thingQueryEci: string,
  tagID: string,
  domain: string = SAFEANDMINE_TAG_DOMAIN
): Promise<void> {
  await signalWait(state, thingQueryEci, "safeandmine", "deregister", { tagID, domain });
}

export async function waitForRegistryTag(
  state: RuntimeState,
  registrationEci: string,
  tagID: string,
  domain: string,
  expectPresent: boolean
): Promise<TagRegistryEntry | true> {
  return waitFor(
    async () => {
      const entry = await scanRegistryTag(state, registrationEci, tagID, domain);
      if (expectPresent) {
        return entry?.did ? entry : null;
      }
      return entry?.did ? null : true;
    },
    {
      timeoutMs: 60_000,
      intervalMs: 500,
      label: expectPresent
        ? `tag ${tagID} registered in tag registry`
        : `tag ${tagID} removed from tag registry`,
    }
  );
}
