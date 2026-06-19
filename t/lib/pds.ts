import { PDS_RID } from "./expected-rulesets.js";
import { query, signalWait, waitFor } from "./engine.js";
import type { RuntimeState } from "./types.js";

export interface PdsQueryResult<T = unknown> {
  status: string;
  profile?: T;
  general?: T;
  settings?: T;
}

interface PicoChannel {
  id: string;
  name?: string;
  tags?: string[];
}

function assertQueryBody<T>(body: T, label: string): T {
  if (body === null || body === undefined) {
    throw new Error(`${label}: empty query response`);
  }
  if (typeof body === "object" && body !== null && "error" in body) {
    throw new Error(`${label}: ${String((body as { error: unknown }).error)}`);
  }
  return body;
}

/** PDS API channel (tag `pds`), created when io.picolabs.pds installs. */
export async function getPdsChannelEci(
  state: RuntimeState,
  uiEci: string
): Promise<string> {
  return waitFor(
    async () => {
      const pico = await query<{ channels: PicoChannel[] }>(
        state,
        uiEci,
        "io.picolabs.pico-engine-ui",
        "pico"
      );
      const channel = pico.channels.find(
        c => c.tags?.includes("pds") || c.name === "pds"
      );
      return channel?.id ?? null;
    },
    { timeoutMs: 30_000, label: "pds channel on pico" }
  );
}

export async function pdsProfile(
  state: RuntimeState,
  pdsEci: string,
  key?: string
): Promise<PdsQueryResult> {
  const args: Record<string, unknown> = {};
  if (key !== undefined) {
    args.key = key;
  }
  const body = await query<PdsQueryResult>(state, pdsEci, PDS_RID, "profile", args);
  return assertQueryBody(body, "pds profile");
}

export async function pdsItems(
  state: RuntimeState,
  pdsEci: string,
  namespace: string,
  key?: string
): Promise<PdsQueryResult> {
  const args: Record<string, unknown> = { namespace };
  if (key !== undefined) {
    args.key = key;
  }
  const body = await query<PdsQueryResult>(state, pdsEci, PDS_RID, "items", args);
  return assertQueryBody(body, "pds items");
}

export async function pdsUpdateProfile(
  state: RuntimeState,
  pdsEci: string,
  attrs: Record<string, unknown>
): Promise<unknown> {
  return signalWait(state, pdsEci, "pds", "updated_profile", attrs);
}

export async function pdsPutGeneral(
  state: RuntimeState,
  pdsEci: string,
  namespace: string,
  key: string,
  value: unknown
): Promise<unknown> {
  return signalWait(state, pdsEci, "pds", "new_data_available", {
    namespace,
    key,
    value,
  });
}
