import type { ManifoldBootstrapContext } from "./bootstrap.js";
import { readTestContextFile } from "./test-context-file.js";
import type { CliOptions, RuntimeState } from "./types.js";

/** Shared fixtures populated by t/run.ts before scenario modules load. */
export interface TestContext {
  opts: CliOptions;
  state: RuntimeState;
  bootstrap?: ManifoldBootstrapContext;
}

let context: Partial<TestContext> = {};

function ensureContextLoaded(): void {
  if (context.state || process.env.MANIFOLD_TEST_CHILD !== "1") {
    return;
  }
  context = readTestContextFile();
}

export function setTestContext(partial: Partial<TestContext>): void {
  context = { ...context, ...partial };
}

export function getTestOpts(): CliOptions {
  ensureContextLoaded();
  if (!context.opts) {
    throw new Error("Test opts not initialized — run via tsx t/run.ts");
  }
  return context.opts;
}

export function getTestState(): RuntimeState {
  ensureContextLoaded();
  if (!context.state) {
    throw new Error("Test state not initialized — run via tsx t/run.ts");
  }
  return context.state;
}

export function getTestBootstrap(): ManifoldBootstrapContext {
  ensureContextLoaded();
  if (!context.bootstrap) {
    throw new Error("Manifold bootstrap not initialized — run bootstrap setup first");
  }
  return context.bootstrap;
}
