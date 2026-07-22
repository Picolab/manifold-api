# Changelog

All notable changes to Manifold platform rulesets in this repository.

## [Unreleased]

### Added

- **`io.picolabs.homeassistant`** — Home Assistant notification channel on the Manifold pico; `homeassistantChannel`, `getPendingNotifications`, and `homeassistant notification` events for the [Manifold HA hub](https://github.com/Picolab/manifold-home-assistant).
- **`docs/Manifold.md`** — consolidated Manifold platform documentation.
- **Discovery bindings** on **`io.picolabs.safeandmine`** and **`io.picolabs.journal`** — `discovery capability` directives with integrator-facing query/event maps and HomeAssistant notification channel support.

### Fixed

- **`io.picolabs.new_tag_registry`** — deliver `tag_register_response` on-engine (no `pico_host` HTTP `event:send`); fixes 401 when HA runs in Docker.

### Changed

- **`io.picolabs.safeandmine`** — discovery rule uses `discovery capabilities` and `filterBindingsForCaller`.
- **`io.picolabs.journal`** — same discovery pattern; wrangler module for binding filter.
- **`io.picolabs.manifold_pico`** — installs `io.picolabs.homeassistant` when needed.
- **`io.picolabs.notifications`** — HomeAssistant notification channel support.
- Integration test expectations updated for new rulesets.
