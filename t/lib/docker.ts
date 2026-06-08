import { spawnSync } from "child_process";
import * as crypto from "crypto";
import * as fs from "fs";
import * as net from "net";
import * as path from "path";
import {
  configRepoRoot,
  defaultConfigPath,
  loadConfig,
  resolveDockerImage,
  resolveMountHostPath,
  testContainerName,
  testPicoEngineHome,
  TEST_CONTAINER_LABEL,
  TEST_REPO_LABEL,
  testResourcePrefix,
} from "./config.js";
import type { RuntimeState, TestConfig } from "./types.js";
import { writeRuntime } from "./runtime.js";

const MIN_PORT = 5001;
const MAX_PORT = 6999;

function run(cmd: string, args: string[]): { ok: boolean; stdout: string; stderr: string } {
  const result = spawnSync(cmd, args, { encoding: "utf8" });
  return {
    ok: result.status === 0,
    stdout: (result.stdout || "").trim(),
    stderr: (result.stderr || "").trim(),
  };
}

function randomRunId(): string {
  return crypto.randomBytes(4).toString("hex");
}

async function isPortFree(port: number): Promise<boolean> {
  return new Promise(resolve => {
    const server = net.createServer();
    server.unref();
    server.on("error", () => resolve(false));
    server.listen(port, "127.0.0.1", () => {
      server.close(() => resolve(true));
    });
  });
}

export async function pickHostPort(): Promise<number> {
  for (let attempt = 0; attempt < 50; attempt++) {
    const port =
      MIN_PORT + Math.floor(Math.random() * (MAX_PORT - MIN_PORT + 1));
    if (await isPortFree(port)) {
      return port;
    }
  }
  throw new Error(`Could not find a free port in ${MIN_PORT}-${MAX_PORT}`);
}

function resolveAllMounts(config: TestConfig, configPath: string) {
  const mounts = config.mounts.map(m => ({
    name: m.name,
    hostPath: resolveMountHostPath(m.hostPath, configPath),
    containerPath: m.containerPath,
    parseExclude: m.parseExclude ?? [],
  }));

  for (const dep of config.dependsOn ?? []) {
    const hostPath = path.resolve(configRepoRoot(configPath), dep.path);
    mounts.push({
      name: dep.repo,
      hostPath,
      containerPath: dep.mount,
      parseExclude: dep.parseExclude ?? [],
    });
  }

  return mounts;
}

export async function startEngine(configPath?: string): Promise<RuntimeState> {
  const resolvedConfigPath = path.resolve(configPath ?? defaultConfigPath);
  const config = loadConfig(resolvedConfigPath);
  const dockerImage = resolveDockerImage(config);
  const runId = randomRunId();
  const hostPort = await pickHostPort();
  const picoEngineHome = testPicoEngineHome(config.repoName, runId);
  const containerName = testContainerName(config.repoName, runId);

  fs.mkdirSync(picoEngineHome, { recursive: true });

  const mounts = resolveAllMounts(config, resolvedConfigPath);
  for (const mount of mounts) {
    if (!fs.existsSync(mount.hostPath)) {
      throw new Error(`Mount host path does not exist: ${mount.hostPath}`);
    }
  }

  const args = [
    "run",
    "-d",
    "--name",
    containerName,
    "--label",
    `${TEST_CONTAINER_LABEL}=1`,
    "--label",
    `${TEST_REPO_LABEL}=${config.repoName}`,
    "-p",
    `${hostPort}:3000`,
    "-e",
    "TESTING=1",
    "-e",
    `PICO_ENGINE_BASE_URL=http://localhost:${hostPort}`,
    "-v",
    `${picoEngineHome}:/var/pico-image`,
  ];

  for (const mount of mounts) {
    args.push("-v", `${mount.hostPath}:${mount.containerPath}`);
  }

  args.push(dockerImage);

  const started = run("docker", args);
  if (!started.ok) {
    throw new Error(
      `docker run failed for image ${dockerImage}:\n${started.stderr || started.stdout}`
    );
  }

  const containerId = started.stdout;
  const state: RuntimeState = {
    runId,
    containerId,
    containerName,
    hostPort,
    baseUrl: `http://localhost:${hostPort}`,
    picoEngineHome,
    dockerImage,
    testing: true,
    configPath: resolvedConfigPath,
    mounts: mounts.map(({ name, hostPath, containerPath }) => ({
      name,
      hostPath,
      containerPath,
    })),
    startedAt: new Date().toISOString(),
  };

  writeRuntime(state);
  await waitForEngine(state.baseUrl);
  return state;
}

