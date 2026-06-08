import { spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import { minimatch } from "minimatch";
import {
  defaultConfigPath,
  loadConfig,
  resolveDependencyHostPath,
  resolveMountHostPath,
} from "./config.js";
import type { ParseResult, TestConfig } from "./types.js";

function walkKrlFiles(dir: string, files: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkKrlFiles(fullPath, files);
    } else if (entry.isFile() && entry.name.endsWith(".krl")) {
      files.push(fullPath);
    }
  }
  return files;
}

function mountRoots(
  config: TestConfig,
  configPath: string,
  opts: { manifoldApiPath?: string } = {}
) {
  const roots: Array<{ root: string; exclude: string[]; label: string }> = [];

  for (const mount of config.mounts) {
    roots.push({
      root: resolveMountHostPath(mount.hostPath, configPath),
      exclude: mount.parseExclude ?? [],
      label: mount.name,
    });
  }

  for (const dep of config.dependsOn ?? []) {
    roots.push({
      root: resolveDependencyHostPath(dep, config, configPath, opts),
      exclude: dep.parseExclude ?? [],
      label: dep.repo,
    });
  }

  return roots;
}

function isExcluded(filePath: string, mountRoot: string, patterns: string[]): boolean {
  const rel = path.relative(mountRoot, filePath).replace(/\\/g, "/");
  return patterns.some(pattern => minimatch(rel, pattern, { dot: true }));
}

function verifyFile(filePath: string): string | null {
  const source = fs.readFileSync(filePath, "utf8");
  const result = spawnSync("krl-compiler", ["--verify"], {
    input: source,
    encoding: "utf8",
  });
  if (result.status === 0) {
    return null;
  }
  const message = (result.stdout || result.stderr || "parse failed").trim();
  return message;
}

export function parseMountedKrl(
  configPath?: string,
  opts: { manifoldApiPath?: string } = {}
): ParseResult {
  const resolvedConfigPath = path.resolve(configPath ?? defaultConfigPath);
  const config = loadConfig(resolvedConfigPath);
  const errors: ParseResult["errors"] = [];
  const seen = new Set<string>();
  let filesChecked = 0;

  for (const { root, exclude, label } of mountRoots(config, resolvedConfigPath, opts)) {
    if (!fs.existsSync(root)) {
      errors.push({
        file: root,
        message: `mount root for ${label} does not exist`,
      });
      continue;
    }

    for (const file of walkKrlFiles(root)) {
      if (seen.has(file)) {
        continue;
      }
      seen.add(file);

      if (isExcluded(file, root, exclude)) {
        continue;
      }

      filesChecked++;
      const message = verifyFile(file);
      if (message) {
        errors.push({ file, message });
      }
    }
  }

  return {
    ok: errors.length === 0,
    filesChecked,
    errors,
  };
}

export function printParseResult(result: ParseResult): void {
  if (result.ok) {
    console.log(`KRL parse OK (${result.filesChecked} files)`);
    return;
  }

  console.error(`KRL parse failed (${result.errors.length} errors, ${result.filesChecked} files checked)`);
  for (const err of result.errors) {
    console.error(`\n${err.file}\n  ${err.message}`);
  }
}
