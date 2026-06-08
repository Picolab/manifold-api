import type { RuntimeState } from "./types.js";

export interface UiContext {
  version: string;
  eci: string;
}

export async function getUiContext(state: RuntimeState): Promise<UiContext> {
  const resp = await fetch(`${state.baseUrl}/api/ui-context`);
  if (!resp.ok) {
    throw new Error(`GET /api/ui-context failed (${resp.status})`);
  }
  return resp.json() as Promise<UiContext>;
}

function serializeQueryArg(value: unknown): string {
  if (value === null || value === undefined) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return JSON.stringify(value);
}

export async function query<T = unknown>(
  state: RuntimeState,
  eci: string,
  rid: string,
  name: string,
  args: Record<string, unknown> = {}
): Promise<T> {
  const url = new URL(`${state.baseUrl}/c/${eci}/query/${rid}/${name}`);
  for (const [key, value] of Object.entries(args)) {
    url.searchParams.set(key, serializeQueryArg(value));
  }

  const resp = await fetch(url);
  const body = await resp.text();
  if (!resp.ok) {
    throw new Error(`Query ${rid}/${name} failed (${resp.status}): ${body}`);
  }
  return body ? (JSON.parse(body) as T) : (null as T);
}

export async function signal(
  state: RuntimeState,
  eci: string,
  domain: string,
  name: string,
  attrs: Record<string, unknown> = {},
  eid = "test"
): Promise<unknown> {
  const url = `${state.baseUrl}/sky/event/${eci}/${eid}/${domain}/${name}`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(attrs),
  });
  const body = await resp.text();
  if (!resp.ok) {
    throw new Error(`Event ${domain}/${name} failed (${resp.status}): ${body}`);
  }
  return body ? JSON.parse(body) : null;
}

/** POST event-wait and return when the engine finishes processing the transaction. */
export async function signalWait(
  state: RuntimeState,
  eci: string,
  domain: string,
  name: string,
  attrs: Record<string, unknown> = {}
): Promise<unknown> {
  const url = `${state.baseUrl}/c/${eci}/event-wait/${domain}/${name}`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(attrs),
  });
  const body = await resp.text();
  if (!resp.ok) {
    throw new Error(`Event-wait ${domain}/${name} failed (${resp.status}): ${body}`);
  }
  return body ? JSON.parse(body) : null;
}

export async function waitFor<T>(
  fn: () => Promise<T>,
  opts: { timeoutMs?: number; intervalMs?: number; label?: string } = {}
): Promise<T> {
  const timeoutMs = opts.timeoutMs ?? 30_000;
  const intervalMs = opts.intervalMs ?? 500;
  const deadline = Date.now() + timeoutMs;
  let lastError = "condition not met";

  while (Date.now() < deadline) {
    try {
      const value = await fn();
      if (value) {
        return value;
      }
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err);
    }
    await new Promise(resolve => setTimeout(resolve, intervalMs));
  }

  throw new Error(
    opts.label
      ? `Timed out waiting for ${opts.label}: ${lastError}`
      : `Timed out: ${lastError}`
  );
}
