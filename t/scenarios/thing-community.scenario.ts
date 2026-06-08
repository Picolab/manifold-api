import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { assertIncludes, assertTruthy } from "../lib/assert.js";
import {
  COMMUNITY_RULESETS,
  THING_RULESETS,
} from "../lib/expected-rulesets.js";
import { query } from "../lib/engine.js";
import {
  addThingToCommunity,
  assertChildGone,
  createCommunity,
  createThing,
  deleteCommunity,
  deleteThing,
  getCommunities,
  getCommunityDescription,
  getCommunityThings,
  getThingCommunities,
  getThings,
  removeThingFromCommunity,
  waitForCommunityMembership,
  waitForInstalledRids,
  type ThingCommunityContext,
} from "../lib/manifold.js";
import { getTestBootstrap, getTestState } from "../lib/test-context.js";

const THING_NAME = "Test Thing";
const COMMUNITY_NAME = "Test Community";
const COMMUNITY_DESCRIPTION = "A community for integration tests";

/** Mutable state shared across sequential tests in this describe block. */
const ctx: ThingCommunityContext = {
  thingName: THING_NAME,
  communityName: COMMUNITY_NAME,
  communityDescription: COMMUNITY_DESCRIPTION,
  thingPicoId: "",
  communityPicoId: "",
  thingUiEci: "",
  communityUiEci: "",
  thingQueryEci: "",
  communityQueryEci: "",
  manifoldAppEci: "",
};

describe("thing / community", () => {
  it("creates a thing pico with rulesets, name, and Manifold subscription", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const { entry, uiEci, appEci } = await createThing(state, bootstrap, THING_NAME);

    ctx.thingPicoId = entry.picoID;
    ctx.thingUiEci = uiEci;
    ctx.thingQueryEci = entry.Tx;
    ctx.manifoldAppEci = appEci;

    const name = await query<string>(state, uiEci, "io.picolabs.pico-engine-ui", "name");
    assert.equal(name, THING_NAME);

    const rids = await waitForInstalledRids(state, uiEci, THING_RULESETS, "Thing pico");
    assertIncludes(rids, [...THING_RULESETS], "Thing pico");

    assert.equal(entry.Tx_role, "manifold_thing");
    assert.ok(entry.Id && entry.Tx, "Manifold→thing subscription missing Id or Tx channel");
  });

  it("creates a community pico with rulesets, name, description, and Manifold subscription", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const { entry, uiEci, appEci } = await createCommunity(
      state,
      bootstrap,
      COMMUNITY_NAME,
      COMMUNITY_DESCRIPTION
    );

    ctx.communityPicoId = entry.picoID;
    ctx.communityUiEci = uiEci;
    ctx.communityQueryEci = entry.Tx;
    ctx.manifoldAppEci = appEci;

    const name = await query<string>(state, uiEci, "io.picolabs.pico-engine-ui", "name");
    assert.equal(name, COMMUNITY_NAME);

    const description = await getCommunityDescription(state, entry.Tx);
    assert.equal(description, COMMUNITY_DESCRIPTION);

    const rids = await waitForInstalledRids(state, uiEci, COMMUNITY_RULESETS, "Community pico");
    assertIncludes(rids, [...COMMUNITY_RULESETS], "Community pico");

    assert.equal(entry.Tx_role, "manifold_community");
    assert.ok(entry.Id && entry.Tx, "Manifold→community subscription missing Id or Tx channel");
  });

  it("adds the thing to the community with a subscription on both picos", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();

    assertTruthy(ctx.thingPicoId, "thingPicoId not set");
    assertTruthy(ctx.communityPicoId, "communityPicoId not set");

    await addThingToCommunity(state, bootstrap, ctx.thingPicoId, ctx.communityPicoId);
    await waitForCommunityMembership(state, ctx.thingQueryEci, ctx.communityQueryEci, true);

    const thingCommunities = await getThingCommunities(state, ctx.thingQueryEci);
    const communityThings = await getCommunityThings(state, ctx.communityQueryEci);

    assert.equal(thingCommunities.length, 1);
    assert.equal(communityThings.length, 1);

    const thingSide = thingCommunities[0];
    const communitySide = communityThings[0];

    assert.equal(thingSide.Tx_role, "community");
    assert.equal(communitySide.Tx_role, "thing");
    assert.equal(thingSide.Id, communitySide.Id);
    assert.equal(thingSide.name, COMMUNITY_NAME);
    assert.equal(thingSide.description, COMMUNITY_DESCRIPTION);
    assert.equal(communitySide.name, THING_NAME);
  });

  it("removes the thing from the community without deleting either pico", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();

    await removeThingFromCommunity(state, bootstrap, ctx.thingPicoId, ctx.communityPicoId);
    await waitForCommunityMembership(state, ctx.thingQueryEci, ctx.communityQueryEci, false);

    const thingCommunities = await getThingCommunities(state, ctx.thingQueryEci);
    const communityThings = await getCommunityThings(state, ctx.communityQueryEci);

    assert.equal(thingCommunities.length, 0);
    assert.equal(communityThings.length, 0);

    const things = await getThings(state, ctx.manifoldAppEci);
    const communities = await getCommunities(state, ctx.manifoldAppEci);
    assertTruthy(things[ctx.thingPicoId], "thing missing from Manifold after detach");
    assertTruthy(communities[ctx.communityPicoId], "community missing after thing detach");
  });

  it("deletes the community and thing picos from Manifold", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();

    await deleteCommunity(state, bootstrap, ctx.manifoldAppEci, ctx.communityPicoId);
    await deleteThing(state, bootstrap, ctx.manifoldAppEci, ctx.thingPicoId);

    await assertChildGone(state, bootstrap.manifoldUiEci, COMMUNITY_NAME);
    await assertChildGone(state, bootstrap.manifoldUiEci, THING_NAME);

    const things = await getThings(state, ctx.manifoldAppEci);
    const communities = await getCommunities(state, ctx.manifoldAppEci);

    assert.equal(things[ctx.thingPicoId], undefined);
    assert.equal(communities[ctx.communityPicoId], undefined);
  });
});
