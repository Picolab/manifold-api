# Changelog

All notable changes to Manifold platform rulesets in this repository.

## [Unreleased]

## [1.8.0] - 2026-10-27

**Requires [pico-engine](https://github.com/Picolab/pico-engine) 1.8.0+** at runtime (discovery annotations, `wrangler:schemaBindings`, MCP `channelSchema` / `ruleset_schema`). **`krl-compiler` devDependency** stays **`^1.5.0`** until **1.6.0** is on npm (publish pico-engine first, then bump here).

### Added

- **`/** */` discovery annotations** on shared Manifold ruleset events and queries (1.8 schema / `krl-check`).
- **`docs/rulesets/`** — generated ruleset API reference; **`docs/llms.txt`** / **`docs/llms-full.txt`** for agents.
- **`npm run generate:docs`** and **`npm run check:schema-docs`** (`tools/generate-docs.cjs`, `tools/check-schema-docs.cjs`).
- **`archive/`** — retired **`io.picolabs.manifold.skills_registry`** (superseded by engine mesh MCP + dev MCP).
- **`io.picolabs.homeassistant`** — Home Assistant notification channel on the Manifold pico; `homeassistantChannel`, `getPendingNotifications`, and `homeassistant notification` events for the [Manifold HA hub](https://github.com/Picolab/manifold-home-assistant).
- **`docs/Manifold.md`** — consolidated Manifold platform documentation; **sensor-network** as reference mesh app.
- **Discovery bindings** on **`io.picolabs.safeandmine`** and **`io.picolabs.journal`** — `wrangler:schemaBindings` and integrator-facing capability maps.

### Removed

- **`io.picolabs.manifold.skills_registry`** from bootstrap and the live ruleset tree (see **`archive/`**).

### Fixed

- **`io.picolabs.new_tag_registry`** — deliver `tag_register_response` on-engine (no `pico_host` HTTP `event:send`); fixes 401 when HA runs in Docker.
- **`io.picolabs.safeandmine`** — resolve Manifold app channel by tags (not fragile `name` / tag-count heuristics).
- **`io.picolabs.manifold_pico`** — app channel query policy allows **`io.picolabs.notifications`**.
- **`io.picolabs.community`** / **`io.picolabs.thing`** — `wrangler:picoQuery(..., {})` for engine 1.8; safer community/thing membership naming.
- **Integration harness (`t/`)** — flush via UI `engine_ui/flush` (not `/api/flush`); **`PICO_ENGINE_AUTO_CREATE_ROOT=1`** in Docker; normalized KRL array responses; **16/16** scenarios including thing/community flows.

### Changed

- **`io.picolabs.community`** — disabled `broadcastThingEvent` (rule commented out). Automatic fan-out of `thing_event_occurred` to other members is deferred; use `community raise_thing_event` or `raise_all_things_event` for explicit broadcasts. Fixes sensor-network feedback loops when multiple sensors share a community.
- **`io.picolabs.safeandmine`** — discovery rule uses `discovery capabilities` and `filterBindingsForCaller`.
- **`io.picolabs.journal`** — same discovery pattern; wrangler module for binding filter.
- **`io.picolabs.manifold_pico`** — installs `io.picolabs.homeassistant` when needed.
- **`io.picolabs.notifications`** — HomeAssistant notification channel support.
- **README**, **CLAUDE.md**, **MEMORY.md** — 1.8 requirements, MCP over skills registry, sensor-network harness cross-reference.

[1.8.0]: https://github.com/Picolab/manifold-api/releases/tag/v1.8.0
