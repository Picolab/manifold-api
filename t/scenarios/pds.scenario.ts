import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getInstalledRids, waitForInstalledRids } from "../lib/bootstrap.js";
import { PDS_RID } from "../lib/expected-rulesets.js";
import { createThing, getManifoldAppEci, getThings } from "../lib/manifold.js";
import {
  getPdsChannelEci,
  pdsItems,
  pdsProfile,
  pdsPutGeneral,
  pdsUpdateProfile,
} from "../lib/pds.js";
import { getTestBootstrap, getTestState } from "../lib/test-context.js";

const THING_NAME = "PDS Test Thing";
const OWNER_DISPLAY_NAME = "PDS Owner Test";
const THING_DISPLAY_NAME = "PDS Thing Profile";
const TEST_NAMESPACE = "manifold_test";

describe("pds", () => {
  it("is installed on bootstrap picos with a pds channel", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();

    for (const [label, uiEci] of [
      ["Owner", bootstrap.ownerUiEci],
      ["Manifold hub", bootstrap.manifoldUiEci],
    ] as const) {
      const rids = await getInstalledRids(state, uiEci);
      assert.ok(
        rids.includes(PDS_RID),
        `${label} pico missing ${PDS_RID}; installed: ${rids.join(", ")}`
      );
      const pdsEci = await getPdsChannelEci(state, uiEci);
      assert.ok(pdsEci, `${label} pico missing pds-tagged channel`);
    }
  });

  it("queries profile on owner pico before and after updated_profile", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const pdsEci = await getPdsChannelEci(state, bootstrap.ownerUiEci);

    const before = await pdsProfile(state, pdsEci, "name");
    assert.equal(before.status, "success");

    await pdsUpdateProfile(state, pdsEci, {
      name: OWNER_DISPLAY_NAME,
      description: "Owner pico PDS profile write",
      email: "owner@example.com",
      phone: "555-0199",
    });

    const nameResult = await pdsProfile(state, pdsEci, "name");
    assert.equal(nameResult.status, "success");
    assert.equal(nameResult.profile, OWNER_DISPLAY_NAME);

    const emailResult = await pdsProfile(state, pdsEci, "email");
    assert.equal(emailResult.status, "success");
    assert.equal(emailResult.profile, "owner@example.com");

    const phoneResult = await pdsProfile(state, pdsEci, "phone");
    assert.equal(phoneResult.status, "success");
    assert.equal(phoneResult.profile, "555-0199");

    const full = await pdsProfile(state, pdsEci);
    assert.equal(full.status, "success");
    assert.equal(typeof full.profile, "object");
    assert.equal((full.profile as Record<string, unknown>)?.name, OWNER_DISPLAY_NAME);
    assert.ok((full.profile as Record<string, unknown>)?._created);
    assert.ok((full.profile as Record<string, unknown>)?._modified);
  });

  it("writes and reads profile and general data on a thing pico", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const appEci = await getManifoldAppEci(state, bootstrap.manifoldUiEci);

    const { uiEci } = await createThing(state, bootstrap, THING_NAME);
    await waitForInstalledRids(state, uiEci, [PDS_RID], "PDS thing");
    const pdsEci = await getPdsChannelEci(state, uiEci);

    const seeded = await pdsProfile(state, pdsEci, "name");
    assert.equal(seeded.status, "success");
    assert.equal(seeded.profile, THING_NAME, "PDS profile name should seed from wrangler on install");

    await pdsUpdateProfile(state, pdsEci, {
      name: THING_DISPLAY_NAME,
      description: "Thing pico PDS profile write",
    });

    const nameResult = await pdsProfile(state, pdsEci, "name");
    assert.equal(nameResult.status, "success");
    assert.equal(nameResult.profile, THING_DISPLAY_NAME);

    await pdsPutGeneral(state, pdsEci, TEST_NAMESPACE, "marker", "phase-c-ok");

    const item = await pdsItems(state, pdsEci, TEST_NAMESPACE, "marker");
    assert.equal(item.status, "success");
    assert.equal(item.general, "phase-c-ok");

    const things = await getThings(state, appEci);
    const entry = Object.values(things).find(t => t.name === THING_NAME);
    assert.ok(entry, `Manifold should still track thing "${THING_NAME}"`);
  });
});
