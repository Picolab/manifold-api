# Manifold rulesets (generated API reference)

Markdown for each ruleset is generated from `/** */` annotations in the repo-root `.krl` files.

```bash
npm run generate:docs   # requires ../pico-engine (krl-schema CLI)
npm run check:schema-docs   # CI: regenerate and diff
```

## Platform (bootstrap graph)

| Ruleset | Doc | Installed on |
|---------|-----|----------------|
| **io.picolabs.manifold_bootstrap** | [bootstrap](io.picolabs.manifold_bootstrap.md) | Engine root |
| **io.picolabs.new_tag_registry** | [tag registry](io.picolabs.new_tag_registry.md) | Tag registry child |
| **io.picolabs.profile** | [profile](io.picolabs.profile.md) | Owner |
| **io.picolabs.manifold_owner** | [manifold_owner](io.picolabs.manifold_owner.md) | Owner |
| **io.picolabs.manifold_pico** | [manifold_pico](io.picolabs.manifold_pico.md) | Manifold hub |
| **io.picolabs.notifications** | [notifications](io.picolabs.notifications.md) | Manifold hub |
| **io.picolabs.twilio.sms** | [twilio.sms](io.picolabs.twilio.sms.md) | Manifold hub |
| **io.picolabs.prowl** | [prowl](io.picolabs.prowl.md) | Manifold hub |
| **io.picolabs.homeassistant** | [homeassistant](io.picolabs.homeassistant.md) | Manifold hub (HA channel) |

## Thing and community

| Ruleset | Doc | Installed on |
|---------|-----|----------------|
| **io.picolabs.thing** | [thing](io.picolabs.thing.md) | Thing picos |
| **io.picolabs.community** | [community](io.picolabs.community.md) | Community picos |

## Apps and extensions (examples)

| Ruleset | Doc | Typical use |
|---------|-----|-------------|
| **io.picolabs.safeandmine** | [safeandmine](io.picolabs.safeandmine.md) | Tags, contacts, lost-and-found on things |
| **io.picolabs.journal** | [journal](io.picolabs.journal.md) | Journal / todo-style events (e.g. Home Assistant) |
| **io.picolabs.manifold_portable_thing** | [portable_thing](io.picolabs.manifold_portable_thing.md) | Portable thing move helpers |

Domain repos (sensor meshes, Fuse-style connected car, custom IoT) add their **own** bootstrap rulesets on the Manifold pico — they are not listed here.

**Retired:** `io.picolabs.manifold.skills_registry` (pre–1.8 MCP tool directory) — see [`archive/`](../../archive/README.md).

**Engine-bundled PDS:** `io.picolabs.pds` — see [pico-engine ruleset docs](https://github.com/Picolab/pico-engine/tree/main/packages/pico-engine/public/docs/rulesets). A copy may exist in this repo for tests; prefer the engine doc.
