#!/usr/bin/env node
"use strict";

/**
 * Generate docs/rulesets/*.md from KRL annotations and write docs/llms.txt + llms-full.txt.
 * Requires a sibling pico-engine checkout (for tools/krl-schema/cli.js).
 */

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const docsDir = path.join(repoRoot, "docs");
const rulesetsDocsDir = path.join(docsDir, "rulesets");

const engineRepo =
  process.env.PICO_ENGINE_REPO ||
  path.resolve(repoRoot, "../pico-engine");
const krlSchemaCli = path.join(engineRepo, "tools/krl-schema/cli.js");

/** Root-level published rulesets (not tmp/, OLD/, fix/). */
const publishedKrl = fs
  .readdirSync(repoRoot)
  .filter(
    (f) =>
      f.startsWith("io.picolabs.") &&
      f.endsWith(".krl") &&
      f !== "io.picolabs.pds.krl",
  )
  .sort();

const indexMd = [
  { title: "Manifold overview", file: "Manifold.md" },
  { title: "Managing PDS", file: "Managing_PDS.md" },
  { title: "Ruleset index", file: "rulesets/README.md" },
];

function readDoc(rel) {
  const p = path.join(docsDir, rel);
  return fs.existsSync(p) ? fs.readFileSync(p, "utf8") : "";
}

if (!fs.existsSync(krlSchemaCli)) {
  console.error(
    "Missing pico-engine krl-schema CLI at:",
    krlSchemaCli,
    "\nClone pico-engine beside manifold-api or set PICO_ENGINE_REPO.",
  );
  process.exit(1);
}

fs.mkdirSync(rulesetsDocsDir, { recursive: true });

for (const krlFile of publishedKrl) {
  const krlPath = path.join(repoRoot, krlFile);
  const mdName = krlFile.replace(/\.krl$/, ".md");
  const mdPath = path.join(rulesetsDocsDir, mdName);
  try {
    const md = execFileSync(
      process.execPath,
      [krlSchemaCli, "-q", "-f", "markdown", krlPath],
      { encoding: "utf8", cwd: repoRoot },
    );
    fs.writeFileSync(mdPath, md);
  } catch (err) {
    console.warn(`warn: skip ${krlFile} (${err.stderr || err.message})`);
    if (fs.existsSync(mdPath)) fs.unlinkSync(mdPath);
  }
}

const llmsLines = [
  "# Manifold docs (llms.txt)",
  "",
  "Machine-readable index for agents building on Manifold (KRL mesh framework on pico-engine).",
  "",
  "## Start here",
  "",
  "- Repo `CLAUDE.md` — layering, mesh shape, conventions",
  "- Engine operator guide: `pico-engine` → `packages/pico-engine/public/docs/pico-engine.md`",
  "- Requires **pico-engine 1.8+** and **wrangler** for lifecycle (use `manifold:*` / domain events, not raw `ctx:`)",
  "",
  "## Manifold docs",
  "",
];

for (const entry of indexMd) {
  llmsLines.push(`- ${entry.title}: docs/${entry.file}`);
}

llmsLines.push("", "## Ruleset API (generated from KRL)", "");
for (const krlFile of publishedKrl) {
  const mdName = krlFile.replace(/\.krl$/, ".md");
  llmsLines.push(`- ${mdName.replace(/\.md$/, "")}: docs/rulesets/${mdName}`);
}

llmsLines.push(
  "",
  "## Regenerate",
  "",
  "`npm run generate:docs` (needs pico-engine checkout for krl-schema)",
  "",
);

const fullParts = [];
for (const entry of indexMd) {
  const body = readDoc(entry.file);
  if (!body) continue;
  fullParts.push(`\n\n---\n\n# ${entry.title}\n\n${body}`);
}

fs.writeFileSync(path.join(docsDir, "llms.txt"), llmsLines.join("\n"));
fs.writeFileSync(
  path.join(docsDir, "llms-full.txt"),
  `# Manifold — full text bundle\n${fullParts.join("")}\n`,
);

console.log(
  `Wrote docs/rulesets/ (${publishedKrl.length} files), docs/llms.txt, docs/llms-full.txt`,
);
