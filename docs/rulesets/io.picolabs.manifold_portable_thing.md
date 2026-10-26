# io.picolabs.manifold_portable_thing

Example app-layer wrapper on io.picolabs.portable_subtree for moving a thing pico  
(export blob + import under Manifold with thing RS and ent:things registration).

Layering (follow this pattern for other mesh apps):  
portable_subtree — generic export/import (dido/wrangler); opt-in from engine /krl/  
this ruleset — Manifold-specific portable move (export hints, import registration)  
manifold_pico — unchanged; read registry via use module getThings() only

Opt-in on Manifold (not installed at bootstrap):  
raise manifold event "enable_portable_thing"  
→ installs io.picolabs.portable_subtree then this ruleset (use module order)

Export (query on Manifold app channel):  
manifold_portable_thing:exportPortableThing(subtreeRootPicoId, secret)  
→ { blob, name, donorQueryEci, subtreeRootPicoId, thingFamilyPicoID }  
name is the Manifold thing label (ent:things). subtreeRootPicoId may be any channel  
ECI on the thing (including the About tab UI ECI), family ECI, or internal pico id.  
Secret is input only — not echoed.

Import (event on Manifold app channel):  
raise manifold event "import_portable_thing"  
attributes { "blob", "secret", "name", "donorQueryEci", "renewIngress" }  
→ import_portable_thing_done (+ thingQueryEci when donorQueryEci is set)

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [manifold:import_portable_thing](#manifoldimport_portable_thing)  
**Queries:** [exportPortableThing](#exportportablethingsubtreerootpicoid-secret--map) · [lastImport](#lastimport--map)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `manifold:import_portable_thing`

Import a thing exported with exportPortableThing as a child of this Manifold pico: restores the subtree, installs io.picolabs.thing, subscribes it to Manifold, and adds it to the registry under name. Raises manifold:import_portable_thing_done with the result (also in lastImport()).

**Send:** `manifold:import_portable_thing` with `blob` matches `re#.+#` and `secret` matches `re#.+#`  
**Rule:** `import_portable_thing`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `blob` | String | yes | from exportPortableThing |
| `secret` | String | yes | the secret used to export it |
| `name` | String | no | the thing's Manifold name (from the export) |
| `donorQueryEci` | String | no | from the export; maps to the thing's new query channel |
| `renewIngress` | Boolean | no | mint fresh DIDComm ingress (default true) |

**Examples:**

- **import:** `{"blob":"<blob>","secret":"<secret>","name":"<name>","donorQueryEci":"<eci>"}`

**Acts when:** always, once selected

**May emit** (possible, not guaranteed):

- raises `portable_subtree:import` on this pico — when it acts

<details><summary>Select expression</summary>

```krl
select when manifold import_portable_thing
        blob re#.+#
        secret re#.+#
```

</details>

## Queries

### `exportPortableThing(subtreeRootPicoId, secret)` → Map

Export a thing pico (and its children) for moving to another Manifold. Returns the encrypted blob plus the hints import_portable_thing needs: the thing's Manifold name and its donor query channel. Read-only; the thing is untouched.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `subtreeRootPicoId` | String | yes |  | any channel ECI on the thing, its family ECI, or its pico id |
| `secret` | String | yes |  | encryption secret; the importer needs the same one |

**Examples:**

- **export:** `{"subtreeRootPicoId":"<thing eci>","secret":"<secret>"}`

**Call:** `GET /sky/query/<eci>/io.picolabs.manifold_portable_thing/exportPortableThing?subtreeRootPicoId=…&secret=…`, or `<alias>:exportPortableThing(subtreeRootPicoId, secret)` from KRL with `use module io.picolabs.manifold_portable_thing alias <alias>`

### `lastImport()` → Map

Result of the most recent import_portable_thing on this pico, with thingQueryEci (the thing's new query channel) when donorQueryEci was given.

**Call:** `GET /sky/query/<eci>/io.picolabs.manifold_portable_thing/lastImport`, or `<alias>:lastImport()` from KRL with `use module io.picolabs.manifold_portable_thing alias <alias>`
