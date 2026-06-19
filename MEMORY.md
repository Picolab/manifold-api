# MEMORY: Manifold Thing-Creation Delegation + Sensor Network Migration

Working context so we don't lose it across sessions.

## WHERE WE ARE (2026-06-09)

### Summary
The sensor network → Manifold migration is **working** in both manual testing and automated
integration tests. **manifold-api** harness: parse → Docker → bootstrap → **14 scenarios** →
teardown (~18s on Node 22). **sensor-network** harness: same stack via `dependsOn` +
`manifoldApiPath` → **5 scenarios** → teardown (~10s). PDS **Phase A–F done** (engine default-install + Manifold hooks removed).

Both repos pushed to GitHub (`windley/manifold-api`, `windley/sensor-network`; the latter
renamed from `temperature-network`).

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
- **Notification delivery (external)** — Manifold inbox works when provisioned; SMS/Prowl need
  Twilio/Prowl config on Manifold pico + owner profile phone. Sensor communities get Manifold
  channel via `network_bootstrap` `community_ready`; external channels opt-in per community.
- **Parse gate** — `npm run test:parse` fails on 2 pending-review RSs: `io.picolabs.alexa.krl`,
  `io.picolabs.google_assistant.krl` (undefined `rids` in select). Fix or add to `parseExclude`
- **SafeAndMine tags** — register/deregister scenarios pass in harness; real NFC/QR flow not
  fully verified in production
- **CI** — local harness only; no GitHub Actions yet

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
- **Teardown:** always remove container on exit (pass or fail); delete pico home unless
  `--retain-logs`; `--keep` skips container stop for inspection
- **Local only** for now (no CI yet)
- **Cross-repo:** `manifoldApiPath` in `TestConfig` + `--manifold-api-path` / `MANIFOLD_API_PATH`;
  `resolveDependencyHostPath()` for `dependsOn` mounts. **sensor-network/t** uses this (built
  2026-06-08, committed 2026-06-09).

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
3. ~~sensor-network/t — `dependsOn` manifold-api, sensor bootstrap + initiation scenarios~~ ✓ (5 tests)
4. Sensor readings/threshold + notification scenarios in sensor-network (optional)
5. Test RS for open channels / scenario conductor (optional)

### README / docs (2026-06-09)
- Root README: architecture diagram (`manifold_network.png`), per-pico bullets, notifications
  section (centralized fan-out via `io.picolabs.notifications`).
