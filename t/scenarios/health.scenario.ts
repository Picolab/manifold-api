import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { waitForEngine } from "../lib/docker.js";
import { getTestState } from "../lib/test-context.js";

describe("health", () => {
  it("engine is reachable over HTTP", async () => {
    const state = getTestState();
    await waitForEngine(state.baseUrl, 5_000);
    const resp = await fetch(state.baseUrl);
    assert.ok(
      resp.ok || resp.status === 404,
      `Expected engine UI at ${state.baseUrl}, got HTTP ${resp.status}`
    );
  });
});
