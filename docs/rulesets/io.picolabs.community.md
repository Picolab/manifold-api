# io.picolabs.community

Base ruleset for a Manifold community pico: a group of things. Accepts things  
as members, keeps their names, and sends events to one member or all of them.  
Installed by Manifold when it creates a community.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [community:new_description](#communitynew_description) · [community:add_thing](#communityadd_thing) · [community:raise_thing_event](#communityraise_thing_event) · [community:raise_all_things_event](#communityraise_all_things_event)  
**Queries:** [things](#things--array) · [queryThing](#querythingid-rid-func-params--any) · [description](#description--string)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `community:new_description`

Set this community's description (stored in its PDS profile).

**Send:** `community:new_description`  
**Rule:** `setDescription`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `description` | String | yes |  |

**Examples:**

- **set:** `{"description":"<description>"}`

**Acts when:** `not desc.isnull()`

**May emit** (possible, not guaranteed):

- raises `pds:updated_profile` on this pico — when it acts

<details><summary>Select expression</summary>

```krl
select when community new_description
```

</details>

### `community:add_thing`

Add a thing to this community: requests a relationship with the thing, which the thing accepts automatically. Fails (logged) if the thing can't be queried at eci.

**Send:** `community:add_thing`  
**Rule:** `addThing`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `eci` | String | yes | a channel on the thing that allows queries, e.g. its Manifold Tx (not its family channel) |
| `host` | String | no | the thing's engine URL, if on another engine |

**Examples:**

- **same engine:** `{"eci":"<thing eci>"}`

**Acts when:** `query_ok`

**May emit** (possible, not guaranteed):

- sends `wrangler:subscription` to `thing_eci`

<details><summary>Select expression</summary>

```krl
select when community add_thing
```

</details>

### `community:raise_thing_event`

Send an event to one member thing.

**Send:** `community:raise_thing_event`  
**Rule:** `raiseThingEvent`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | String | yes | the thing's picoID |
| `domain` | String | yes |  |
| `type` | String | yes |  |
| `attrs` | String | yes | its attributes, JSON-encoded |

**Examples:**

- **one thing:** `{"id":"<thing picoID>","domain":"<domain>","type":"<type>","attrs":"{}"}`

**Acts when:** `eci`

**May emit** (possible, not guaranteed):

- sends `domain:type` to `eci`

<details><summary>Select expression</summary>

```krl
select when community raise_thing_event
```

</details>

### `community:raise_all_things_event`

Send an event to every member thing.

**Send:** `community:raise_all_things_event`  
**Rule:** `raiseAllThingsEvent`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `domain` | String | yes |  |
| `type` | String | yes |  |
| `attrs` | String | yes | its attributes, JSON-encoded |

**Examples:**

- **all things:** `{"domain":"<domain>","type":"<type>","attrs":"{}"}`

**Acts when:** always, once selected

**May emit** (possible, not guaranteed):

- sends `domain:type` to `thing{"Tx"}`

<details><summary>Select expression</summary>

```krl
select when community raise_all_things_event
```

</details>

## Queries

### `things()` → Array

The things in this community: its established relationships with Tx_role thing, each with the thing's name.

**Call:** `GET /sky/query/<eci>/io.picolabs.community/things`, or `<alias>:things()` from KRL with `use module io.picolabs.community alias <alias>`

### `queryThing(id, rid, func, params)` → Any

Query a function on one member thing over its community relationship. Null if no member has that picoID.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | String | yes |  | the thing's picoID |
| `rid` | String | yes |  | ruleset id on the thing |
| `func` | String | yes |  | shared function to call |
| `params` | String | yes |  | its arguments, JSON-encoded |

**Examples:**

- **thing's name:** `{"id":"<thing picoID>","rid":"io.picolabs.wrangler","func":"name","params":"{}"}`

**Call:** `GET /sky/query/<eci>/io.picolabs.community/queryThing?id=…&rid=…&func=…&params=…`, or `<alias>:queryThing(id, rid, func, params)` from KRL with `use module io.picolabs.community alias <alias>`

### `description()` → String

This community's description, from its PDS profile.

**Call:** `GET /sky/query/<eci>/io.picolabs.community/description`, or `<alias>:description()` from KRL with `use module io.picolabs.community alias <alias>`
