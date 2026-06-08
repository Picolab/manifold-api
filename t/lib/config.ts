import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import type { TestConfig } from "./types.js";

const libDir = path.dirname(fileURLToPath(import.meta.url));
export const tDir = path.resolve(libDir, "..");
/** Repo root when this library lives in manifold-api (legacy default). */
export const repoRoot = path.resolve(tDir, "..");
export const defaultConfigPath = path.join(tDir, "config.json");

export function configPathDir(configPath: string = defaultConfigPath): string {
  return path.resolve(path.dirname(configPath));
}

/** Repo root for the test config being loaded (parent of `t/`). */
export function configRepoRoot(configPath: string = defaultConfigPath): string {
  return path.resolve(configPathDir(configPath), "..");
}

export function runtimePathForConfig(configPath: string = defaultConfigPath): string {
  return path.join(configPathDir(configPath), ".runtime.json");
}

/** @deprecated prefer runtimePathForConfig(configPath) for cross-repo test configs */
export const runtimePath = runtimePathForConfig(defaultConfigPath);

export function loadConfig(configPath: string = defaultConfigPath): TestConfig {
  const raw = fs.readFileSync(configPath, "utf8");
  const config = JSON.parse(raw) as TestConfig;
  if (!config.repoName) {
    throw new Error(`config missing repoName: ${configPath}`);
  }
  if (!config.dockerImage) {
    throw new Error(`config missing dockerImage: ${configPath}`);
  }
  if (!Array.isArray(config.mounts) || config.mounts.length === 0) {
    throw new Error(`config must declare at least one mount: ${configPath}`);
  }
  return config;
}

export function resolveDockerImage(config: TestConfig): string {
  return process.env.PICO_ENGINE_IMAGE?.trim() || config.dockerImage;
}

export function resolveMountHostPath(
  hostPath: string,
  configPath: string = defaultConfigPath
): string {
  return path.resolve(configRepoRoot(configPath), hostPath);
}

export interface ManifoldApiPathOptions {
  manifoldApiPath?: string;
}

const DEFAULT_MANIFOLD_API_PATH = "../manifold-api";

/** Resolve host filesystem path to a local manifold-api checkout. */
export function resolveManifoldApiPath(
  config: TestConfig,
  configPath: string,
  opts: ManifoldApiPathOptions = {}
): string {
  const raw =
    opts.manifoldApiPath?.trim() ||
    process.env.MANIFOLD_API_PATH?.trim() ||
    config.manifoldApiPath?.trim() ||
    config.dependsOn?.find(dep => dep.repo === "manifold-api")?.path?.trim() ||
    DEFAULT_MANIFOLD_API_PATH;

  return path.isAbsolute(raw)
    ? raw
    : path.resolve(configRepoRoot(configPath), raw);
}

/** Resolve a dependsOn entry to an absolute host path. */
export function resolveDependencyHostPath(
  dep: DependencyConfig,
  config: TestConfig,
  configPath: string,
  opts: ManifoldApiPathOptions = {}
): string {
  if (dep.path?.trim()) {
    const raw = dep.path.trim();
    return path.isAbsolute(raw)
      ? raw
      : path.resolve(configRepoRoot(configPath), raw);
  }

  if (dep.repo === "manifold-api") {
    return resolveManifoldApiPath(config, configPath, opts);
  }

  throw new Error(
    `dependsOn entry "${dep.repo}" is missing path in ${configPath}`
  );
}

export function toFileRulesetUrl(containerPath: string, krlFile: string): string {
  const normalized = path.posix.join(
    containerPath.replace(/\/+$/, ""),
    krlFile.replace(/\\/g, "/")
  );
  return `file://${normalized}`;
}

/** Prefix for test container names and /tmp pico-engine home dirs. */
export function testResourcePrefix(repoName: string): string {
  return `${repoName}-pico-test-`;
}

export function testContainerName(repoName: string, runId: string): string {
  return `${testResourcePrefix(repoName)}${runId}`;
}

export function testPicoEngineHome(repoName: string, runId: string): string {
  return path.join("/tmp", testContainerName(repoName, runId));
}

export const TEST_CONTAINER_LABEL = "io.picolabs.test";
export const TEST_REPO_LABEL = "io.picolabs.test.repo";
