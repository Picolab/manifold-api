export interface MountConfig {
  name: string;
  /** Path relative to the repo root (parent of `t/`). */
  hostPath: string;
  containerPath: string;
  /** Minimatch patterns relative to the mount root; matched files are skipped. */
  parseExclude?: string[];
}

export interface DependencyConfig {
  repo: string;
  /**
   * Host path to the dependency repo, relative to this repo root or absolute.
   * For `manifold-api`, omit to use top-level `manifoldApiPath` (default `../manifold-api`).
   */
  path?: string;
  mount: string;
  parseExclude?: string[];
}

export interface TestConfig {
  repoName: string;
  dockerImage: string;
  mounts: MountConfig[];
  /** Host path to manifold-api for cross-repo integration tests. */
  manifoldApiPath?: string;
  dependsOn?: DependencyConfig[];
}

export interface RuntimeState {
  runId: string;
  containerId: string;
  containerName: string;
  hostPort: number;
  baseUrl: string;
  picoEngineHome: string;
  dockerImage: string;
  testing: boolean;
  /** Absolute path to the t/config.json used for this run. */
  configPath: string;
  mounts: Array<{
    name: string;
    hostPath: string;
    containerPath: string;
  }>;
  startedAt: string;
}

export interface CliOptions {
  keep: boolean;
  retainLogs: boolean;
  skipDocker: boolean;
  skipParse: boolean;
  configPath?: string;
  /** Override config `manifoldApiPath` (cross-repo tests). */
  manifoldApiPath?: string;
}

export interface ParseResult {
  ok: boolean;
  filesChecked: number;
  errors: Array<{ file: string; message: string }>;
}
