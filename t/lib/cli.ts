import type { CliOptions } from "./types.js";

export function parseCliArgs(argv: string[]): CliOptions {
  const opts: CliOptions = {
    keep: false,
    retainLogs: false,
    skipDocker: false,
    skipParse: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case "--keep":
        opts.keep = true;
        break;
      case "--retain-logs":
        opts.retainLogs = true;
        break;
      case "--skip-docker":
        opts.skipDocker = true;
        break;
      case "--skip-parse":
        opts.skipParse = true;
        break;
      case "--config":
        opts.configPath = argv[++i];
        if (!opts.configPath) {
          throw new Error("--config requires a path");
        }
        break;
      default:
        if (arg.startsWith("-")) {
          throw new Error(`Unknown flag: ${arg}`);
        }
    }
  }

  return opts;
}

export function printCliHelp(): void {
  console.log(`Usage: tsx t/run.ts [options]

Options:
  --keep           Leave the container running after tests (even on success)
  --retain-logs    Keep PICO_ENGINE_HOME on disk after a successful run
  --skip-docker    Skip container start/stop (parse and scenarios only)
  --skip-parse     Skip krl-compiler verification
  --config <path>  Alternate t/config.json path

Environment:
  PICO_ENGINE_IMAGE   Override dockerImage from config (e.g. pjw/pico-engine:latest)
`);
}
