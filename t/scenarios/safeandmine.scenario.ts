import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { assertTruthy } from "../lib/assert.js";
import { THING_RULESETS } from "../lib/expected-rulesets.js";
import {
  enableNotificationChannel,
  waitForNotification,
} from "../lib/notifications.js";
import {
  getContactInfo,
  getThingWranglerId,
  notifyTagScan,
  updateContactInfo,
} from "../lib/safeandmine.js";
import {
  addTagToThing,
  getTagRegistryStore,
  removeTagFromThing,
  SAFEANDMINE_TAG_DOMAIN,
  scanRegistryTag,
  waitForRegistryTag,
} from "../lib/tag-registry.js";
import {
  createThing,
  deleteThing,
  waitForInstalledRids,
} from "../lib/manifold.js";
import { getTestBootstrap, getTestState } from "../lib/test-context.js";

const THING_NAME = "SafeAndMine Test Thing";
const TAG_ID = "TESTTAG01";
const REGISTRY_TAG_ID = "TAG02";

describe("safeandmine", () => {
  it("stores contact information on a thing pico", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const { entry, uiEci, appEci } = await createThing(state, bootstrap, THING_NAME);

    await waitForInstalledRids(state, uiEci, THING_RULESETS, "SafeAndMine thing");

    await updateContactInfo(state, entry.Tx, {
      name: "Test Owner",
      email: "owner@example.com",
      phone: "555-0100",
      message: "Please return this item.",
      shareName: true,
      shareEmail: false,
    });

    const info = await getContactInfo(state, entry.Tx);
    assert.equal(info.name, "Test Owner");
    assert.equal(info.email, "owner@example.com");
    assert.equal(info.phone, "555-0100");
    assert.equal(info.message, "Please return this item.");
    assert.equal(info.shareName, true);
    assert.equal(info.shareEmail, false);

    await deleteThing(state, bootstrap, appEci, entry.picoID);
  });

  it("sends a tag-scan notification to the Manifold inbox", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const { entry, appEci } = await createThing(state, bootstrap, THING_NAME);

    const wranglerId = await getThingWranglerId(state, entry.Tx);
    await enableNotificationChannel(state, appEci, wranglerId, "Manifold");
    await notifyTagScan(state, entry.Tx, TAG_ID);

    const notification = await waitForNotification(
      state,
      appEci,
      n =>
        n.picoId === wranglerId &&
        n.app === "SafeAndMine" &&
        n.message.includes(TAG_ID),
      `SafeAndMine tag-scan notification for ${TAG_ID}`
    );

    assert.equal(notification.thing, THING_NAME);
    assert.match(notification.message, /has been scanned/);

    await deleteThing(state, bootstrap, appEci, entry.picoID);
  });

  it("registers a tag in the tag registry and deregisters it", async () => {
    const state = getTestState();
    const bootstrap = getTestBootstrap();
    const registrationEci = bootstrap.status.tag_registry_registration_eci;
    assertTruthy(registrationEci, "tag_registry_registration_eci not set");

    const { entry, appEci } = await createThing(state, bootstrap, THING_NAME);

    await addTagToThing(state, entry.Tx, REGISTRY_TAG_ID, SAFEANDMINE_TAG_DOMAIN);

    const registered = await waitForRegistryTag(
      state,
      registrationEci,
      REGISTRY_TAG_ID,
      SAFEANDMINE_TAG_DOMAIN,
      true
    );
    assert.ok(typeof registered === "object" && registered.did, "registry entry missing DID");

    const store = await getTagRegistryStore(state, registrationEci);
    assert.ok(store[SAFEANDMINE_TAG_DOMAIN]?.[REGISTRY_TAG_ID], "tag missing from get_tag_store");

    const scanned = await scanRegistryTag(
      state,
      registrationEci,
      REGISTRY_TAG_ID,
      SAFEANDMINE_TAG_DOMAIN
    );
    assert.equal(scanned?.did, registered.did);

    await removeTagFromThing(state, entry.Tx, REGISTRY_TAG_ID, SAFEANDMINE_TAG_DOMAIN);
    await waitForRegistryTag(
      state,
      registrationEci,
      REGISTRY_TAG_ID,
      SAFEANDMINE_TAG_DOMAIN,
      false
    );

    const afterRemove = await scanRegistryTag(
      state,
      registrationEci,
      REGISTRY_TAG_ID,
      SAFEANDMINE_TAG_DOMAIN
    );
    assert.equal(afterRemove, null);

    await deleteThing(state, bootstrap, appEci, entry.picoID);
  });
});
