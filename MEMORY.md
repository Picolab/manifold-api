# MEMORY: Manifold Thing-Creation Delegation + Sensor Network Migration

Working context so we don't lose it across sessions.

## WHERE WE ARE (2026-06-08)

### Summary
The sensor network → Manifold migration is **working in manual/cursory testing** (bootstrap,
community + sensor.community install, sensor initiation, community↔thing subscription, readings
path). The **local TS + Docker integration test harness** in `manifold-api/t/` is **working**
(parse → one Docker container → bootstrap → 14 scenarios → teardown). PDS work remains **parked**.

**Recommended runtime:** Node **22 LTS** (project requires 18+; 20 is maintenance-only).
After upgrade: `nvm install 22 && nvm use 22 && npm install && npm test`.

### Verified working (manual, 2026-06-04)
- Profile on owner pico
- `sensor create_community` via `io.picolabs.sensor.network_bootstrap` → Manifold creates
  community child, `io.picolabs.community` installed (manifold_pico), `io.picolabs.sensor.community`
  installed (bootstrap), Manifold↔community subscription
- `sensor initiation` → thing created, sensor rulesets installed, community↔thing subscription
- Readings / threshold path (2026-06-03 baseline; re-validated after recent fixes)
- `removeCommunity` → subscription removed **and** child pico deleted (`child_deletion_request`)

### Recent fixes (2026-06-04 session)
| Area | Fix |
|------|-----|
| `io.picolabs.community.krl` | Stray backtick after `meta { }` (blocked registration); valid `addThing` KRL; `autoAcceptThing` accepts `Rx_role`/`Tx_role` |
| `io.picolabs.manifold_pico.krl` | `install_community_ruleset` URL fallback via `rulesetByRID("io.picolabs.manifold_pico")`; `deleteCommunity` uses `child_deletion_request` + `eci` |
| `io.picolabs.sensor.network_bootstrap.krl` | Valid single postlude (`fired { } else { }`); prelude direct path reads; `sensor_bootstrap` on `child_initialized` |
| `io.picolabs.sensor.community.krl` | Parse error: nested ent assign uses `{[key, "field"]}` not `{key}{"field"}` |
| KRL hygiene | One action block; one postlude; prelude = name decls; `ent:{key} :=` not `.put()` — see **KRL conventions** below |

### Still open / not fully verified
- **Notification delivery** — `addNotification` fires but channels must be provisioned via
  `ent:notification_settings` / bootstrap `community_ready` → `change_notification_setting`
- **External channels** — SMS/Prowl need Twilio/Prowl RS + owner profile phone on Manifold pico
- **Parse gate** — `npm run test:parse` fails on 2 pending-review RSs: `io.picolabs.alexa.krl`,
  `io.picolabs.google_assistant.krl` (undefined `rids` in select). Fix or add to `parseExclude`
- **Automated regression** — manifold-api harness has 14 scenarios; sensor-network tests
  not yet added (`dependsOn` planned)

### Integration test harness (WORKING — 2026-06-08)

**Location:** `manifold-api/t/` (see `t/README.md`)

**Decisions locked in:**
- Option 3: TypeScript integration tests against a real engine
- **Single Docker container** per `npm test` run; image default `picolabs/pico-engine:latest`
  (override `PICO_ENGINE_IMAGE` or `t/config.json` → `dockerImage`)
- Host port random **5001–6999**; `PICO_ENGINE_HOME` on host at
  `/tmp/<repoName>-pico-test-<runId>` mounted as `/var/pico-image`
- Container env: `TESTING=1`, `PICO_ENGINE_BASE_URL=http://localhost:<port>`
- Repo dirs bound to `/var/<repo-name>` (e.g. `/var/manifold-api`)
- **Parse first:** all `*.krl` under each mount; `parseExclude` minimatch patterns per mount
  (currently `OLD/**`, `fix/**`)
- **Teardown:** pass → remove container + delete pico home; fail → leave container up;
  `--keep` / `--retain-logs` flags
- **Local only** for now (no CI yet)
- **Dependencies:** `sensor-network/t` will declare `dependsOn: manifold-api` (not built yet)

**Architecture (parent + child):**
- **`t/run.ts` (parent):** parse gate → `setup()` (one container) → `setupManifoldBootstrap()` →
  write `t/.test-context.json` → spawn child `node --test` → `teardown()` in `finally`
- **Child subprocess:** runs `t/scenarios/*.scenario.ts` via `node --import tsx --test`
  (`t/lib/run-tests.ts`). Reads bootstrap/state from `t/.test-context.json`
  (`MANIFOLD_TEST_CHILD=1`).
- **Why subprocess:** Node 18's programmatic `run()` stream never emits `end`, so
  `await finished(stream)` hung forever → teardown never ran → **container leak** (124 orphaned
  `/tmp/manifold-api-pico-test-*` dirs cleaned 2026-06-08). Subprocess exits cleanly.

**Scenario files** (order in `t/lib/run-tests.ts`):
| File | Coverage |
|------|----------|
| `health.scenario.ts` | Engine HTTP reachable |
| `bootstrap.scenario.ts` | Tag registry, skills registry, owner, manifold picos |
| `thing-community.scenario.ts` | Create thing/community, add/remove, delete |
| `safeandmine.scenario.ts` | Contact info, tag-scan notification, tag registry register/deregister |
| `journal.scenario.ts` | Install journal on thing, create/edit/delete entries |

**Helpers:** `t/lib/tag-registry.ts`, `t/lib/safeandmine.ts`, `t/lib/journal.ts`,
`t/lib/notifications.ts`, `t/lib/manifold.ts`

**Harness gotchas (learned 2026-06-08):**
- **Query args:** Sky Cloud expects plain values (`?tagID=TAG02`), not JSON-stringified
  (`"TAG02"`). Fixed in `t/lib/engine.ts` `serializeQueryArg()`.
- **SafeAndMine on things:** events/queries must use the thing's **Manifold subscription channel**
  (`entry.Tx`), not the UI channel (policy blocks UI).
- **Journal:** install via UI channel; exercise CRUD via `entry.Tx`. `getEntry(title)` param
  doesn't work — call `getEntry()` with no args and filter in TS.
