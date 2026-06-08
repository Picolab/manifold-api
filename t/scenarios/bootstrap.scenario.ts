import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { assertIncludes, assertTruthy } from "../lib/assert.js";
import {
  findChildUiByName,
  waitForInstalledRids,
} from "../lib/bootstrap.js";
import {
  MANIFOLD_RULESETS,
  OWNER_RULESETS,
  SKILLS_REGISTRY_RULESETS,
  TAG_REGISTRY_RULESETS,
} from "../lib/expected-rulesets.js";
import { getTestBootstrap, getTestState } from "../lib/test-context.js";

const TAG_REGISTRY_NAME = "Tag Registry";
const SKILLS_REGISTRY_NAME = "Skills Registry";
const OWNER_NAME = "Owner";
const MANIFOLD_NAME = "Manifold";

describe("bootstrap", () => {
  it("creates tag registry pico with registration ECI and new_tag_registry ruleset", async () => {
    const state = getTestState();
    const ctx = getTestBootstrap();

    assertTruthy(ctx.status.tag_registry_eci, "bootstrap: tag_registry_eci not set");
    assertTruthy(
      ctx.status.tag_registry_registration_eci,
      "bootstrap: tag_registry_registration_eci not set"
    );

    const uiEci = await findChildUiByName(state, ctx.rootUiEci, TAG_REGISTRY_NAME);
    assertTruthy(uiEci, `root has no child pico named "${TAG_REGISTRY_NAME}"`);

    const rids = await waitForInstalledRids(
      state,
      uiEci,
      TAG_REGISTRY_RULESETS,
      "Tag Registry pico"
    );
    assertIncludes(rids, [...TAG_REGISTRY_RULESETS], "Tag Registry pico");
  });

  it("creates skills registry pico with skills_registry ruleset", async () => {
    const state = getTestState();
    const ctx = getTestBootstrap();

    assertTruthy(ctx.status.skills_registry_eci, "bootstrap: skills_registry_eci not set");

    const uiEci = await findChildUiByName(state, ctx.rootUiEci, SKILLS_REGISTRY_NAME);
    assertTruthy(uiEci, `root has no child pico named "${SKILLS_REGISTRY_NAME}"`);

    const rids = await waitForInstalledRids(
      state,
      uiEci,
      SKILLS_REGISTRY_RULESETS,
      "Skills Registry pico"
    );
    assertIncludes(rids, [...SKILLS_REGISTRY_RULESETS], "Skills Registry pico");
  });

  it("creates owner pico with profile and manifold_owner rulesets", async () => {
    const state = getTestState();
    const ctx = getTestBootstrap();

    assertTruthy(ctx.status.owner_eci, "bootstrap: owner_eci not set");

    const uiEci = await findChildUiByName(state, ctx.rootUiEci, OWNER_NAME);
    assertTruthy(uiEci, `root has no child pico named "${OWNER_NAME}"`);
    assert.equal(uiEci, ctx.ownerUiEci, "Owner UI ECI mismatch");

    const rids = await waitForInstalledRids(state, uiEci, OWNER_RULESETS, "Owner pico");
    assertIncludes(rids, [...OWNER_RULESETS], "Owner pico");
  });

  it("creates manifold pico with manifold_pico and notification init rulesets", async () => {
    const state = getTestState();
    const ctx = getTestBootstrap();

    const uiEci = ctx.manifoldUiEci;
    const found = await findChildUiByName(state, ctx.ownerUiEci, MANIFOLD_NAME);
    assertTruthy(found === uiEci, "Manifold UI ECI mismatch");

    const rids = await waitForInstalledRids(state, uiEci, MANIFOLD_RULESETS, "Manifold pico");
    assertIncludes(rids, [...MANIFOLD_RULESETS], "Manifold pico");
  });
});
