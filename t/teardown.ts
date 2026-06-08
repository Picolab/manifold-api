import { teardownRuntime } from "./lib/docker.js";
import { clearRuntime, formatRuntimeSummary, readRuntime } from "./lib/runtime.js";
import type { CliOptions, RuntimeState } from "./lib/types.js";

export async function teardown(
  state: RuntimeState | null,
  opts: Pick<CliOptions, "keep" | "retainLogs">,
  passed: boolean
): Promise<void> {
  const runtime = state ?? readRuntime();
  if (!runtime) {
    return;
  }

  if (opts.keep || !passed) {
    console.log("\nLeaving test container running for inspection:");
    console.log(formatRuntimeSummary(runtime));
    if (!passed) {
      console.log("\nFix the failure, then stop manually:");
      console.log(`  docker rm -f ${runtime.containerName}`);
      console.log(`  rm -rf ${runtime.picoEngineHome}`);
    }
    return;
  }

  await teardownRuntime(runtime, { retainLogs: opts.retainLogs });
  clearRuntime(runtime);
  console.log("\nTest container removed.");
  if (opts.retainLogs) {
    console.log(`Pico engine home retained at: ${runtime.picoEngineHome}`);
  } else {
    console.log("Pico engine home deleted.");
  }
}
