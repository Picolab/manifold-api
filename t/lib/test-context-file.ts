import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import type { TestContext } from "./test-context.js";

const CONTEXT_FILE = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.test-context.json"
);

export function testContextFilePath(): string {
  return CONTEXT_FILE;
}

export function writeTestContextFile(context: TestContext): void {
  fs.writeFileSync(CONTEXT_FILE, JSON.stringify(context, null, 2) + "\n");
}

export function readTestContextFile(): TestContext {
  if (!fs.existsSync(CONTEXT_FILE)) {
    throw new Error(
      `Missing ${CONTEXT_FILE} — scenario subprocess must be started by tsx t/run.ts`
    );
  }
  return JSON.parse(fs.readFileSync(CONTEXT_FILE, "utf8")) as TestContext;
}

export function clearTestContextFile(): void {
  if (fs.existsSync(CONTEXT_FILE)) {
    fs.unlinkSync(CONTEXT_FILE);
  }
}
