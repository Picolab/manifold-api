import * as fs from "fs";
import type { RuntimeState } from "./types.js";
import { runtimePathForConfig } from "./config.js";

function runtimePath(state?: RuntimeState | null, configPath?: string): string {
  if (state?.configPath) {
    return runtimePathForConfig(state.configPath);
  }
  if (configPath) {
    return runtimePathForConfig(configPath);
  }
  return runtimePathForConfig();
}

export function readRuntime(configPath?: string): RuntimeState | null {
  const file = runtimePath(null, configPath);
  if (!fs.existsSync(file)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(file, "utf8")) as RuntimeState;
}

export function writeRuntime(state: RuntimeState): void {
  fs.writeFileSync(runtimePath(state), JSON.stringify(state, null, 2) + "\n");
}

export function clearRuntime(state?: RuntimeState | null, configPath?: string): void {
  const file = runtimePath(state, configPath);
  if (fs.existsSync(file)) {
    fs.unlinkSync(file);
  }
}

export function formatRuntimeSummary(state: RuntimeState): string {
  return [
    `container: ${state.containerName} (${state.containerId.slice(0, 12)})`,
    `base URL:  ${state.baseUrl}`,
    `pico home: ${state.picoEngineHome}`,
    `image:     ${state.dockerImage}`,
  ].join("\n");
}
