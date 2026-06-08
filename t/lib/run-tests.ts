import { spawnSync } from "node:child_process";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

/** Scenario order (sequential suites share engine state). */
const SCENARIO_FILES = [
  "health.scenario.ts",
  "bootstrap.scenario.ts",
  "thing-community.scenario.ts",
  "safeandmine.scenario.ts",
  "journal.scenario.ts",
] as const;

/**
 * Run scenarios in a child `node --test` process.
 *
 * The parent (t/run.ts) owns Docker/bootstrap; the child only executes tests.
 * Node 18's programmatic run() stream never closes, which previously hung the
 * parent before teardown and leaked containers on every retry.
 */
export function runScenarioTests(): boolean {
  const scenariosDir = path.join(
    path.dirname(fileURLToPath(import.meta.url)),
    "../scenarios"
  );
  const files = SCENARIO_FILES.map(name => path.join(scenariosDir, name));

  const tsxImport = path.join(
    process.cwd(),
    "node_modules/tsx/dist/loader.mjs"
  );

  const result = spawnSync(
    process.execPath,
    [
      "--import",
      tsxImport,
      "--test",
      "--test-concurrency=1",
      ...files,
    ],
    {
      stdio: "inherit",
      env: { ...process.env, MANIFOLD_TEST_CHILD: "1" },
    }
  );

  if (result.error) {
    throw result.error;
  }

  return result.status === 0;
}
