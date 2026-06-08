# manifold-api

Manifold is a framework for the [pico engine](https://github.com/Picolab/pico-engine) that enables the creation and orchestration of pico-based systems. These rulesets define the behavior of pico devices in the Manifold ecosystem.

This repository contains KRL (Kynetx Rules Language) rulesets for [Manifold](https://manifold.picolabs.io/), updated for compatibility with Pico Engine version 1.0.

## Architecture

Manifold organizes a personal network of picos as a small graph under the engine's root pico, with cross-links formed by subscriptions. The root pico hosts shared registries and the **owner** pico; the owner manages a single **Manifold** pico that creates thing and community picos and tracks them. Things can belong to one or more communities — dashed lines in the diagram are subscriptions (membership and event routing); solid lines are parent/child relationships in the wrangler hierarchy.

![Manifold network: root pico, tag and skills registries, owner, Manifold pico, and thing/community picos](manifold_network.png)

- **Pico (root)** — The engine's top-level pico. Bootstrap (`io.picolabs.manifold_bootstrap`) runs here and creates the registry and owner child picos. In production this is typically the root of a dedicated Manifold engine instance.

- **Tag Registry** — Child of the root pico running `io.picolabs.new_tag_registry`. Central store for NFC/QR tag IDs mapped to thing picos and redirect URLs (used by SafeAndMine and similar apps). The owner pico holds a reference to its registration channel so things can register tags before use.

- **Skills Registry** — Child of the root pico running `io.picolabs.manifold.skills_registry`. Directory of named skills (ruleset IDs, optional URLs, MCP tool definitions) that can be installed on things. Manifold and things query it when adding capabilities.

- **Owner** — Child of the root pico running `io.picolabs.profile` and `io.picolabs.manifold_owner`. Represents the human owner: contact info, tag-server configuration, and management of the Manifold child pico. Installing `manifold_owner` automatically creates the Manifold pico and installs `io.picolabs.manifold_pico`.

- **Manifold** — Child of the owner pico running `io.picolabs.manifold_pico` plus notification rulesets. The operational hub: creates thing and community picos, maintains subscriptions to them, exposes `getThings()` / `getCommunities()`, and routes notifications (inbox, SMS, Prowl). Other repos (e.g. sensor-network) install additional bootstrap rulesets here to delegate domain-specific setup.

- **Blue Backpack** *(thing example)* — A thing pico running `io.picolabs.thing` (often plus domain rulesets such as SafeAndMine). Represents a trackable object or device. Subscribes to Manifold as a `manifold_thing` and can belong to one or more communities (dashed line to Travel in the diagram).

- **Travel** *(community example)* — A community pico running `io.picolabs.community`. Groups related things, accepts thing subscriptions, and can broadcast events to members. Subscribes to Manifold as a `manifold_community`; things join via `community add_thing`. Things can belong to more than one community.

### Notifications

Notification delivery is centralized on the **Manifold pico**. Bootstrap installs `io.picolabs.notifications` plus the channel modules `io.picolabs.twilio.sms` and `io.picolabs.prowl`. Any thing or community (or domain ruleset acting on their behalf) raises **`manifold add_notification`** on the Manifold pico with a subject **`picoId`**, a human-readable **`message`**, and identifying attrs such as **`thing`**, **`app`**, and **`ruleset`**.

The notifications ruleset fans the alert out to whichever channels are **enabled for that subject pico**:

- **Manifold** — Appended to the in-app inbox (`getNotifications()`, badge count)
- **SMS** — Sent via Twilio using the owner's phone from `io.picolabs.profile` on the owner pico
- **Prowl** — Push notification via the owner's Prowl API key

Channels are **opt-in per subject** (each thing or community pico has its own settings). Toggle them with **`manifold change_notification_setting`** and attrs `{ id: picoId, option: "Manifold" }` (or `"SMS"`, `"Prowl"`). By default only the Manifold inbox is on; external channels stay off until explicitly enabled — sensor-network bootstrap, for example, turns on requested channels when a sensor community is created.

Domain rulesets should not call Twilio or Prowl directly; they raise `manifold add_notification` and let Manifold handle routing and owner credentials.

## Ruleset Status

### Updated for Pico Engine 1.0

Core platform rulesets — covered by the integration test harness ([`t/README.md`](t/README.md)):

- ✅ **`io.picolabs.manifold_bootstrap.krl`** — One-step bootstrap automation for the root pico
- ✅ **`io.picolabs.new_tag_registry.krl`** — Refactored for Pico Engine 1.0
- ✅ **`io.picolabs.manifold.skills_registry.krl`** — Skills registry child pico
- ✅ **`io.picolabs.profile.krl`** — Updated for Pico Engine 1.0; flat `ent:profile` contact fields
- ✅ **`io.picolabs.manifold_owner.krl`** — Uses modern Wrangler API; updated channel creation and ruleset installation patterns
- ✅ **`io.picolabs.manifold_pico.krl`** — Thing/community management, thing-creation delegation (`callback_eci`/`rcn`), notification init RS installs
- ✅ **`io.picolabs.thing.krl`** — Community support: `communities()`, `autoAcceptCommunity`, `communityAdded`/`communityRemoved`, `notifyCommunity`
- ✅ **`io.picolabs.community.krl`** — Full community/thing subscription system: `things()`, `autoAcceptManifold`/`autoAcceptThing`, `addThing`, `broadcastThingEvent`
- ✅ **`io.picolabs.safeandmine.krl`** — Partially updated; tags not yet working
- ✅ **`io.picolabs.notifications.krl`** — Notification orchestrator (Manifold inbox + SMS + Prowl channels)
- ✅ **`io.picolabs.twilio.sms.krl`** — SMS delivery module (replaces `io.picolabs.twilio_notifications`)
- ✅ **`io.picolabs.prowl.krl`** — Prowl push module (replaces `io.picolabs.prowl_notifications`)
- ✅ **`io.picolabs.journal.krl`** — Reviewed for Pico Engine 1.0; optional standalone journal (not part of bootstrap)

**Note:** **`io.picolabs.safeandmine.krl`** is installed on thing picos via tests but tags are not yet working.

### Pending review

None at repo root — all active Manifold platform rulesets are reviewed. Archived and experimental rulesets may exist locally under `OLD/` or `fix/`; those directories are gitignored and not published in this repo.

### Removed / superseded

These rulesets were deleted and replaced by the notification platform refactor:

| Removed | Replaced by |
|---------|-------------|
| `io.picolabs.prowl_notifications.krl` | `io.picolabs.prowl.krl` |
| `io.picolabs.twilio_notifications.krl` | `io.picolabs.twilio.sms.krl` |
| `io.picolabs.manifold.text_message_notifications` | `io.picolabs.twilio.sms.krl` (via `notifications`) |
| `io.picolabs.manifold.text_messenger.krl` | `io.picolabs.twilio.sms.krl` (via `notifications`) |

## Bootstrap

### Option 1: Automated (recommended)

1. Start your pico engine with the root pico as the top-level parent.
2. Install **`io.picolabs.manifold_bootstrap`** on the root pico.
3. Query `getBootstrapStatus()` on the root pico's **bootstrap** channel to get the ECIs for the tag registry and owner pico.

### Option 2: Manual

**Three-part initialization sequence:**

1. **Tag registry pico** — Create a child of the root pico; install `io.picolabs.new_tag_registry`. Note the `registration` channel ECI.
2. **Owner pico** — Create a child of the root pico; install `io.picolabs.profile` and `io.picolabs.manifold_owner`. This automatically creates the Manifold child pico and installs `io.picolabs.manifold_pico`.
3. **Tag server registration** — Raise `manifold:new_tag_server` with the tag registry's `registration` ECI to the owner pico **before creating any things**.

```
Root Pico
  ├─ Tag Registry Pico → io.picolabs.new_tag_registry
  └─ Owner Pico → io.picolabs.profile + io.picolabs.manifold_owner
       └─ Manifold Pico → io.picolabs.manifold_pico (auto-installed)
```

## Core Rulesets

| Ruleset | Installed On | Purpose |
|---|---|---|
| `io.picolabs.manifold_bootstrap` | Root pico | Automates full bootstrap |
| `io.picolabs.new_tag_registry` | Tag registry pico | Tag registry |
| `io.picolabs.manifold.skills_registry` | Skills registry pico | Skills registry |
| `io.picolabs.profile` | Owner pico | User profile / contact info |
| `io.picolabs.manifold_owner` | Owner pico | Manages Manifold child pico |
| `io.picolabs.manifold_pico` | Manifold pico | Thing/community management, notifications init |
| `io.picolabs.notifications` | Manifold pico | Notification orchestrator |
| `io.picolabs.twilio.sms` | Manifold pico | SMS delivery |
| `io.picolabs.prowl` | Manifold pico | Prowl push delivery |
| `io.picolabs.thing` | Thing picos | Base thing behavior |
| `io.picolabs.community` | Community picos | Base community behavior |
| `io.picolabs.safeandmine` | Thing picos | Safe and Mine integration |

## Dependencies

All rulesets depend on standard pico engine modules provided by the engine itself:
- `io.picolabs.wrangler` — pico management
- `io.picolabs.subscription` — subscription management

## Accessing Manifold

After bootstrapping, access functionality via:
- Sky Cloud queries: `GET /sky/cloud/{eci}/{ruleset}/{function}`
- Sky Events: `POST /sky/event/{eci}/{eid}/{domain}/{type}`

## Integration tests

This repo includes a local TypeScript integration test harness in [`t/`](t/). Tests run against a **real pico-engine** in Docker with this repo bind-mounted as `file://` ruleset URLs — edit KRL, re-run, iterate without rebuilding the image.

**Prerequisites:** Docker, Node.js 18+, and the `picolabs/pico-engine` image. One-time setup:

```bash
npm install
```

**Quick commands** (from the repo root):

| Command | What it does |
|---------|----------------|
| `npm test` | Parse gate → Docker → bootstrap + scenarios → teardown |
| `npm run test:parse` | KRL syntax check only (no Docker) |
| `npm run test:keep` | Full run; leave container up for inspection |
| `npm run test:cleanup` | Remove leftover test containers and `/tmp` pico homes |

Current scenarios cover Manifold bootstrap (tag registry, owner, Manifold pico), and thing/community create/add/remove/delete flows.

**Full documentation** — prerequisites, flags, failed-run inspection, writing scenarios, and config — is in **[`t/README.md`](t/README.md)**.

The sibling **sensor-network** repo reuses this harness via `dependsOn` and `manifoldApiPath` (default `../manifold-api`); see its `t/README.md`.

## File Conventions

- All rulesets use the `.krl` extension (some legacy files omit it but are valid KRL)
- Ruleset IDs match the filename (e.g., `io.picolabs.manifold_owner.krl` → RID `io.picolabs.manifold_owner`)

## Contributing

When contributing KRL rulesets:
- Follow KRL best practices
- Document dependencies in the `meta` section
- Note Pico Engine version compatibility

For more information about KRL and Pico Labs, visit [picolabs.io](http://picolabs.io).