- **Notifications toggle:** use thing's **wrangler id** for `change_notification_setting`, not
  `entry.picoID`.
- **Leftover resources:** `npm run test:cleanup` removes labeled containers + `/tmp/*-pico-test-*`
  dirs. Use after failed/hung runs.

**Commands:**
```bash
cd manifold-api && npm install
npm run test:parse     # krl-compiler --verify on mounted *.krl
npm test               # parse + docker + scenarios + teardown (~18s on Node 22)
npm test -- --skip-parse   # docker + scenarios only
npm run test:keep      # leave container running
npm run test:cleanup   # remove leftover test containers and /tmp pico homes
```

**Runtime state (gitignored):**
- `t/.runtime.json` — port, container name, pico home path
- `t/.test-context.json` — bootstrap/state for scenario subprocess (written per run)

**Signaling test mode to KRL:** `TESTING=1` is for **setup scripts only**. Rulesets cannot read
process env. Use `meta:rulesetConfig{"testing"}` on install and/or a test-only RS (planned).

**Next harness phases:**
1. ~~Docker layer + parse gate~~ ✓
2. ~~manifold-api scenarios (bootstrap, thing/community, safeandmine, journal)~~ ✓ (14 tests)
3. **sensor-network/t** — `dependsOn` manifold-api, sensor bootstrap + initiation scenarios
4. Test RS for open channels / scenario conductor (optional)

### SafeAndMine tag registry (fixed for tests — 2026-06-08)

**Test flow:** `safeandmine new_tag` on thing → channel → `register_tag` on registry pico →
`scan_tag` / `get_tag_store` confirm → `safeandmine deregister` → gone from registry.

**KRL fixes in `io.picolabs.safeandmine.krl`:**
- **`new_tag` guard:** In KRL, `if X then noop(); fired { }` runs `fired` when **X is true**.
  Original `if (tagID.length() > 1) then noop()` was correct for non-empty tags; a bad "fix" to
  `< 1` inverted it and blocked all registrations.
- **`send_registry_request`:** read `event:attr("channel"){"id"}` (attrs pass through
  `wrangler new_channel_request` → `channel_created`).
