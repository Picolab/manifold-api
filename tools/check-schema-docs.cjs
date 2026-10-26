#!/usr/bin/env node
"use strict";

const { execFileSync } = require("child_process");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const gen = path.join(__dirname, "generate-docs.cjs");

execFileSync(process.execPath, [gen], { stdio: "inherit", cwd: repoRoot });

const diff = execFileSync(
  "git diff --name-only docs/rulesets docs/llms.txt docs/llms-full.txt",
  { encoding: "utf8", cwd: repoRoot },
).trim();

if (diff) {
  console.error("Generated Manifold docs are out of date. Run: npm run generate:docs");
  console.error(diff);
  process.exit(1);
}

console.log("Manifold schema docs OK");
