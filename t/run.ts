#!/usr/bin/env tsx
import "./disable-auto-test.mjs";
import { parseCliArgs, printCliHelp } from "./lib/cli.js";
import { parseMountedKrl, printParseResult } from "./lib/parse-krl.js";
import { setup } from "./setup.js";
import { teardown } from "./teardown.js";
import { setupManifoldBootstrap } from "./lib/bootstrap.js";
import { runScenarioTests } from "./lib/run-tests.js";
import { setTestContext } from "./lib/test-context.js";
import { clearTestContextFile, writeTestContextFile } from "./lib/test-context-file.js";
import type { RuntimeState } from "./lib/types.js";

const args = process.argv.slice(2);
if (args.includes("-h") || args.includes("--help")) {
  printCliHelp();
  process.exit(0);
}

const opts = parseCliArgs(args);
let state: RuntimeState | null = null;
let passed = false;

try {
  if (!opts.skipParse) {
    const parseResult = parseMountedKrl(opts.configPath);
    printParseResult(parseResult);
    if (!parseResult.ok) {
      process.exit(1);
    }
  }

  if (!opts.skipDocker) {
    state = await setup(opts.configPath);
    setTestContext({ opts, state });

    console.log("\nInstalling Manifold bootstrap…");
    const bootstrap = await setupManifoldBootstrap(state);
    setTestContext({ bootstrap });

    writeTestContextFile({ opts, state, bootstrap });

    passed = runScenarioTests();
  } else {
    passed = true;
  }
} catch (err) {
  console.error("\nTest run failed:");
  console.error(err instanceof Error ? err.message : err);
  passed = false;
} finally {
  clearTestContextFile();
  if (!opts.skipDocker) {
    await teardown(state, opts, passed);
  }
}

// Node's test runner may set exitCode to the test count; override explicitly.
process.exitCode = passed ? 0 : 1;
process.exit(process.exitCode);