- `t/README.md`: cross-repo `manifoldApiPath` for dependent repos.

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
- **PDS + mirrors** — see FUTURE section below; **engine-default PDS** + pico event schema + selective log/replay; security in [`docs/Managing_PDS.md`](docs/Managing_PDS.md#security-model); profile works on owner pico for now
- **Channel policy engine fix** — permit-over-deny + pico-level ceiling; see [Design debt: channel policy](#design-debt-channel-policy--permit-overrides-deny-must-fix)
- **SPIFFE + Cedar policy** — see FUTURE section below; exploration only, not implemented

---

## Two repos involved
- `manifold-api` (this repo, `/Users/pjw/Dropbox/prog/picolabs/manifold-api`) — the Manifold
  KRL rulesets being updated for Pico Engine 1.0. Think of Manifold as the "OS".
- `sensor-network` (`/Users/pjw/Dropbox/prog/picolabs/sensor-network`) — the real sensor
  network. Think of it as an "application" running on Manifold. GitHub: `windley/sensor-network`
  (renamed from `temperature-network`, 2026-06-09).
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
  -> ... -> `ingest_thing_event` -> `catch_threshold_violation` raises
  `manifold add_notification` on the Manifold pico (NOT direct Prowl/Twilio on community).

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

## Test plan (manual — largely covered by harness)
- ~~Create community, install `sensor.community`, send `sensor initiation`~~ ✓ sensor-network harness
- Plain `manifold create_thing` (no `callback_eci`/`rcn`) -> identical-to-today behavior (manifold-api harness)
- Two communities create sensors concurrently -> correlation keeps them separate (not automated)
- Sensor heartbeat -> reading reaches community; threshold -> `add_notification` (manual; not in harness yet)

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

## FUTURE: Personal Data Store (PDS) — pinned 2026-06-04, direction locked 2026-06-09, revised 2026-06-13

Revisit after community/sensor testing. Goal: a Manifold-era PDS inspired by CloudOS and Fuse,
not a port of the old ruleset. **Broader platform goal (2026-06-13):** picos should be
**copyable** and **networks of picos reconstructible** — PDS + selective event logging is the
foundation for **pico mirrors** (see below).

### Platform direction (revised 2026-06-13)

**PDS is a required platform ruleset — installed by default on every pico (pico-engine change).**

Supersedes the interim plan "Manifold installs PDS on every pico it creates." Wrangler is
engine-default today; PDS should join it at that layer.

| Point | Decision |
|-------|----------|
| **Required RS** | Not optional, not Manifold-only plumbing — every pico gets PDS like Wrangler |
| **Why PDS over raw `ent:*`** | Entity vars are already RS-scoped; the win is a **stable contract** so platform enhancements (auth, validation, audit, **mirror/replay hooks**) land in one place without every app reinventing storage |
| **Delivery** | **Pico-engine update** — bundle/default-install PDS alongside Wrangler; register ruleset in engine distribution |
| **Manifold until engine ships** | Interim: Manifold bootstrap may still install PDS explicitly; remove duplicate once engine defaults it |
| **Engine batch opportunity** | Same engine release can tackle other queued repo issues (channel policy, SPIFFE sketch, default ruleset bundle, …) |

- **Source:** [`PDS.krl`](https://github.com/Picolab/wrangler/blob/master/PDS.krl) in
  [Picolab/wrangler](https://github.com/Picolab/wrangler) — adapt for Engine 1.0; local copy
  `io.picolabs.pds.krl` in this repo (parse fixes pending). Fork only if Wrangler upstream gaps
  require Manifold-specific changes.
- **Profile migration path:** owner contact info (`io.picolabs.profile`) eventually folds into
  PDS on the owner pico; until then profile-on-owner remains the SMS recipient source.
- **Start thin when implementing:** profile slice first; extend to general/settings layers.

### Manifold direction (decided 2026-06-09, superseded for install policy)

**Use the Wrangler PDS ruleset.** ~~Have Manifold install it on every pico.~~ → **Engine
default-install** (above). Manifold's job becomes apps/domain RS only — read/write via PDS events
and `use module`, not ad hoc `ent:*` scattered across rulesets.

### Overall goal: pico mirrors (2026-06-13)

Long-standing desire: **allow pico mirrors.**

| Mirror type | What it copies | Mechanism |
|-------------|----------------|-----------|
| **Simple mirror** | One pico's state | PDS snapshot (`profile`, `general`, `settings`) + installed RIDs |
| **Network mirror** | Tree + relationships | More than single-pico data — needs **parent/child, subscriptions, channels, ruleset installs** |
| **Living mirror** | Evolving replica | **Selective event log** replay, not full engine trace |

Simple mirror is easier if every pico has PDS (one canonical data surface). Network mirror
requires **relationship events** (Wrangler/subscription lifecycle) plus replayable state changes
(PDS write commands).

**Right approach for network mirrors:** an **append-only event log** that can be **replayed** on
a mirror pico (or mirror subtree). Not every event should be logged — only those registered for
logging. Replay applies registered events to reconstruct structure + state.

**Literature:** event sourcing / CQRS (Greg Young, Martin Fowler's event-sourcing essay); DDD
domain events; snapshot + event tail for restore; causal ordering for graph structure (subscriptions
before dependent actions). Review event-log patterns in DDD/event-storming space before designing
storage format.

### Pico-level event schema (2026-06-13)

New **pico feature** (engine + wrangler integration): an **event schema** per pico.

- **Pico basis, not ruleset basis** — multiple rules from different RSs may respond to one event;
  the event is the unit of record at the pico boundary.
- **Per `domain:type`:** attributes (required / optional / types); whether the event is **logged**
  for mirror/replay; optional flags (e.g. idempotent replay, `replaySafe: false` for external side effects).
- **Registration:** rulesets register events into the pico's schema (mechanism TBD: KRL meta,
  install-time wrangler hook, explicit register API — lots of details remain).
- **Validation:** engine warns (or rejects in strict mode) on events not in schema — useful before
  mirrors exist.
- **Logging:** schema marks which events are appended to the pico's replay log.

**Default logging policy:**

| Event source | Logged by default? | Rationale |
|--------------|-------------------|-----------|
| **Wrangler** | **Yes — all wrangler events** | Captures tree, installs, subscriptions, channels — the **relationship graph** |
| **PDS write commands** | **Yes** (`pds updated_profile`, `new_data_available`, `add_settings`, …) | Canonical **data plane**; replay commands (not necessarily `pds data_added` notifications) |
| **App/domain events** | **Opt-in** | Ruleset registers + sets `logged: true` only when mirror needs them (e.g. sensor readings) |

With PDS on every pico + wrangler on every pico, **structure and data storage events are logged
and replayable by default** — the platform substrate for mirrors.

### Selective logging & replay (sketch)

- **Log commands, not effects** — prefer replaying `pds new_data_available` (idempotent write
  path) over internal `pds data_added` notifications unless effect-logging is explicitly desired.
- **Side effects on replay** — Twilio, Prowl, external HTTP must be suppressed or tagged
  `replaySafe: false` in schema; mirror driver skips or stubs them.
- **Cross-pico events** — subscription delivers to another pico's bus: log at source, destination,
  or both? Network mirror may need **forest-level log** keyed by SPIFFE path / owner subtree.
- **Snapshots** — periodic PDS snapshot + event tail vs pure replay from genesis (Fuse
  `fleet_channel` idempotency pattern is a precedent for durable cross-pico state).
- **Engine vs RS** — schema registry + append-only store likely **engine**; registration API via
  wrangler + ruleset meta; replay driver TBD (`io.picolabs.mirror` RS or wrangler subsystem).

### Open design questions (mirrors + PDS)

1. Schema conflicts — two RS register same `domain:type` with different attrs?
2. Who may register — any installed RS, or platform RS only for platform events?
3. Mirror scope — single pico, owner subtree, subscription-connected component?
4. Cross-engine mirrors — federation + SPIFFE trust bundles (ties to SPIFFE section below).
5. PDS future enhancements enabled by default install — `meta:callingRID()` write auth, validation,
   structured log records on persist, versioned profile merges.

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

### Delivery phases (interim install via manifold-api → engine default later)

**2026-06-13:** Iterate in manifold-api mount (`meta:rulesetURI` + flush) — no pico-engine
Docker rebuild per PDS edit. Promote to engine default only when contract is stable.

| Phase | Scope | Repo | Goal |
|-------|--------|------|------|
| **A** | Fix `io.picolabs.pds.krl` | manifold-api | krl-compiler verify passes ✓ |
| **B** | Wire PDS install on every Manifold-created pico | manifold-api | bootstrap, owner, manifold_pico, thing, community, registries — PDS before domain RS ✓ |
| **C** | Harness proof | manifold-api | scenario: PDS installed, `pds` channel, query/write profile + general on owner/thing ✓ |
| **D** | Migrate **manifold-api** rulesets to use PDS | manifold-api | profile shim, thing/community names+description, safeandmine contact/registry, notifications phone ✓ |
| **E** | Migrate **sensor-network** rulesets to use PDS | sensor-network | thresholds + community names/notifications; bootstrap reads PDS profile ✓ |
| **F** | Engine default-install PDS | pico-engine | bundle `io.picolabs.pds`; wrangler child init + root startup; remove Manifold install hooks ✓ |

**D vs E:** Installing PDS on picos (B) does not require apps to read/write it. **D** is
Manifold platform/app RS adoption in this repo. **E** is domain app adoption in sensor-network —
second repo, second harness pass, after manifold-api patterns are proven. Do not mix in one PR.

**Phase D candidates (manifold-api, incremental):**
- Thing/community display names → `pds:profile("name")`; sync with wrangler name / `ent:things`
- Owner contact → PDS profile on owner pico (replace `io.picolabs.profile` gradually)
- SafeAndMine contact card → `general.safeandmine`
- Manifold pico lists → read names from PDS via picoQuery where needed
- Notification `thing` attr → PDS profile name

**Phase E candidates (sensor-network, incremental):**
- `sensor.community` cached names / `pico_name` attrs → PDS profile on thing picos
- Bootstrap pending state → optional `general.sensor` namespace (later)
- Threshold notification display strings

**Deferred (not A–F):** pico event schema, selective logging, mirrors, engine channel-policy fixes.

### Possible implementation details (when we build it)
- Start thin: profile slice — `getProfile()` / `getName()` and PDS update events (mirror current
  profile API shape on owner; same API on thing/community picos for display names).
- Extend later: namespaced `ent:general`, per-ruleset `ent:settings`, caller-scoped
  `get_config_value()`, uninstall cleanup (from CloudOS three-layer model).
- Modernize vs CloudOS: ruleset names not RIDs; drop `myCloud`/doorbell/gtour; use `picoQuery` for
  cross-pico when needed, `use module` for same-pico reads.
- **Engine-default PDS** on every pico (Phase F); `io.picolabs.pds.krl` remains in manifold-api mount for dev flush only.
- **Mirrors (post F):** replay driver, forest-level log, app event registration UI.

### Carry forward vs leave behind
- **Keep:** three-layer model, write-through events, namespace conventions, reactive settings,
  per-pico profile identity, **engine-default PDS**, pico event schema, selective logging for mirrors.
- **Defer:** full port of CloudOS PDS; folding profile into PDS (profile works now on owner pico);
  network mirror replay driver.

### Security model (PDS) — documented 2026-06-04

Developer doc: [`docs/Managing_PDS.md`](docs/Managing_PDS.md#security-model).

**Entity vars are RS-scoped**, not pico-wide. PDS `ent:profile` / `ent:general` / `ent:settings`
live in `io.picolabs.pds` only. Other rulesets cannot overwrite them by assigning their own
`ent:*`; they must raise `pds` events (or query via `use module`). Duplicating data in app
`ent:*` is a consistency problem, not a cross-RS overwrite attack.

**Trust model today:** install-time trust + channel capabilities (ECI + event/query policy).
Same-pico PDS writes have **no caller authorization** — any installed RS can raise `pds` events
and PDS will persist. Cross-pico access requires an ECI whose policy allows the event or query.
Human auth (OIDC/session on owner UI) is orthogonal to PDS write authorization on thing picos.

**Mitigations (now):**

| Mitigation | Notes |
|------------|-------|
| **Curated installs** | Manifold bootstrap installs only known RIDs on owner/things/communities |
| **No untrusted RS** | Primary real gate — once installed, RS is fully trusted on that pico |
| **Narrow channel policies** | Restrict cross-pico `io.picolabs.pds` queries; treat ECIs as secrets |
| **Namespace conventions** | One canonical store per app in `general.<namespace>` — avoid shadow `ent:*` |
| **Gate destructive events** | `pds clear_all_data` test-only in production |
| **Query policy on sensitive data** | Do not expose owner email/phone via wide-open query channels |

**Mitigations (near-term, PDS RS):**

| Mitigation | Notes |
|------------|-------|
| **`meta:callingRID()` on writes** | General: only RID matching namespace (or allowlist) may write that namespace; settings: only owning RID (mirror CloudOS `get_config_value` read pattern); profile: platform RIDs only (wrangler, manifold UI path) |
| **Remove or admin-gate `clear_all_data`** | Production picos should not accept wipe from any RS |

**Future plans (engine + platform — see SPIFFE section below):**

| Layer | Addresses |
|-------|-----------|
| **SPIFFE SVID at engine boundary** | Cross-pico workload identity; optional `authPolicy.requireSpiffe` on sensitive channels |
| **Channel policy engine fix** | Deny-over-permit; pico-level policy ceiling; **wildcard `*.*` must require SPIFFE** — see [Design debt: channel policy](#design-debt-channel-policy--permit-overrides-deny-must-fix) |
| **Cedar in engine** | Authorize principal + action + resource before events/queries reach KRL |
| **Channel templates (Wrangler)** | Thing/community/owner types cap what app RSs can declare on new channels |
| **Engine-owned channels** | Platform channels (e.g. `manifold_callback`) not replaceable by app RS with `allow: *` |
| **Install allowlist / signed RIDs** | Longer term — only approved rulesets installable in production engines |
| **Audit log** | SPIFFE ID + event/query for forensics |

SPIFFE/Cedar fix **engine-boundary** and **cross-pico** trust; **`meta:callingRID()` in PDS**
fixes **same-pico forged `pds` events** from co-installed RSs. Both layers needed for defense in depth.

## Design debt: channel policy — permit overrides deny (must fix)

Documented 2026-06-04. Affects all pico security that relies on channel event/query policies,
not only Manifold or PDS.

### Current engine behavior

Channel `eventPolicy` / `queryPolicy` use allow and deny lists (domain/name or rid/fn). Evaluation
is **per channel (per ECI)**, and within that policy **permit overrides deny** — an allow rule
wins even when a deny rule would also match.

Worse, authorization is effectively **the union of all channels on the pico**. Each ECI is an
independent capability. Restrictive policies on channel A do **not** limit what a caller can do
if they also hold channel B's ECI.

### Why this is a design flaw

Any installed ruleset can call `wrangler:createChannel` with a wide-open policy, e.g.
`allow: [{domain: "*", name: "*"}]`. Anyone who learns that ECI can send or query anything the
engine will deliver — **regardless of narrow policies on other channels** (subscription Tx/Rx,
`manifold_callback`, UI channels, etc.).

So channel policy does not provide **pico-level** access control. It only constrains callers who
*only* know restricted ECIs. A single careless or malicious RS undermines every other channel's
limitations. This matches the "trust every installed RS" problem but is structural in the engine,
not just a Manifold coding mistake.

Example in this repo: `io.picolabs.new_tag_registry.krl` creates a channel with
`allow: [{domain: "*", name: "*"}]` — legitimate for that use case, but illustrates that any RS
can mint a universal capability on the same pico where other channels are carefully scoped.

### Required change (engine)

**Must change** before channel policy can be treated as a meaningful security boundary:

| Change | Rationale |
|--------|-----------|
| **Deny overrides permit** | Explicit deny wins over allow within one channel's policy (deny-by-default semantics) |
| **Pico-level policy ceiling** | No channel on a pico may exceed a max policy for that pico type (owner / thing / community / registry) — channel templates enforced by engine or wrangler, not honor system |
| **Restrict who may create channels** | App RSs should not mint arbitrary channels; platform/wrangler owns sensitive channel types |
| **Optional: pico-wide deny list** | Engine-level denies that apply to every ECI on the pico regardless of per-channel allow |

**Partial mitigation with SPIFFE (before full policy ceiling):** engine rule that any channel whose
`eventPolicy` or `queryPolicy` includes a full wildcard (`domain: "*", name: "*"` or rid/fn
equivalent) **must** require a validated SPIFFE ID on every request — not opt-in via
`authPolicy`. ECI alone is insufficient on `*.*` channels. This does not fix permit-over-deny or
capability union structurally, but **shrinks blast radius**: a leaked wide-open ECI is useless
without a caller SVID the channel (or engine default) accepts. See SPIFFE section below.

SPIFFE + Cedar (below) add identity and authorization at the engine door but **do not fully replace**
fixing permit-over-deny and the capability-union problem — an `allow: *` channel still grants
broad access to any **authorized SPIFFE principal** holding that ECI unless channel creation is
capped or Cedar evaluates every request independently of per-channel permissiveness.

Cross-ref: callback gotcha ([Gotcha: callback channel policy](#gotcha-callback-channel-policy-fixed))
shows the opposite failure mode (too-narrow channel blocks a needed event) — both cases show
channel policy is fragile without pico-level governance.

## FUTURE: SPIFFE workload identity + Cedar policy — exploration 2026-06-09

Revisit after PDS or when multi-engine / cross-host trust becomes a requirement. Goal:
cryptographic **pico-to-pico (workload) identity** at the engine boundary, plus expressive
**authorization** that does not depend on KRL rulesets behaving correctly.

**SPIFFE solves workload identity; it does NOT solve human authentication.** Who controls a
Manifold tree (owner, OIDC session, profile) remains a separate layer.

### Problem today

| Mechanism | What it provides | Weakness |
|-----------|------------------|----------|
| **ECI** | Capability URL for events/queries | Bearer token — possession = access |
| **Channel policy** | Allow/deny by domain/name (and rid/fn for queries) | No cryptographic caller identity; **permit overrides deny**; **capability union across channels** — see [Design debt: channel policy](#design-debt-channel-policy--permit-overrides-deny-must-fix) |
| **Installed rulesets** | Business logic, channel creation | **Trust in RS is a weak point** — any installed RS can create a wide-open channel (`allow: *`) that bypasses restrictions on all other channels for holders of that ECI |

Channel policies assume every ruleset on that pico will do the right thing. They cannot prevent
a buggy or malicious ruleset from opening another channel with no meaningful control. Even
perfect per-channel policies fail while **permit overrides deny** and **any ECI on the pico can
grant broader access than other ECIs** — engine change required (section above).

### Design decisions (locked for exploration)

1. **One SPIFFE ID per pico** — stable workload identity, separate from rotatable ECIs/channels.
2. **Channels stay capabilities** — routing and coarse event/query filtering; not the identity.
3. **Basic SPIFFE in the engine** — mint/verify SVIDs, trust anchor per engine instance.
4. **Wrangler on top** — attach SPIFFE path at child creation; expose IDs to KRL; channel templates.
5. **Within one engine** — trust in locally minted SVIDs is **implicit** (engine is the CA).
6. **Between engines** — trust is **not** implicit; requires federation (trust bundles, path policy).
7. **Optional SPIFFE on channel policies** — sensitive channels can require validated SVID + path prefix.
8. **Cedar (or similar) in the engine** — authoritative policy evaluation outside KRL.
9. **Wildcard channels require SPIFFE (engine-enforced)** — any channel with `allow: [{domain:"*", name:"*"}]`
   (or query-policy `rid/fn` wildcard equivalent) **must** verify caller SVID on every request;
   possession of the ECI alone is rejected. Limits blast radius of leaked wide-open ECIs and of
   RS-created `*.*` channels until pico-level policy ceilings exist. Does not stop a co-installed
   malicious RS from using the channel **as its own pico's outbound identity** — same-pico trust
   problem remains; see `meta:callingRID()` / install curation.

### SPIFFE ID hierarchy (sketch)

Trust domain = one per engine deployment, e.g. `spiffe://manifold.example.com`.

```
spiffe://<td>/root
spiffe://<td>/registry/tag
spiffe://<td>/registry/skills
spiffe://<td>/owner/<owner-uuid>
spiffe://<td>/owner/<owner-uuid>/manifold
spiffe://<td>/owner/<owner-uuid>/community/travel
spiffe://<td>/owner/<owner-uuid>/thing/blue-backpack
```

Wrangler sets path at `new_child_request`. Aligns with Manifold tree (see architecture diagram
in README).

### Three enforcement layers

```
HTTP request
  → (1) verify JWT-SVID or mTLS → SPIFFE ID of caller
  → (2) resolve ECI → channel → eventPolicy/queryPolicy (domain/name/rid/fn)
  → (3) optional authPolicy.requireSpiffe + allowed path prefixes
  → (4) optional Cedar evaluate(principal, action, resource)
  → deliver event/query to pico rulesets
```

| Layer | Question | Enforcer |
|-------|----------|----------|
| **Workload identity** | Which pico is calling? | Engine (SVID verify) |
| **Channel gate** | Allowed on this ECI? | Engine (existing policies) |
| **SPIFFE channel auth** | Allowed SPIFFE principal? | Engine (opt-in per channel) |
| **Cedar policy** | Allowed action on resource? | Engine (future) |
| **Human auth** | Which person is acting? | OIDC/session + owner pico (separate) |

KRL rulesets should **not** be the source of truth for security decisions. Engine decides
before events enter the pico. KRL handles orchestration on already-authorized events.

### Engine vs wrangler split

**Engine (minimal SPIFFE):**
- CA / signing keys for trust domain
- Mint JWT-SVID (and optionally X.509-SVID) per pico at creation; rotate on schedule
- Verify SVID on inbound sky/event, sky/cloud (optional per route, required on sensitive channels)
- Store `spiffeId` on pico record; publish JWKS / trust bundle for federation
- Cedar policy store + evaluator (later phase)

**Wrangler:**
- SPIFFE path template on child creation
- `wrangler:mySpiffeId()`, `wrangler:callerSpiffeId()` for KRL (informational — engine already verified)
- Channel creation from **templates** per pico type (thing, community, registry) — limits what app RSs can declare
- Does **not** embed Cedar; declares bindings the engine understands

**Manifold / domain RSs:**
- Subscriptions may record peer SPIFFE ID alongside ECI/picoID
- Delegation callbacks (e.g. `community thing_created`) validated against parent Manifold SPIFFE ID

### Optional SPIFFE on channel policy (sketch)

Extend channel config without breaking existing picos:

```json
{
  "tags": ["manifold_callback"],
  "eventPolicy": {
    "allow": [{ "domain": "community", "name": "thing_created" }],
    "deny": []
  },
  "authPolicy": {
    "requireSpiffe": true,
    "allowedSpiffePathPrefixes": [
      "spiffe://manifold.example.com/owner/*/manifold"
    ]
  }
}
```

**Engine-enforced wildcard rule (design decision #9):** if `eventPolicy.allow` or
`queryPolicy.allow` contains a full wildcard (`domain` and `name` both `"*"`, or rid/fn both
`"*"` for queries), the engine **automatically** requires SPIFFE — `authPolicy.requireSpiffe`
cannot be omitted. Rationale: `*.*` channels are the highest-risk capability-union bypass; tying
them to workload identity means a leaked ECI is not enough for arbitrary internet callers.

At channel creation, RS must supply `allowedSpiffePathPrefixes` (or engine applies a default from
pico type, e.g. parent Manifold + subscription peers only). Example: tag registry registration
channel with `allow: *` might allow `spiffe://…/registry/tag` and subscribed owner picos only.

| Channel shape | SPIFFE |
|---------------|--------|
| Narrow allow (specific domain/name) | Optional `authPolicy.requireSpiffe` |
| Full wildcard `*.*` | **Required** (engine-enforced) |
| Leaked ECI, no valid SVID | Rejected on wildcard channels |

- **Low-sensitivity channels** (dev UI, narrow allows): ECI + domain/name only.
- **High-sensitivity channels** (`manifold_callback`, tag registry `registration`, Manifold app):
  `requireSpiffe` + prefixes (phase 1) → Cedar (phase 2).
- **Wildcard channels**: SPIFFE mandatory; prefixes define who may exercise the broad capability.

Prefix matching is crude; Cedar replaces it for real policy.

### Cedar policy direction

Use [Cedar](https://www.cedarpolicy.com/) (or OPA/Rego) **in the engine**, not in KRL.

- **Principal** = caller SPIFFE ID (workload)
- **Action** = `Event::"community:thing_created"` or `Query::"io.picolabs.wrangler:channels"`
- **Resource** = target pico SPIFFE ID
- **Context** (optional) = human OIDC `sub` for owner-only operations

Example intent (illustrative, not literal Cedar):

```
permit(
  principal == spiffe::".../owner/alice/manifold",
  action == Event::"community:thing_created",
  resource == spiffe::".../owner/alice/community/garden"
);
```

Cedar is deny-by-default and composable — unlike scattering hope across KRL RSs.

**Human + workload:** Cedar policies may require both `principal` (SPIFFE) and `context.human`
(OIDC) for UI-initiated operations vs pico-initiated delegation.

### The KRL / ruleset trust problem

SPIFFE fixes **cross-pico impersonation** and **engine-boundary** authentication. It does **not**
fix a malicious RS running **inside** the same pico.

Mitigations (layered):

| Mitigation | Addresses |
|------------|-----------|
| **Deny-over-permit + pico policy ceiling** | Structural fix — see [Design debt: channel policy](#design-debt-channel-policy--permit-overrides-deny-must-fix) |
| **Wildcard `*.*` requires SPIFFE (engine)** | Leaked wide-open ECI insufficient without caller SVID; mandatory on full wildcard allows |
| Engine-owned sensitive channels | RS cannot replace `manifold_callback` with `allow: *` |
| Channel templates per pico type | Cap policies at creation (thing vs community vs owner) |
| `authPolicy.requireSpiffe` | Open channel useless without valid SVID from allowed prefix |
| Cedar at engine | Permissive allow-list still fails if Cedar denies principal/action |
| Install policy | Only wrangler/Manifold install RS; signed/allowlisted RIDs (longer term) |
| Audit | Log SPIFFE ID + action for forensics |

**Trust model summary:**
- **SPIFFE** = who (workload)
- **Cedar** = what (at the engine door)
- **Ruleset curation** = what code runs inside the pico

### Within-engine vs cross-engine trust

**Single engine (phase 1):** engine mints and verifies SVIDs; no SPIRE deployment required.
JWT-SVID fits HTTP sky APIs; X.509-SVID for mTLS if engine peers or external gateways need it.

**Cross-engine (phase 2+):** each engine = own trust domain + bundle URL. Federation exports
bundle; peer trusts selected path prefixes. Subscriptions across engines become federated
workload trust, not shared ECIs. Real work — attestation, bundle rotation, path policy.

Complements (not replaces) SafeAndMine **DIDs/tags** (public object identity for NFC/QR scans).

### Human authentication (orthogonal)

| Layer | Question | Technology |
|-------|----------|------------|
| Workload | Which pico is calling? | SPIFFE SVID |
| Ownership | Who owns this Manifold tree? | Owner pico + bootstrap |
| User session | Who is at the UI/API? | OIDC / session (legacy google/github signin in OLD/) |
| Delegation | May this human act on this pico? | Consent or owner-as-sole-delegate |

SPIFFE path under `…/owner/<uuid>/…` implies tree ownership structurally, but **proving the
caller is that human** still requires OIDC/session — not SVID alone.

### Node / JS SPIFFE libraries (for engine implementation)

Go (`go-spiffe`) is production-grade. Node is thinner:

| Package | Role | Notes |
|---------|------|-------|
| [`spiffe` npm (depot/node-spiffe)](https://github.com/depot/node-spiffe) | Workload API **client** | Fetches SVID from SPIRE agent; active but ~7 stars; **not minting** |
| [`spiffile`](https://github.com/PeterSR/spiffile) | File-based ID + **`provision`** API | Zero deps, `node:crypto`; closer to **engine-as-CA** without SPIRE |
| andyfurnival/spiffe-library | SPIRE demos | Stale (~2023) |

**Likely approach:** engine implements mint/verify with `node:crypto` + JWT-SVID spec, or
`spiffile` provision for dev/single-node. Use `spiffe` npm only if we adopt external SPIRE later.

### Phased implementation path

1. **SPIFFE ID per pico** in engine metadata; channels unchanged; no verify yet.
2. **Mint JWT-SVID** at pico creation; wrangler exposes `mySpiffeId` / `callerSpiffeId`.
3. **Optional verify** on sky APIs; **`authPolicy.requireSpiffe`** on Manifold callback, registry, app channel.
4. **Channel templates** — restrict RS-created channels per pico type.
5. **Cedar in engine** — principals = SPIFFE ID; actions = domain:name / rid:fn.
6. **Cross-engine federation** — trust bundles, foreign subscription policy.

### Open design questions

- JWT-SVID vs X.509-SVID as default for sky HTTP? (JWT likely; X.509 for mTLS peers.)
- Does ECI ever embed SPIFFE ID, or parallel `Authorization: Bearer` only?
- Federation scope: entire owner subtree exportable, or per-community?
- LoRa / edge gateways: SPIFFE for gateway→engine; sensor serial numbers = separate layer.
- Cedar vs OPA: Cedar fits SPIFFE principals well; evaluate before committing.

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
