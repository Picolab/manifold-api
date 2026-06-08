#!/usr/bin/env tsx
import { parseCliArgs, printCliHelp } from "./lib/cli.js";
import { parseMountedKrl, printParseResult } from "./lib/parse-krl.js";

const args = process.argv.slice(2);
if (args.includes("-h") || args.includes("--help")) {
  printCliHelp();
  process.exit(0);
}

const opts = parseCliArgs(args);
const result = parseMountedKrl(opts.configPath);
printParseResult(result);
process.exit(result.ok ? 0 : 1);
