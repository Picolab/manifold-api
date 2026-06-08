#!/usr/bin/env tsx
import { loadConfig, defaultConfigPath } from "./lib/config.js";
import { cleanupTestResources } from "./lib/docker.js";
import { clearRuntime, readRuntime } from "./lib/runtime.js";

function printHelp(): void {
  console.log(`Usage: tsx t/cleanup.ts [options]

Remove test containers and pico-engine home directories left behind by
test:keep or failed runs.

Containers are identified by Docker labels (io.picolabs.test) and by name
prefix <repoName>-pico-test-* from t/config.json.

Options:
  --dry-run        List what would be removed without deleting
  --config <path>  Alternate t/config.json path
  -h, --help       Show this help
`);
}

const args = process.argv.slice(2);
if (args.includes("-h") || args.includes("--help")) {
  printHelp();
  process.exit(0);
}

let configPath: string | undefined;
let dryRun = false;
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === "--dry-run") {
    dryRun = true;
  } else if (arg === "--config") {
    configPath = args[++i];
    if (!configPath) {
      console.error("--config requires a path");
      process.exit(1);
    }
  } else if (arg.startsWith("-")) {
    console.error(`Unknown flag: ${arg}`);
    process.exit(1);
  }
}

const config = loadConfig(configPath ?? defaultConfigPath);
const result = cleanupTestResources(configPath, { dryRun });

if (result.containers.length === 0 && result.picoHomes.length === 0) {
  console.log(`No test resources found for ${config.repoName}.`);
  process.exit(0);
}

const verb = dryRun ? "Would remove" : "Removed";
if (result.containers.length > 0) {
  console.log(`${verb} ${result.containers.length} container(s):`);
  for (const name of result.containers) {
    console.log(`  ${name}`);
  }
}
if (result.picoHomes.length > 0) {
  console.log(`${verb} ${result.picoHomes.length} pico home dir(s):`);
  for (const home of result.picoHomes) {
    console.log(`  ${home}`);
  }
}

if (!dryRun) {
  const runtime = readRuntime();
  if (
    runtime &&
    (result.containers.includes(runtime.containerName) ||
      result.picoHomes.includes(runtime.picoEngineHome))
  ) {
    clearRuntime(runtime, configPath);
    console.log("Cleared t/.runtime.json");
  }
}
