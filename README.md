# manifold-api

KRL (Kynetx Rules Language) rulesets for [Manifold](https://manifold.picolabs.io/), updated for compatibility with Pico Engine version 1.0.

Manifold is a platform built on the [pico engine](https://github.com/Picolab/pico-engine) that enables the creation and orchestration of pico-based systems. These rulesets define the behavior of pico devices in the Manifold ecosystem.

## Ruleset Status

### Updated for Pico Engine 1.0

- ✅ **`io.picolabs.manifold_owner.krl`** — Uses modern Wrangler API; updated channel creation and ruleset installation patterns
- ✅ **`io.picolabs.manifold_pico.krl`** — Uses `foreach` initialization, synchronous `wrangler:createChannel()`, `meta:rulesetURI` for URL derivation; includes `createCommunity`, `addThingToCommunity`, and `getCommunities`
- ✅ **`io.picolabs.profile.krl`** — Updated for Pico Engine 1.0
- ✅ **`io.picolabs.thing.krl`** — Community support: `communities()`, `autoAcceptCommunity`, `communityAdded`/`communityRemoved`, `notifyCommunity`
- ✅ **`io.picolabs.safeandmine.krl`** — Partially updated; tags not yet working
- ✅ **`io.picolabs.new_tag_registry.krl`** — Refactored for Pico Engine 1.0
- ✅ **`io.picolabs.manifold_bootstrap.krl`** — One-step bootstrap automation for the root pico
- ✅ **`io.picolabs.community.krl`** — Full community/thing subscription system: `things()`, `autoAcceptManifold`/`autoAcceptThing`, `addThing`, `broadcastThingEvent`, `addEventSequence`/`removeEventSequence`

### Pending Review

These rulesets have not yet been reviewed for Pico Engine 1.0 compatibility:

- ⚠️ `io.picolabs.notifications.krl`
- ⚠️ `io.picolabs.prowl_notifications.krl`
- ⚠️ `io.picolabs.twilio_notifications.krl`
- ⚠️ `io.picolabs.manifold.email_notifications.krl`
- ⚠️ `io.picolabs.manifold.text_message_notifications`
- ⚠️ `io.picolabs.manifold.text_messenger.krl`
- ⚠️ `io.picolabs.manifold.pico_mailer.krl`
- ⚠️ `io.picolabs.manifold.disk_space_monitor.krl`
- ⚠️ `io.picolabs.google_signin.krl`
- ⚠️ `io.picolabs.github_signin.krl`
- ⚠️ `io.picolabs.alexa.krl`
- ⚠️ `io.picolabs.google_assistant.krl`
- ⚠️ `io.picolabs.weather.krl`
- ⚠️ `io.picolabs.manifold_import.krl`
- ⚠️ `io.github.picolab.manifold_disk.krl`
- ⚠️ `io.picolabs.neighborhood_temps`

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
| `io.picolabs.manifold_owner` | Owner pico | Manages Manifold child pico |
| `io.picolabs.manifold_pico` | Manifold pico | Thing/community management |
| `io.picolabs.thing` | Thing picos | Base thing behavior |
| `io.picolabs.community` | Community picos | Base community behavior |
| `io.picolabs.profile` | Owner pico | User profile management |
| `io.picolabs.new_tag_registry` | Tag registry pico | Tag registry |

## Dependencies

All rulesets depend on standard pico engine modules provided by the engine itself:
- `io.picolabs.wrangler` — pico management
- `io.picolabs.subscription` — subscription management

## Accessing Manifold

After bootstrapping, access functionality via:
- Sky Cloud queries: `GET /sky/cloud/{eci}/{ruleset}/{function}`
- Sky Events: `POST /sky/event/{eci}/{eid}/{domain}/{type}`

## File Conventions

- All rulesets use the `.krl` extension (some legacy files omit it but are valid KRL)
- Ruleset IDs match the filename (e.g., `io.picolabs.manifold_owner.krl` → RID `io.picolabs.manifold_owner`)

## Contributing

When contributing KRL rulesets:
- Follow KRL best practices
- Document dependencies in the `meta` section
- Note Pico Engine version compatibility

For more information about KRL and Pico Labs, visit [picolabs.io](http://picolabs.io).
