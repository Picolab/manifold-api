# manifold-api — guide for coding agents

**Manifold** is a KRL framework for building and operating **meshes of picos** on the [pico engine](https://github.com/Picolab/pico-engine). This repo holds its rulesets, bootstrap automation, integration tests, and docs. Engine-level conventions (KRL rules, layering, terminology) live in the engine repo's `CLAUDE.md`; read that first if it is checked out beside this one (`../pico-engine/CLAUDE.md`). This file covers only what is specific to Manifold.

**Requires:** pico-engine **1.8+** (rulesets carry `/** */` discovery annotations, and `io.picolabs.journal` and `io.picolabs.safeandmine` build their discovery bindings with `wrangler:schemaBindings`, which is new in 1.8; PDS bundled since 1.4). Node 22 LTS recommended. Docker for tests.

## Where Manifold sits

```
engine ← wrangler ← MANIFOLD (this repo) ← mesh apps (sensor-network, Fuse, Home Assistant, …)
```

Manifold is the layer that **supplies the vocabulary**: owner, thing, community, registry. It consumes engine + wrangler primitives and hides them behind mesh-oriented constructs so app developers don't wire channels and subscriptions by hand. Two consequences:

- Anything that needs those words belongs **here**, not in engine or wrangler.
- Manifold itself stays **generic**: it must not know about sensors, SafeAndMine tags, or any one app. App behavior is installed *on top* by the app's own bootstrap ruleset (see how `sensor-network` does it).

## Mesh shape

```
Root pico                      io.picolabs.manifold_bootstrap
  ├─ Tag Registry              io.picolabs.new_tag_registry
  └─ Owner                     io.picolabs.profile + io.picolabs.manifold_owner
       └─ Manifold             io.picolabs.manifold_pico + notifications (+ app bootstrap RSs)
            ├─ Thing …         io.picolabs.thing (+ app RSs)        ──subscribed to Manifold as manifold_thing
            └─ Community …     io.picolabs.community (+ app RSs)    ──subscribed as manifold_community; things join via community add_thing
```

Solid = parent/child (wrangler). Dashed = relationships/subscriptions (membership and event routing). Full description with diagram in `README.md`; developer overview in `docs/Manifold.md`; PDS data model in `docs/Managing_PDS.md`.

## Layout

| Path | What |
|------|------|
| `io.picolabs.*.krl` (root) | The published rulesets. Table of what installs where is in `README.md` → *Core Rulesets* |
| `t/` | Integration harness (TypeScript, tsx): `run.ts`, `parse.ts`, `lib/`, `scenarios/*.scenario.ts`, `config.json` |
| `docs/` | `Manifold.md`, `Managing_PDS.md`, **`llms.txt` / `llms-full.txt`**, **`rulesets/*.md`** (generated — `npm run generate:docs`) |
| `MEMORY.md` | Working log: status, decisions, every gotcha we hit. Long; grep it before guessing |
| `OLD/`, `fix/` | Gitignored scratch — never publish from here; excluded from the parse gate |
| `.githooks/pre-commit` | Runs the parse gate when `.krl` files are staged (`npm run hooks:install` once) |

## Commands (run from repo root, not `t/`)

```sh
npm install
npm run test:parse        # krl-compiler --verify on every *.krl (no Docker) — run after ANY KRL edit
npm test                  # parse gate → Docker engine → bootstrap → scenarios → teardown (~20s)
npm run test:keep         # same, leaves the container up for poking
npm run test:cleanup      # kill leftover containers / /tmp pico homes after a hung run
npm test -- --help        # scenario filters and flags
```

Default image `picolabs/pico-engine:latest`; override with `PICO_ENGINE_IMAGE=…` (build locally from `../pico-engine` with `Dockerfile.local` when you need unreleased engine features). Ruleset source is bind-mounted into the container, so edit KRL → rerun, no image rebuild.

## Patterns to follow (Manifold-specific)

| Pattern | How |
|---------|-----|
| **Discovery annotations** | Put a `/** */` annotation directly before each rule or shared function callers should see: a description first, then `@attr` / `@param` / `@returns` / `@example` as needed. Everything else (select, condition, emits) is derived. Unannotated = internal. Discovery `bindings()` = `wrangler:schemaBindings(meta:rid)`, never hand-written. Run `node ../pico-engine/packages/krl-compiler/bin/krl-check <file>` and fix warnings |
| **Delegation with callbacks** | App rulesets ask Manifold to create things/communities and pass `callback_eci` + `rcn` (correlation id). Manifold calls back (`community thing_created`, `community community_completed`) with `{rcn, thingPicoID, thing_eci}`. Stash app context under `ent:pending{rcn}` and finish setup in the callback rule. Never `schedule` and hope |
| **Callback channel policy** | The `callback_eci` **must** point at a channel whose event policy allows the callback event. The well-known/UI channels do not. Create a dedicated channel (e.g. tagged `manifold_callback`) that allows `community:thing_created` |
| **Which ECI to use** | Thing's **subscription Tx** (`event:attr("Tx")` / `thingSub{"Tx"}`) for cross-pico sends and queries — **not** `picoID`, which is the family channel and only the parent may use it. Use the Manifold **app channel** for app events; the UI channel's policy blocks non-UI domains |
| **Notifications** | Raise `manifold add_notification` on the Manifold pico with `picoId`, `message`, `thing`, `app`, `ruleset`. Never call Twilio/Prowl from domain rulesets. Channels are opt-in per subject via `manifold change_notification_setting` (`option`: `Manifold` / `SMS` / `Prowl`) using the pico's **wrangler id** |
| **Adding a capability to things** | Install rulesets on the thing via wrangler (`install_ruleset_request` / UI). Agent tools: pico-engine **1.8 mesh MCP** from `channelSchema` — not the retired skills registry (`archive/io.picolabs.manifold.skills_registry.krl`) |
| **Profile / contact data** | PDS on the owner pico (`io.picolabs.pds`, engine-bundled). `io.picolabs.profile` is the legacy shim; read phone/email through PDS paths |
| **Queries over family channels** | `wrangler:picoQuery`, not `skyQuery` |
| **Deleting children** | `raise wrangler event "child_deletion_request" attributes {"eci": picoID}` |

## Harness gotchas (from `MEMORY.md`)

- Sky Cloud query args are plain values (`?tagID=TAG02`), not JSON-stringified; `t/lib/engine.ts` `serializeQueryArg()` handles this.
- Events/queries to things from tests go over `entry.Tx` (the Manifold subscription channel), not the UI channel.
- A stray character after `meta { }` prevents registration silently; if a rule never fires, confirm the ruleset actually loaded (`wrangler:installedRIDs()` or the UI).
- `io.picolabs.alexa.krl` / `io.picolabs.google_assistant.krl` are pending review and fail the parse gate; they are in `parseExclude` for dependents (see `../sensor-network/t/config.json`).

## Working in this repo

- Keep Manifold generic. If an app needs something Manifold doesn't expose, add a **generic** event/query (with `callback_eci`/`rcn`) rather than app-specific branches.
- Every KRL change: `npm run test:parse`, then `npm test`. Add or extend a scenario in `t/scenarios/` for new behavior; `t/lib/` has helpers for bootstrap, Manifold events, PDS, notifications, tag registry.
- Record new engine behavior you discover the hard way in `MEMORY.md` (and, if it's engine-level, in `../pico-engine/CLAUDE.md`).
- Don't commit, push, or publish; leave that to the maintainer.
- Downstream consumers test against this repo's KRL via `dependsOn`: a breaking change here shows up first in `sensor-network`'s harness. Run both when you touch `manifold_pico`, `community`, or `thing`.