- **`deregister_tag`:** split into two rules — (1) always notify registry when
  `tagToDelete && domain && ent:registry_eci`; (2) local channel cleanup only when thing has
  `ent:tagStore` entry. Previously required local tagStore (often empty if
  `tag_register_response` hadn't arrived) so registry never got deregistered.
- **`deregister` event:send:** use `"name": "deregister_tag"` not `"type"`.
- **`notify`:** resolve Manifold channel via `picoQuery(parent, wrangler, channels, {tags:
  "manifold"})`; use `wrangler:myself(){"id"}` for picoId.

**Registry RS (`io.picolabs.new_tag_registry.krl`):** `register_tag` sends
`tag_register_response` with `"name"` not `"type"`.

### Parked
- **PDS** — see FUTURE section below; profile works on owner pico for now

---

## Two repos involved
- `manifold-api` (this repo, `/Users/pjw/Dropbox/prog/picolabs/manifold-api`) — the Manifold
  KRL rulesets being updated for Pico Engine 1.0. Think of Manifold as the "OS".
- `sensor-network` (`/Users/pjw/prog/picolabs/sensor-network`) — the real sensor
  network. Think of it as an "application" running on Manifold.
  - NOTE: ignore the `wovyn.*` rulesets in that repo (legacy/parallel).
  - NOTE: the `neighborhood_temps` ruleset in `manifold-api` is a separate gossip teaching
    example, NOT the sensor network. Red herring.

## Overall goal
Fold the sensor network into Manifold's data model:
- The sensor community pico becomes a Manifold **community** pico (runs `io.picolabs.community`).
- Each sensor becomes a Manifold **thing** pico (runs `io.picolabs.thing`).
- Sensors join their community via a Manifold **community<->thing subscription**, replacing the
  old parent/child (`wrangler:parent_eci()` / `wrangler:children()`) relationship.

## Desired user workflow
1. Open Manifold and create a new community.
2. Install the sensor-network ruleset (`io.picolabs.sensor.community`) on that community pico,
   giving it capabilities beyond a plain Manifold community (which is just plumbing).
3. Send a "create sensor" event to the **sensor community pico** (not the Manifold pico),
   because that is where the specialized functionality and state live. This is a deliberate
   break from traditional Manifold flow. The sensor still ends up as a plain Manifold thing
   created by the Manifold pico, then specialized afterward. Supports multiple sensor
   communities coexisting (e.g. home and cabin).

## Key design principles
- **Manifold stays generic (OS).** It creates a bare thing, installs only `io.picolabs.thing`
  (which self-installs `safeandmine` -- intentionally kept), and subscribes it as
  `manifold_thing`. Manifold installs NO sensor-specific rulesets.
- **Specialized setup belongs to the app (sensor network).** After the thing exists, control
  passes BACK to the originating community pico, which installs the sensor-type rulesets and
  configures the thing.
- **Callback is contingent.** The completion callback fires only when BOTH `callback_eci` and
  `rcn` (correlation id) are present on the `create_thing` event. Without them, Manifold's
  `create_thing` behaves exactly as before. Delegation is purely additive.
- **No scheduled "wait" events.** Use an event-driven callback correlated by `rcn`.
- **Correlation pattern** (from Fuse `report_correlation_number`, in
  `/Users/pjw/prog/kynetx/Fuse-API/api/fuse_fleet.krl`): the delegating pico mints an `rcn`,
  stores context under it in an entity var, passes only `{callback_eci, rcn}` through the chain,
  and reloads context by `rcn` on the callback. Fuse fleet:vehicle is the analog of
  community:thing.

## Delegation flow
```
User --"sensor initiation"{name,type,color}--> Sensor Community pico
   (community pico runs io.picolabs.community + io.picolabs.sensor.community)
        | mint rcn; ent:pending{rcn} = {name,sensor_type,color,url_rids,config}
        | event:send manifold create_thing {name, callback_eci, rcn} to parent
        v
   Manifold pico (io.picolabs.manifold_pico)
        | createThing -> child pico
        | install io.picolabs.thing (self-installs safeandmine)
        | subscribe manifold_thing; trackThingSubscription records ent:things
        | IF callback registered: event:send community thing_created
        |     {rcn, thingPicoID, thing_eci} back to callback_eci
        v
   Sensor Community pico (finish_sensor)
        | load ent:pending{rcn}
        | raise community add_thing {eci: thing_eci}  (establishes community<->thing subscription)
        | install sensor-type rulesets on thing (wrangler install_ruleset_request)
        | record sensor; clear ent:pending{rcn}
        v
   Thing pico now runs io.picolabs.thing + router + sensor.thresholds + dragino/iotplotter
```

Runtime reporting (after a sensor is set up):
- Sensor reading: router raises `sensor new_readings` -> `route_to_community` raises
  `thing community_notify` -> `io.picolabs.thing` `notifyCommunity` sends
  `community thing_event_occurred` to each community -> sensor.community `ingest_thing_event`
  re-raises `sensor new_readings` -> `catch_new_readings` stores it.
- Threshold violation: `sensor.thresholds` detects on the thing, raises
  `sensor threshold_violation` -> `send_violation_to_community` raises `thing community_notify`
  -> ... -> `ingest_thing_event` -> `catch_threshold_violation` (Prowl/Twilio) on the community.

## Implementation status: DONE
All edits below are complete (KRL is not compiled/linted here; needs runtime testing).

### `manifold-api/io.picolabs.manifold_pico.krl`
- `createThing` already forwards `event:attrs` into `new_child_request`, so `callback_eci`/`rcn`
  propagate to `child_initialized`.
- Added rule `stashThingCallback` (on `child_initialized` for `manifold_create_thing`): if both
  `callback_eci` and `rcn` present, store `ent:pending_callbacks{eci} = {callback_eci, rcn}`.
- Added rule `fireThingCreatedCallback` (on `subscription_added` where `Tx_role == thing_role`):
  if a callback is registered for this picoID, `event:send` `community thing_created`
  `{rcn, thingPicoID, thing_eci}` to `callback_eci`, then clear the entry.

### `sensor-network/io.picolabs.sensor.community.krl`
- Added `use module io.picolabs.subscription alias subscription`.
- `new_sensor` (select `sensor initiation`) rewritten to delegate: mint `rcn`, store
  `ent:pending{rcn}`, `event:send manifold create_thing {name, callback_eci, rcn}` to
  `wrangler:parent_eci()`. `callback_eci = subscription:wellKnown_Rx(){"id"}`.
- Added `finish_sensor` (select `community thing_created`): reload `ent:pending{rcn}`, raise
  `community add_thing {eci: thing_eci}`, raise `sensor install_rulesets`, record
  `ent:sensor_things{thingPicoID}`, clear `ent:pending{rcn}`.
- Added `install_sensor_rulesets` (select `sensor install_rulesets`): `foreach url_rids`,
  `event:send wrangler install_ruleset_request` to `thing_eci` with `absoluteURL: meta:rulesetURI`.
- Added `ingest_thing_event` (select `community thing_event_occurred` where `domain == sensor`):
  re-raise `sensor <type>` with inner attrs.
- `lastTemperatures` now enumerates members via `sensorThings()` (subscriptions filtered by
  `Tx_role == "thing"`) + `wrangler:skyQuery`, not `wrangler:children()`.
- Removed the now-dead `sensor_initialization` rule (it depended on `new_child_created`).

### `sensor-network/io.picolabs.lht65.router.krl`
- `route_to_community` now raises `thing community_notify` instead of `event:send` to
  `wrangler:parent_eci()`.

### `sensor-network/io.picolabs.lse01.router.krl`, `io.picolabs.lsn50.router.krl`, `io.picolabs.ldds20.krl` (2026-06-03)
- Added the same `route_to_community` rule as `lht65.router` (select `sensor new_readings`,
  raise `thing community_notify` with `{domain:"sensor", type:"new_readings", attrs: readings}`).
  These routers previously had no forwarding rule; this is a net add.

### `sensor-network/io.picolabs.iotplotter.krl` (2026-06-03)
- `show_configuration()` is now the single source of truth for effective config: it reads
  `meta:rulesetConfig{"api_key"|"feed_id"}` first, falling back to `ent:api_key`/`ent:feed_id`.
- `send_data_to_IoTPlotter` only calls `send_payload` when BOTH `api_key` and `feed_id` are
  non-null; postlude changed from `always` to `fired` so it only logs the POST response when a
  payload was actually sent.

### `manifold-api` + `sensor-network`: `__testing` removed (2026-06-03)
- Removed all `__testing` declarations (from `shares`/`provides` lists and `global` assignments,
  plus weather's prose comments) across the 18 manifold-api rulesets that had them.
  sensor-network had none. Repo-wide search for `__testing` returns zero matches.

### `sensor-network/io.picolabs.sensor.thresholds.krl`
- `send_violation_to_parent` renamed to `send_violation_to_community`, now raises
  `thing community_notify` instead of sending to `parent_eci`.

## Open / assumed decisions
- Callback event is `community thing_created` (could be namespaced `manifold thing_created`).
- Manifold does NOT call `add_thing_to_community`; the community subscribes itself via its own
  `community add_thing` in `finish_sensor`. Keeps Manifold minimal.
- Routers `lht65.router`, `lse01.router`, `lsn50.router`, and `ldds20` now all forward readings
  via `route_to_community` raising `thing community_notify` (2026-06-03). `wl03a_lb` still has no
  `route_to_community` and can adopt the same pattern when needed.
- `initialize_temperatures` in sensor.community still references `ctx:children` (now stale,
  harmless dead path). Not in scope.

## Test plan (not yet run)
- Create community, install `sensor.community`, send `sensor initiation` -> thing pico created,
  `io.picolabs.thing` + sensor rulesets installed, community/thing subscription established,
  `ent:pending{rcn}` cleared.
- Plain `manifold create_thing` (no `callback_eci`/`rcn`) -> identical-to-today behavior.
- Two communities (home, cabin) create sensors concurrently -> correlation keeps them separate.
- Sensor heartbeat -> reading reaches the correct community; threshold alerts still fire.

## Notifications are a Manifold platform service (future cleanup)
Insight: notification delivery is part of the service platform Manifold provides, so sensors
and communities should NOT re-implement it.
- On the Manifold pico: `io.picolabs.notifications` (orchestrator) + channel rulesets
  `io.picolabs.prowl_notifications`, `io.picolabs.twilio_notifications`,
  `io.picolabs.manifold.email_notifications`, `io.picolabs.manifold.text_message_notifications`.
  These are installed by `io.picolabs.manifold_pico` (`initializationRids` / `updateManifoldVersion`)
  and driven by events (no `use module`). A thing raises `manifold add_notification` to the
  Manifold pico (see `io.picolabs.safeandmine` `notify` rule), and `notifications` fans out to
  Twilio/Prowl/Email/Text per `ent:notification_settings`.

Sensor-network state: DONE (interim cleanup complete).
- Removed `use module io.picolabs.prowl` and `use module io.picolabs.twilio.sms` from the
  sensor_community meta block, and removed the now-unused `sms_notification_number` global.
- `catch_threshold_violation` now routes through the Manifold platform: it finds the Manifold
  pico via the `manifold_pico`-role subscription Tx and `event:send`s
  `manifold add_notification {picoId, thing, app:"Sensor Network", message, ruleset}` (same path
  as safeandmine's `notify`). Manifold fans out to Twilio/Prowl/Email/Text per notification_settings.
- `ingest_thing_event` now carries the originating thing's `sender_id` into the re-raised sensor
  attrs so `catch_threshold_violation` has the source thing's picoId.

TODO (still open): for notifications to actually deliver, the Manifold pico needs
`ent:notification_settings{picoId}{rid}` populated for each sensor-thing (via
`manifold set_notification_settings` / `change_notification_setting`). Decide how/when the
sensor community provisions those settings for its things. Also consider whether non-violation
readings should ever generate notifications (currently only threshold violations do).

Verified 2026-06-03: threshold violation reaches the Manifold pico and `addNotification` fires,
but nothing is stored because every postlude action is gated on
`ent:notification_settings{picoId}{rs}{channel} == true`, and settings were unset. Here
picoId = sensor thing's id (sender_id), rs = "io.picolabs.sensor.community".
The normal seeding path (`manifold update_app_list`/`update_version` -> `updateManifoldAppList`
queries each thing's `apps` discovery -> `set_notification_settings`) does NOT work for sensor
things because they have no `manifold apps` discovery rule.
DECISION (for now): leave provisioning MANUAL. To enable a thing, send to the Manifold pico:
  domain: manifold, name: change_notification_setting,
  attrs: { id: <thing picoId>, app_name: "io.picolabs.sensor.community", option: "Manifold" }
(from unset, the toggle sets it true). Revisit durable provisioning later (options considered:
community provisions in finish_sensor; notifications defaults to deliver-when-unset; add a
`manifold apps` discovery rule to sensor things).

## Notifications normalization (in progress, 2026-06-03)
Goal: normalize how notifications work. Background: the original Manifold had NO community
concept; the notification unit of identity is `(thing picoId, app ruleset rid)` --
`ent:notification_settings{id}{rs}{channel}`. Apps self-register a `manifold apps` discovery rule
that Manifold HTTP-polls per `manifold_thing` subscription to seed settings; the send contract is
`manifold add_notification {picoId, thing, app, message, ruleset}` to the Manifold pico.

Cleanups done in `io.picolabs.notifications` (no behavior change unless noted):
- Removed the convoluted `setNotificationSettings` function (it only RETURNED an initialized
  copy). `setDefaultNotificationSettings` now writes inline with a guarded path `put`:
  `ent:notification_settings := ent:notification_settings.defaultsTo({}).put([id, app_name],
  default_settings()) if ent:notification_settings{[id, app_name]}.isnull();`
- Added `global` `channels` = canonical list `["Manifold","Twilio","Prowl","Email","Text"]`
  (one per line, commented with each channel's action). Case matters: these are the exact
  `ent:notification_settings{..}{..}{channel}` keys.
- Added `default_settings()` = fold over `channels` -> `{Manifold:true, rest:false}` (single
  source of truth for seeded defaults).
- Added `isEnabled(picoId, rs, channel)` helper; `addNotification` gates every channel through it
  and uses one shared `notify_attrs` superset `{Body, rs, id, application, thing}` for all raises.
- Renamed rule `changeNotificationSetting` -> `toggleNotificationSetting` (it toggles, doesn't
  set). Now validates the freeform `option` against `channels` (`channels >< option`); unknown
  channel -> `error warn` and no write (previously would create a junk key). Event name is still
  `manifold change_notification_setting` (unchanged contract).
- KRL limitation noted in code: the 4 external raises (twilio/prowl/email/text_messenger) can't be
  collapsed into a `foreach channels` loop because `raise` requires a STATIC event domain.

"Manifold" channel = in-app inbox only: appends to `ent:notifications` (badge via
`getBadgeNumber`, feed via `getNotifications`) + `ent:notification_state`. No outbound delivery.
The 4 external channels are independent/gated separately, so delivered-but-not-logged is possible
if Manifold is off while another channel is on.

### Twilio vs Text channels (both send SMS via Twilio) -- consolidation candidate
Three rulesets, two channels, same delivery mechanism (Twilio REST). Differences:
- "Twilio" channel = `io.picolabs.twilio_notifications` (self-contained). Per-(id,rs) credentials
  (`rs_toSID`,`rs_toToken`,`fromPhone`,`toPhone`); posts to Twilio directly; NO verification;
  sends Body verbatim; bring-your-own-account per app.
- "Text" channel = `io.picolabs.manifold.text_message_notifications` (registry/policy) +
  `io.picolabs.manifold.text_messenger` (transport). Uses ONE shared Manifold Twilio account
  (text_messenger globals `twilioSID`/`twilioAuthToken`/`twilioNumber`); enforces phone
  VERIFICATION (set_toPhone -> start_verification -> texts a link -> receiveVerification appends
  to `ent:verified`; `send_notification` only fires `if isVerified(...)`); prepends
  "Notification from <thing>: "; and event:sends cross-pico to a HARDCODED eci
  "CqpUcKndBo8xeioWJFQM47" + host https://manifold.picolabs.io:9090 (a separate shared
  text-messenger service pico) -- a real coupling smell.
- Both seed a default number from `io.picolabs.profile` `getContacts` via `getDefaultNumber`.
RECOMMENDATION: collapse to ONE SMS channel (the central/verified "Text" model fits a sensor
network better than per-app Twilio creds for unattended things). Remove the hardcoded eci/host
coupling when doing so.

### STATUS: normalization IMPLEMENTED 2026-06-03 (needs runtime testing)
Implemented all 8 steps below. Specifics & caveats:
- `io.picolabs.notifications` rewritten: channels `["Manifold","SMS","Prowl"]`; settings keyed
  `{picoId}{channel}`; `isEnabled(picoId, channel)`; `getSettings(id)`; `toggleNotificationSetting`
  now `{id, option}`; `addNotification` resolves `to_phone` via
  `wrangler:picoQuery(parent_eci, "io.picolabs.profile", "getOwnerPhone")` ONLY when SMS enabled,
  and fans out Manifold(inbox)/SMS(raise twilio notify_through_twilio)/Prowl(raise prowl
  notify_through_prowl). Discovery machinery (updateManifoldAppList, setDefaultNotificationSettings,
  app_list, getID) REMOVED; `default_settings()` kept dormant; dropped unused
  manifold_pico/subscription `use module`s.
- NEW `io.picolabs.twilio.sms` (in manifold-api): temp-network module + event rule
  `twilio notify_through_twilio` -> `send_sms(Body, to)`; `save_config` now on `twilio configuration`.
- NEW `io.picolabs.prowl` (in manifold-api): temp-network module + event rule
  `prowl notify_through_prowl` -> `notify(title=thing||application, Body)`.
- DELETED: `io.picolabs.twilio_notifications`, `io.picolabs.prowl_notifications`,
  `io.picolabs.manifold.text_message_notifications`, `io.picolabs.manifold.text_messenger`.
- KEPT but UNINSTALLED: `io.picolabs.manifold.email_notifications` (Email channel deferred).
- `io.picolabs.profile`: REWRITTEN (2026-06-03). Removed all google/github + "other"/favorites
  machinery and the verify defactions. Now a simple flat `ent:profile {name, email, phone}` with
  query fns `getProfile/getEmail/getPhone/getOwnerPhone/getOwnerEmail` and update rules
  `profile update {name?, email?, phone?}` (ignores empty) + `profile clear {field}`.
  Moved `io.picolabs.google_signin` + `io.picolabs.github_signin` into `OLD/` (git mv).
- `io.picolabs.manifold_owner`: updated the "updates" channel queryPolicy to allow the new profile
  query fns (getProfile/getEmail/getPhone/getOwnerPhone/getOwnerEmail) instead of the old
  getOther/getSection/availableSection/unFavAll/getContacts.
  RUNTIME CAVEAT: `createUpdateChannel` only creates the channel if absent, so an already-running
  owner pico keeps the OLD policy until the "updates" channel is recreated (or policy patched).
  (This "updates" channel is for external UI/LLM queries; it is NOT the channel `parent_eci()`
  returns -- see picoQuery note below.)
- picoQuery migration (2026-06-04): replaced ALL `wrangler:skyQuery(...)` with
  `wrangler:picoQuery(...)` (same params/order, drop-in) across notifications, thing, community,
  manifold_import, email_notifications, and sensor-network sensor.community. skyQuery is
  deprecated AND only did HTTP; pico-engine v1.X blocks HTTP on FAMILY channels (parent<->child).
  picoQuery uses `ctx:query()` locally on the same host, so it works over family channels. This
  RESOLVES the earlier worry about the Manifold pico's `parent_eci()` (a family channel to the
  Owner pico) querying profile `getOwnerPhone` for SMS -- picoQuery does it locally, bypassing the
  HTTP/channel-policy issue. NOTE the error map key changed: `skyQueryError` -> `picoQueryError`.
- `io.picolabs.manifold.email_notifications` (uninstalled) still calls profile `getContacts`, which
  no longer exists -- update it if/when the Email channel is revived.
- `io.picolabs.manifold_pico`: `initializationRids` + `updateManifoldVersion` now install
  notifications/twilio.sms/prowl only.
- `sensor.community` `catch_threshold_violation`: `picoId = meta:picoId` (community is subject);
  originating sensor kept in `thing` + new `sensor_id` attr.
- CAVEAT: `io.picolabs.profile` still has `verifyEmail`/`verifyPhone`/`verifyBoth` defactions (called
  from `save_other_profile`) that `event:send` to the now-deleted `text_messenger`/email service
  picos. These are now harmless UNHANDLED no-ops (verification removed). Clean up later if desired.
- CAVEAT: opt-in means a freshly created sensor community delivers NOTHING until its picoId is
  toggled (`manifold change_notification_setting {id: <community picoId>, option: "Manifold"|"SMS"|
  "Prowl"}`) or provisioned by the bootstrap RS.
- Twilio/Prowl global config events: `twilio configuration {twilio_account_sid, twilio_auth_token,
  twilio_from_number}` and `prowl configuration {apikey, providerkey, application}` to the Manifold pico.

### FINALIZED normalization plan (2026-06-03, decisions locked)
New model context: the old Manifold was multi-tenant (ONE Manifold pico for many owners -- hence
the github/google signin rulesets). New model = each owner has their OWN Manifold pico (child of
the owner's root pico), so it's personal. The owner's root (parent) pico runs `io.picolabs.profile`
which stores the owner's contact points (email/phone). That is the single source of contacts.

Decisions (locked):
- KEYING: by SUBJECT pico only -> `ent:notification_settings{picoId}{channel}`. NO ruleset/app
  dimension (may add later). A subject either notifies or it doesn't.
- CHANNELS: `["Manifold","SMS","Prowl"]`. Twilio+Text collapse into one `SMS`. Email DROPPED for now.
- VERIFICATION: REMOVED. Trust the contacts in the owner's profile.
- PROVIDER CONFIG: global, configured ONCE on the Manifold pico (not per app). Use the simpler
  sensor-network rulesets `io.picolabs.twilio.sms` (account_sid/auth_token/from_number) and
  `io.picolabs.prowl` (apikey/providerkey/application). KEEP their `send_sms`/`notify` defactions
  and have new event-driven rules call them.
- RECIPIENT RESOLUTION: in the orchestrator. `addNotification` does one
  `skyQuery(parent_eci, "io.picolabs.profile", "getOwnerPhone")` and passes `to_phone` in
  `notify_attrs`; channels stay dumb.
- SEEDING: NONE (no_seed). Remove the `apps` discovery machinery (`updateManifoldAppList`,
  `setDefaultNotificationSettings`, `app_list`, `getID`). Entries are created on demand by the
  existing toggle (creates `{picoId}{channel}` from unset) or by the future bootstrap RS (which can
  call the dormant `default_settings()`). CONSEQUENCE: notifications are fully OPT-IN -- nothing
  (even in-app Manifold) delivers for a subject until its picoId is toggled/provisioned.

SUBJECT PRINCIPLE: the subject picoId is whoever originates the notification's PURPOSE, not who
relays it. Two independent paths coexist:
- Community-function notifications (e.g. sensor threshold violations: a thing detects, the community
  catches via ingest_thing_event -> catch_threshold_violation and forwards) -> subject = COMMUNITY
  picoId (`meta:picoId`). One toggle governs the whole network's sensor alerts.
- Thing-level notifications (a thing as a plain Manifold thing, independent of any community) ->
  subject = the THING's own picoId. Example: a safeandmine QR tag stuck on a temperature sensor ->
  S&M "tag scanned" alerts go directly from the S&M app to the Manifold pico under the thing's
  picoId, NOT through the community. `safeandmine`'s `notify` already does this; DO NOT reroute it.
So one physical sensor can have TWO settings entries (its own picoId for thing-level apps; the
community picoId for network alerts), toggled independently. (No single "mute this sensor
everywhere" switch under per-pico keying; that would need the deferred per-app dimension.)

Implementation steps (in order):
1. `io.picolabs.notifications`: channels -> ["Manifold","SMS","Prowl"]; drop `rs` keying
   (`{picoId}{channel}`, `isEnabled(picoId, channel)`); resolve `to_phone` from profile in
   `addNotification`; fan out Manifold(inbox)/SMS(raise twilio)/Prowl(raise prowl); simplify
   `toggleNotificationSetting` to `{id, option}`; `getSettings(id)`.
2. REMOVE discovery/seeding (`updateManifoldAppList`, `setDefaultNotificationSettings`, `app_list`,
   `getID`); keep `default_settings()` dormant for the bootstrap.
3. Move `io.picolabs.twilio.sms` into manifold-api: keep `send_sms` defaction + global creds, fix
   `save_config` to a `twilio configuration` domain, add `twilio notify_through_twilio` ->
   `send_sms(Body, to_phone)`. Retire `twilio_notifications` + both text rulesets.
4. Move `io.picolabs.prowl` into manifold-api: keep `notify` defaction + global creds, add
   `prowl notify_through_prowl` -> `notify(...)` (restores richer payload: title/url/providerkey).
   Retire `prowl_notifications`.
5. `io.picolabs.profile` (owner/parent pico): add favorite-aware `getOwnerPhone()` (and
   `getOwnerEmail()` for later).
6. `io.picolabs.manifold_pico`: install `notifications`, `twilio.sms`, `prowl`; drop the
   email/text/`*_notifications` rulesets from `initializationRids`/`updateManifoldVersion`.
7. `sensor-network/io.picolabs.sensor.community` `catch_threshold_violation`: subject =
   community (`picoId = meta:picoId`); keep the originating sensor's name in `thing` for display.
8. Update MEMORY.md status when implemented.

## Gotcha: callback channel policy (fixed)
Symptom: `sensor initiation` created the thing pico with the Manifold rulesets installed, but
the community never finished initializing it.
Root cause: the callback `callback_eci` was `subscription:wellKnown_Rx(){"id"}`, but the
well-known channel's event policy only allows `engine_ui:*` and a few `wrangler` subscription
events -- it REJECTS the `community thing_created` callback Manifold sends. So
`fireThingCreatedCallback` fired but the event was denied at the community.
Fix (community side only; Manifold stays generic): `io.picolabs.sensor.community` now creates a
dedicated `manifold_callback`-tagged channel whose event policy allows
`{domain:"community", name:"thing_created"}`, and `new_sensor` sets
`callback_eci = wrangler:channels("manifold_callback").head(){"id"}`.
Lesson: any callback_eci handed to Manifold must point at a channel whose event policy allows the
callback event domain/name.

## Gotcha: callback must hand back a usable eci, not the family channel (fixed)
Symptom: `addThing` (community) errored with "This is a family channel and only the owner can
use it." when calling `wrangler:skyQuery(thing_eci, ...)`.
Root cause: `fireThingCreatedCallback` passed `thing_eci = picoID`, which equals the child's
parent/child (family) bootstrap channel -- only the Manifold pico (owner) may use it.
Fix: pass `thing_eci = event:attr("Tx")` (the manifold_thing subscription's Tx, i.e. the thing's
subscription channel), matching what `addThingToCommunity` does with `thingSub{"Tx"}`.
Watch next: installing sensor rulesets on the thing from the community, and the community<->thing
`add_thing` subscription send, both depend on the target channel's policy allowing those events.
If they fail with policy errors, route the installs over the community<->thing subscription
channel (after it is established) instead of the manifold_thing Tx.

## STATUS: delegation chain verified working (2026-06-02)
End-to-end confirmed in a running engine: `sensor initiation` -> community delegates
`manifold create_thing` -> Manifold creates a thing, installs io.picolabs.thing, subscribes
manifold_thing, fires `community thing_created` callback -> community `finish_sensor` -> the new
thing gets the lht65 sensor rulesets installed AND a community<->thing subscription is
established. Installing the sensor rulesets over the manifold_thing subscription Tx works (no
self-install fallback needed). Required flushing/re-registering manifold_pico for the
thing_eci=Tx fix to take effect.

Verified 2026-06-03: the heartbeat/readings path works end-to-end — a test heartbeat payload ->
`sensor new_readings` -> `thing community_notify` -> `community thing_event_occurred` ->
`ingest_thing_event` -> `catch_new_readings` fired successfully.
Threshold violation reaches `catch_threshold_violation` -> `manifold add_notification` and
`addNotification` fires on the Manifold pico, but delivery is still gated on
`ent:notification_settings` being provisioned (see notifications TODO above).

## Sensor network bootstrap RS (IMPLEMENTED 2026-06-04, updated 2026-06-04)
File: `sensor-network/io.picolabs.sensor.network_bootstrap.krl` -- install manually on the
Manifold pico (app-specific; NOT in manifold_pico initializationRids).
- `sensor create_community {name?, description?, notify_channels?}` (name defaults to "Sensors")
  -> `manifold new_community` + rcn + `sensor_bootstrap: true`; manifold_pico creates child,
  installs `io.picolabs.community`, subscribes; bootstrap `finish_sensor_community` (selects on
  `sensor_bootstrap` attr on `child_initialized`) installs `io.picolabs.sensor.community` and
  records `ent:sensor_communities`. Do NOT gate finish on `ent:pending{rcn}` alone — rcn may not
  correlate; pending is used for notify_channels when rcn matches.
- Query `getSensorCommunities()` lists communities created by this bootstrap on this Manifold pico.
- Notification provisioning: `sensor community_ready` -> `manifold change_notification_setting`
  per channel (default Manifold only; override notify_channels e.g. "Manifold,SMS,Prowl").
- Channels: NO bootstrap work -- sensor.community create_channels handles `sensor` +
  `manifold_callback` on install. Community plumbing + Manifold subscription = manifold_pico.
- Still required separately: sensor-network ruleset registration (meta:rulesetURI), owner
  profile phone, Twilio/Prowl config on Manifold pico for external notification delivery.

## FUTURE: Personal Data Store (PDS) — pinned 2026-06-04

Revisit after community/sensor testing. Goal: a Manifold-era PDS inspired by CloudOS and Fuse,
not a port of the old ruleset.

### Background
- CloudOS PDS: `/Users/pjw/prog/kynetx/cloudos/PDSService/a169x676.krl` (RID `a169x676`).
  Three layers on one ruleset per pico:
  - `ent:me` — profile / pico identity (name, email, phone, photo, app-specific fields)
  - `ent:elements{namespace}{key}` — app/domain state (e.g. Fuse `fuse-meta.fleet_channel`,
    `fuse:carvoyant.vehicle_info`)
  - `ent:settings{setRID}` — per-ruleset preferences; `get_config_value(key)` uses
    `meta:callingRID()` so apps read their own config without passing RID
- Apps `use module a169x676 alias pds` to read; writes go through PDS events (`pds new_data_available`,
  `new_profile_item_available`, `new_settings_attribute`, etc.) — PDS owns all `ent:*`.
- Fuse used PDS as **platform infrastructure** on every pico (owner, fleet, vehicle). See
  `/Users/pjw/prog/kynetx/Fuse-API/api` — especially `fuse_bootstrap.krl` (core install),
  `fuse_init.krl` (owner: fleet_channel singleton, reportPreference settings),
  `fuse_fleet.krl` / `fuse_vehicle.krl` (same init ritual: new_map_available → myCloud schema →
  new_profile_item_available), `fuse_common.krl` (`role()` from PDS schema, fleetChannel fallback
  to stored channel).

### Why it mattered for Fuse
- **Standardized identity on every pico** — any ruleset calls `pds:get_me("myProfileName")` regardless
  of pico type (owner / fleet / vehicle each had their own `ent:me`).
- **Namespace conventions** for app plumbing vs domain data vs CloudOS integration.
- **Durable cross-pico state** when subscriptions aren't ready (e.g. `fleet_channel` for idempotency).
- **Reactive settings** — rules select on `pds new_settings_available` to reconfigure.
- **Uninstall cleanup** — `explicit application_uninstalled` clears `ent:settings{appid}`.

### Manifold today (gaps)
- `io.picolabs.profile` on **owner pico only** — `{name, email, phone}`; no shared contract elsewhere.
- Names/identity scattered:
  - Wrangler: `wrangler:myself(){"name"}` (creation-time pico metadata)
  - Manifold pico: `ent:things{picoID.name}`, `ent:communities{...}`
  - Community/thing: `ent:thingInfo` / `ent:communityInfo` caches + `picoQuery` fallback to wrangler
  - Apps: e.g. safeandmine `ent:contactInfo`, sensor events pass `pico_name` / `sensor_name` attrs
- No central elements registry, no per-ruleset settings store, no write-through-event contract.
- Delegation/correlation (`ent:pending{rcn}`) solves the same *class* of problem as Fuse's PDS-stored
  `fleet_channel`, but ad hoc per app.

### Key insight (2026-06-04)
**PDS on every pico standardizes how common elements like names get stored.** Wrangler has a name
in `myself()`, but that's wrangler internals — apps shouldn't need wrangler knowledge or cross-pico
queries just to display "what is this pico called?". One query API on every pico (thing, community,
owner) simplifies notifications, UI lists, and multi-pico apps.

### Possible Manifold direction (not decided)
- **`io.picolabs.pds`** installed on every pico (or at minimum owner + thing + community picos).
- Start thin: profile slice only — `ent:profile {name, description?, photo?}` with
  `getProfile()` / `getName()` and `pds update_profile` events (mirror current profile API shape).
  Owner adds contact fields (email, phone) in same store or keep `io.picolabs.profile` as alias.
- Extend later: namespaced `ent:elements`, per-ruleset `ent:settings`, caller-scoped
  `get_config_value()`, uninstall cleanup.
- Modernize vs CloudOS: ruleset names not RIDs; drop `myCloud`/doorbell/gtour; use `picoQuery` for
  cross-pico when needed, `use module` for same-pico reads.
- Candidates for PDS-style storage when built: sensor bootstrap state, per-community notify
  provisioning, shared thing config, notification display names without event-attr stitching.

### Carry forward vs leave behind
- **Keep:** three-layer model, write-through events, namespace conventions, reactive settings,
  per-pico profile identity.
- **Defer:** full port of CloudOS PDS; folding profile into PDS (profile works now on owner pico).

## KRL conventions & gotchas (2026-06-04)

Reference: [Postlude](https://picolabs.atlassian.net/wiki/spaces/docs/pages/1189919/Postlude)
(Picolabs KRL Manual). Lessons from Manifold/sensor-network work this session.

### Rule structure
```
select when ... 
pre { ... }           // prelude: name declarations
if ... then every { } // action block (one only)
fired { ... }         // postlude — ONE postlude only (see below)
```

A rule **fires** when selected AND the action condition is true. Postlude effects (persistent
vars, raises, logging) run in postlude, not the action block.

### Action block
- **One action block per rule** — not multiple `if`/`every`/`send_directive` siblings.
- **Multiple actions** → single `if cond then every { action1; action2; ... }`.
- **No `else` in the action block** — there is no action-level else.

### Postlude (not-fired / error handling)
Use postlude for side effects and failure paths, not the action block.

**Critical: `if X then noop(); fired { }` runs `fired` when X is true** (not when false).
Example: `if is_valid_channel then noop(); fired { update }` updates when channel IS valid.
To run `fired` on success condition, use `if success_cond then noop(); fired { ... }`.
To skip `fired` on failure, use `if failure_cond then noop(); fired { ... }` where failure_cond
is the negation of what you want.

**Only one postlude per rule** — pick one of `always`, `fired`, or `notfired`. You cannot write
`fired { ... }` followed by a separate `notfired { ... }` block.

Postlude forms (from [Picolabs Postlude docs](https://picolabs.atlassian.net/wiki/spaces/docs/pages/1189919/Postlude)):
- `always { ... }`
- `fired { ... }`
- `notfired { ... }`
- `fired { ... } else { ... }` — else runs when the rule did NOT fire
- `notfired { ... } else { ... }` — else runs when the rule DID fire
- `finally { ... }` — optional; runs regardless (after fired/else)

When you need **success effects AND a failure warn**, use `fired` with `else`:
```krl
if child_eci && sensor_url then every { ... }
fired {
  ent:sensor_communities{child_eci} := { ... };
  raise sensor event "community_ready" attributes { ... }
}
else {
  error warn <<finish_sensor_community skipped: ...>>;
}
```

When you **only need a failure warn** (no success postlude effects), a standalone `notfired`
postlude is fine:
```krl
if query_ok then every { send_directive(...); event:send(...) }
notfired {
  error warn <<add_thing failed: ...>>;
}
```

Do NOT write:
```krl
fired { ... }
notfired { error warn ... }    // INVALID — two postludes

if ok then event:send(...)     // OK in action block
fired { ent:x := y }           // INVALID — event:send cannot go inside fired

if ok then send_directive(...)
else send_directive("failed")  // INVALID — no action-block else
if ok then event:send(...)     // INVALID — second action block
```

### Prelude: name declarations, not assignment
In `pre { }`, lines like `name = expr` are **name declarations** (bindings for the rule), not
reassignments. You can write `foo = ...` twice but it does not update the first binding the way
imperative assignment would.

Implications:
- Do NOT "reassign" to refine a value: `pending = ...; pending = pending || fallback` is wrong.
- Prefer **direct path access** over chaining bindings:
  - Good: `name = ent:pending{rcn}{"name"} || event:attr("name")`
  - Avoid: `pending = ent:pending{rcn}; name = pending{"name"} || ...`
- Postlude `:=` on entity vars **is** assignment: `ent:things{picoID} := value`.

### Entity variable updates
Prefer path assignment over `.put()`:
```krl
ent:things := ent:things.defaultsTo({});
ent:things{picoID} := obj_structure;
ent:things{[picoID, "name"]} := changedName;
```
For nested keys use a **composite path** `{[key, "field"]}` — not chained paths:
```krl
ent:sensor_things{[thingPicoID, "thing_eci"]} := thing_eci;   // good
ent:sensor_things{thingPicoID}{"thing_eci"} := thing_eci;     // parse error
```
Not: `ent:things := ent:things.defaultsTo({}).put([picoID], obj_structure)`

### Wrangler 1.0 child deletion
Delete child picos with:
```krl
raise wrangler event "child_deletion_request"
  attributes { "eci": picoID }
```
NOT legacy `wrangler child_deletion` with `{ "id": picoID }` — unhandled in pico-engine 1.0
wrangler; event sits on schedule and never runs. `deleteThing` was correct; `deleteCommunity`
was fixed 2026-06-04.

### Manifold-specific gotchas (already elsewhere in this file)
- **Callback channel policy** — `callback_eci` must allow the callback event (e.g. dedicated
  `manifold_callback` channel for `community thing_created`).
- **Callback `thing_eci`** — pass subscription `Tx`, not family-channel picoID.
- **`io.picolabs.community` syntax** — stray character after `meta { }` block prevents ruleset
  registration; verify ruleset actually loaded if `addThing` never runs.
- **Two-repo bootstrap** — `sensor.network_bootstrap` `meta:rulesetURI` is sensor-network;
  cannot install `io.picolabs.community` from that URL. manifold_pico installs community;
  bootstrap installs `sensor.community` only. Gate finish on `sensor_bootstrap` attr, not
  `ent:pending{rcn}` alone.
- **`picoQuery` not `skyQuery`** — required for family-channel queries (e.g. profile phone).

## Reference
- Plan file: `.cursor/plans/manifold_thing-creation_delegation_c0b87a0d.plan.md`
- Fuse delegation + correlation patterns: `/Users/pjw/prog/kynetx/Fuse-API/api/fuse_fleet.krl`
  (`create_vehicle`/`create_vehicle_check` ~404-485; `report_correlation_number` ~766-960).
