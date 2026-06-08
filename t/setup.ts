import { startEngine } from "./lib/docker.js";
import { formatRuntimeSummary } from "./lib/runtime.js";
import type { RuntimeState } from "./lib/types.js";

export async function setup(configPath?: string): Promise<RuntimeState> {
  const state = await startEngine(configPath);
  console.log("Pico engine container started:");
  console.log(formatRuntimeSummary(state));
  return state;
}
