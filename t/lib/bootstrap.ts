import { toFileRulesetUrl } from "./config.js";
import { assertTruthy } from "./assert.js";
import { getUiContext, query, waitFor } from "./engine.js";
import type { RuntimeState } from "./types.js";

export interface BootstrapStatus {
  tag_registry_eci: string | null;
  tag_registry_registration_eci: string | null;
  owner_eci: string | null;
  skills_registry_eci: string | null;
}

export interface ManifoldBootstrapContext {
  rootUiEci: string;
  bootstrapChannelEci: string;
  status: BootstrapStatus;
  ownerUiEci: string;
  manifoldUiEci: string;
}

const BOOTSTRAP_RS = "io.picolabs.manifold_bootstrap.krl";
const BOOTSTRAP_RID = "io.picolabs.manifold_bootstrap";

export function manifoldApiMountPath(state: RuntimeState): string {
  const mount = state.mounts.find(m => m.name === "manifold-api");
  assertTruthy(mount, "manifold-api mount not configured in t/config.json");
  return mount.containerPath;
}

interface PicoChannel {
  id: string;
  name?: string;
  tags?: string[];
}

interface PicoDetails {
  children: string[];
  rulesets: Array<{ rid: string }>;
}

export async function flushRuleset(
  state: RuntimeState,
  rulesetFile: string
): Promise<void> {
  const url = toFileRulesetUrl(manifoldApiMountPath(state), rulesetFile);
  const resp = await fetch(
    `${state.baseUrl}/api/flush?url=${encodeURIComponent(url)}`
  );
  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Flush ${rulesetFile} failed (${resp.status}): ${body}`);
  }
}

export async function installRuleset(
  state: RuntimeState,
  uiEci: string,
  rulesetFile: string,
  config: Record<string, unknown> = {}
): Promise<void> {
  const url = toFileRulesetUrl(manifoldApiMountPath(state), rulesetFile);
  const resp = await fetch(`${state.baseUrl}/c/${uiEci}/event-wait/engine_ui/install`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url, config }),
  });
  const body = await resp.text();
  if (!resp.ok) {
    throw new Error(`Install ${rulesetFile} failed (${resp.status}): ${body}`);
  }
}

async function findChannel(
  state: RuntimeState,
  uiEci: string,
  tagOrName: string
): Promise<string | null> {
  const pico = await query<{ channels: PicoChannel[] }>(
    state,
    uiEci,
    "io.picolabs.pico-engine-ui",
    "pico"
  );
  const channel = pico.channels.find(
    c => c.name === tagOrName || c.tags?.includes(tagOrName)
  );
  return channel?.id ?? null;
}

async function waitForBootstrapStatus(
  state: RuntimeState,
  bootstrapChannelEci: string
): Promise<BootstrapStatus> {
  return waitFor(
    async () => {
      const status = await query<BootstrapStatus>(
        state,
        bootstrapChannelEci,
        BOOTSTRAP_RID,
        "getBootstrapStatus"
      );
      if (
        status.tag_registry_eci &&
        status.owner_eci &&
        status.skills_registry_eci &&
        status.tag_registry_registration_eci
      ) {
        return status;
      }
      return null;
    },
    { timeoutMs: 120_000, intervalMs: 1000, label: "Manifold bootstrap completion" }
  );
}

/** Find a child pico's UI channel ECI by display name (via pico-engine-ui). */
export async function findChildUiByName(
  state: RuntimeState,
  parentUiEci: string,
  name: string
): Promise<string | null> {
  const pico = await query<PicoDetails>(
    state,
    parentUiEci,
    "io.picolabs.pico-engine-ui",
    "pico"
  );
  for (const childUiEci of pico.children) {
    const childName = await query<string>(
      state,
      childUiEci,
      "io.picolabs.pico-engine-ui",
      "name"
    );
    if (childName === name) {
      return childUiEci;
    }
  }
  return null;
}

export async function getInstalledRids(
  state: RuntimeState,
  uiEci: string
): Promise<string[]> {
  const pico = await query<PicoDetails>(
    state,
    uiEci,
    "io.picolabs.pico-engine-ui",
    "pico"
  );
  return pico.rulesets.map(r => r.rid);
}

/** Poll until all required rulesets are installed on a pico. */
export async function waitForInstalledRids(
  state: RuntimeState,
  uiEci: string,
  required: readonly string[],
  label: string
): Promise<string[]> {
  return waitFor(
    async () => {
      const rids = await getInstalledRids(state, uiEci);
      const missing = required.filter(rid => !rids.includes(rid));
      if (missing.length === 0) {
        return rids;
      }
      return null;
    },
    {
      timeoutMs: 120_000,
      intervalMs: 500,
      label: `${label} rulesets (${required.join(", ")})`,
    }
  );
}

/** Install bootstrap on the root pico and wait for the full init sequence. */
export async function setupManifoldBootstrap(
  state: RuntimeState
): Promise<ManifoldBootstrapContext> {
  const { eci: rootUiEci } = await getUiContext(state);

  await flushRuleset(state, BOOTSTRAP_RS);
  await installRuleset(state, rootUiEci, BOOTSTRAP_RS, { testing: true });

  const bootstrapChannelEci = await waitFor(
    async () => findChannel(state, rootUiEci, "bootstrap"),
    { timeoutMs: 30_000, label: "bootstrap channel on root pico" }
  );

  const status = await waitForBootstrapStatus(state, bootstrapChannelEci);

  const ownerUiEci = await waitFor(
    async () => findChildUiByName(state, rootUiEci, "Owner"),
    { timeoutMs: 120_000, intervalMs: 1000, label: "Owner pico under root" }
  );

  const manifoldUiEci = await waitFor(
    async () => findChildUiByName(state, ownerUiEci, "Manifold"),
    { timeoutMs: 120_000, intervalMs: 1000, label: "Manifold pico under owner" }
  );

  return {
    rootUiEci,
    bootstrapChannelEci,
    status,
    ownerUiEci,
    manifoldUiEci,
  };
}
