import { query, signalWait, waitFor } from "./engine.js";
import type { RuntimeState } from "./types.js";

export interface ManifoldNotification {
  id: string;
  time: number;
  picoId: string;
  thing: string;
  app: string;
  message: string;
  ruleset?: string;
}

/** Toggle a notification channel on for a subject pico (idempotent if already on). */
export async function enableNotificationChannel(
  state: RuntimeState,
  manifoldAppEci: string,
  picoId: string,
  channel: "Manifold" | "SMS" | "Prowl" | "HomeAssistant"
): Promise<void> {
  const settings = await query<Record<string, boolean> | null>(
    state,
    manifoldAppEci,
    "io.picolabs.notifications",
    "getSettings",
    { id: picoId }
  );
  if (settings?.[channel]) {
    return;
  }
  await signalWait(state, manifoldAppEci, "manifold", "change_notification_setting", {
    id: picoId,
    option: channel,
  });
}

function asNotificationList(raw: unknown): ManifoldNotification[] {
  if (Array.isArray(raw)) {
    return raw;
  }
  if (raw && typeof raw === "object") {
    return Object.values(raw) as ManifoldNotification[];
  }
  return [];
}

export async function getNotifications(
  state: RuntimeState,
  manifoldAppEci: string
): Promise<ManifoldNotification[]> {
  const raw = await query<unknown>(
    state,
    manifoldAppEci,
    "io.picolabs.notifications",
    "getNotifications"
  );
  return asNotificationList(raw);
}

export async function waitForNotification(
  state: RuntimeState,
  manifoldAppEci: string,
  predicate: (n: ManifoldNotification) => boolean,
  label: string
): Promise<ManifoldNotification> {
  return waitFor(
    async () => {
      const notifications = await getNotifications(state, manifoldAppEci);
      return notifications.find(predicate) ?? null;
    },
    { timeoutMs: 30_000, intervalMs: 500, label }
  );
}