export async function waitForEngine(
  baseUrl: string,
  timeoutMs = 60_000
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  let lastError = "unknown";

  while (Date.now() < deadline) {
    try {
      const resp = await fetch(baseUrl, { redirect: "follow" });
      if (resp.ok || resp.status === 404) {
        return;
      }
      lastError = `HTTP ${resp.status}`;
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err);
    }
    await sleep(500);
  }

  throw new Error(`Engine not ready at ${baseUrl}: ${lastError}`);
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export function stopAndRemoveContainer(state: RuntimeState): void {
  run("docker", ["rm", "-f", state.containerName]);
}

export function removePicoEngineHome(state: RuntimeState): void {
  fs.rmSync(state.picoEngineHome, { recursive: true, force: true });
}

export async function teardownRuntime(
  state: RuntimeState,
  opts: { retainLogs: boolean }
): Promise<void> {
  stopAndRemoveContainer(state);
  if (!opts.retainLogs) {
    removePicoEngineHome(state);
  }
}

export interface CleanupResult {
  containers: string[];
  picoHomes: string[];
  dryRun: boolean;
}

/** List Docker containers created by this test harness for the configured repo. */
export function listTestContainers(config: TestConfig): string[] {
  const byLabel = run("docker", [
    "ps",
    "-a",
    "--filter",
    `label=${TEST_CONTAINER_LABEL}=1`,
    "--filter",
    `label=${TEST_REPO_LABEL}=${config.repoName}`,
    "--format",
    "{{.Names}}",
  ]);
  const names = new Set<string>();
  if (byLabel.ok && byLabel.stdout) {
    for (const line of byLabel.stdout.split("\n")) {
      const name = line.trim();
      if (name) {
        names.add(name);
      }
    }
  }

  // Also match by naming convention (covers containers started before labels existed).
  const prefix = testResourcePrefix(config.repoName);
  const byName = run("docker", [
    "ps",
    "-a",
    "--filter",
    `name=${prefix}`,
    "--format",
    "{{.Names}}",
  ]);
  if (byName.ok && byName.stdout) {
    for (const line of byName.stdout.split("\n")) {
      const name = line.trim();
      if (name.startsWith(prefix)) {
        names.add(name);
      }
    }
  }

  return [...names].sort();
}

/** List /tmp pico-engine home dirs for the configured repo (with or without a container). */
export function listTestPicoHomes(config: TestConfig): string[] {
  const prefix = testResourcePrefix(config.repoName);
  const tmpDir = "/tmp";
  if (!fs.existsSync(tmpDir)) {
    return [];
  }
  return fs
    .readdirSync(tmpDir)
    .filter(entry => entry.startsWith(prefix))
    .map(entry => path.join(tmpDir, entry))
    .sort();
}

export function cleanupTestResources(
  configPath?: string,
  opts: { dryRun?: boolean } = {}
): CleanupResult {
  const config = loadConfig(configPath);
  const dryRun = opts.dryRun ?? false;
  const containers = listTestContainers(config);
  const picoHomes = listTestPicoHomes(config);

  if (!dryRun) {
    for (const name of containers) {
      run("docker", ["rm", "-f", name]);
    }
    for (const home of picoHomes) {
      fs.rmSync(home, { recursive: true, force: true });
    }
  }

  return { containers, picoHomes, dryRun };
}
