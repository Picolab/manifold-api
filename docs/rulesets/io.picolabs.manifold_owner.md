# io.picolabs.manifold_owner

Represents the human owner of a Manifold mesh. Installed on the Owner pico (a  
child of the root) with io.picolabs.profile. On install it creates the  
Manifold child pico and installs io.picolabs.manifold_pico there. Holds the  
tag-server configuration and the owner's LLM context.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [manifold:updated_context](#manifoldupdated_context) · [manifold:new_tag_server](#manifoldnew_tag_server) · [manifold:channel_needed](#manifoldchannel_needed)  
**Queries:** [getManifoldPico](#getmanifoldpico--any) · [getManifoldPicoEci](#getmanifoldpicoeci--string) · [getTagServer](#gettagserver--map) · [getLLMContext](#getllmcontext--map)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `manifold:updated_context`

Store context for language-model assistants working with this mesh, replacing what was there. Read it back with getLLMContext().

**Send:** `manifold:updated_context`  
**Rule:** `store_llm_context`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `context` | Map | yes | the context to store |

**Examples:**

- **store:** `{"context":{"<key>":"<value>"}}`

**Acts when:** `context`

<details><summary>Select expression</summary>

```krl
select when manifold updated_context
```

</details>

### `manifold:new_tag_server`

Set the tag registry things use for NFC/QR tags. Bootstrap does this with the tag registry's registration channel; it must happen before things register tags.

**Send:** `manifold:new_tag_server`  
**Rule:** `configure_tag_server`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `eci` | String | yes | the tag registry's registration channel |
| `host_url` | String | no | the tag registry's engine URL (default: this engine) |

**Examples:**

- **same engine:** `{"eci":"<registration eci>"}`

**Acts when:** always, once selected

<details><summary>Select expression</summary>

```krl
select when manifold new_tag_server
```

</details>

### `manifold:channel_needed`

Ask for the Manifold pico's manifold channel. The response directive says which: "manifold channel" with eci when it exists; "manifold still being created" or "manifold channel not found" while bootstrap is still running. The first rule that applies answers (the others stop with last).

**Send:** `manifold:channel_needed`  
**Rule:** `return_existing_channel`

No attributes.

**Acts when:** `eci`

**Other rules on the same event:**

- `manifold_needed` — acts when `child == "No Manifold Pico"`
- `new_channel_check` — acts when `not eci && (child != "No Manifold Pico")`

<details><summary>Select expression</summary>

```krl
select when manifold channel_needed
```

</details>

## Queries

### `getManifoldPico()` → Any

The owner's Manifold child pico ({ eci, name, parent_eci }), or the string "No Manifold Pico" if it hasn't been created yet.

**Call:** `GET /sky/query/<eci>/io.picolabs.manifold_owner/getManifoldPico`, or `<alias>:getManifoldPico()` from KRL with `use module io.picolabs.manifold_owner alias <alias>`

### `getManifoldPicoEci()` → String

The ECI of the Manifold pico's manifold channel, for sending manifold events to it; "No Manifold Pico" if it doesn't exist yet, null if the channel isn't there yet.

**Call:** `GET /sky/query/<eci>/io.picolabs.manifold_owner/getManifoldPicoEci`, or `<alias>:getManifoldPicoEci()` from KRL with `use module io.picolabs.manifold_owner alias <alias>`

### `getTagServer()` → Map

The tag registry things use for NFC/QR tags, as set by manifold:new_tag_server.

**Call:** `GET /sky/query/<eci>/io.picolabs.manifold_owner/getTagServer`, or `<alias>:getTagServer()` from KRL with `use module io.picolabs.manifold_owner alias <alias>`

### `getLLMContext()` → Map

Context stored for language-model assistants working with this mesh (set with manifold:updated_context); {} if none.

**Call:** `GET /sky/query/<eci>/io.picolabs.manifold_owner/getLLMContext`, or `<alias>:getLLMContext()` from KRL with `use module io.picolabs.manifold_owner alias <alias>`
