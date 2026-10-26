# io.picolabs.thing

Base ruleset for a Manifold thing pico: a trackable object or device. Accepts  
community membership, keeps community names, notifies communities of its  
events, and installs app rulesets. Installed by Manifold when it creates a  
thing.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [thing:community_notify](#thingcommunity_notify) · [manifold:installapp](#manifoldinstallapp) · [manifold:uninstallapp](#manifolduninstallapp)  

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `thing:community_notify`

Send an event to this thing's communities, which receive it as community:thing_event_occurred with domain, type, attrs, and this thing's id as sender_id. Goes to all of them unless community_eci names one.

**Send:** `thing:community_notify`  
**Rule:** `notifyCommunity`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `domain` | String | yes | domain of the event to report |
| `type` | String | yes | type of the event to report |
| `attrs` | Map | no | its attributes |
| `community_eci` | String | no | only this community (its Tx channel) |

**Examples:**

- **all communities:** `{"domain":"<domain>","type":"<type>","attrs":{}}`
- **one community:** `{"domain":"<domain>","type":"<type>","attrs":{},"community_eci":"<eci>"}`

**Acts when:** always, once selected

**May emit** (possible, not guaranteed):

- sends `community:thing_event_occurred` to `com{"Tx"}`

<details><summary>Select expression</summary>

```krl
select when thing community_notify
```

</details>

### `manifold:installapp`

Install an app ruleset on this thing. The ruleset must be in the same directory as io.picolabs.thing (the manifold-api rulesets).

**Send:** `manifold:installapp`  
**Rule:** `installApp`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `rid` | String | yes | the app ruleset's id |

**Examples:**

- **SafeAndMine:** `{"rid":"io.picolabs.safeandmine"}`

**Acts when:** `absoluteURL`

**May emit** (possible, not guaranteed):

- raises `wrangler:install_ruleset_request` on this pico — when it acts

<details><summary>Select expression</summary>

```krl
select when manifold installapp
```

</details>

### `manifold:uninstallapp`

Uninstall an app ruleset from this thing.

**Send:** `manifold:uninstallapp`  
**Rule:** `uninstallApp`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `rid` | String | yes | the app ruleset's id |

**Acts when:** always, once selected

**May emit** (possible, not guaranteed):

- raises `wrangler:uninstall_ruleset_request` on this pico — when it acts

<details><summary>Select expression</summary>

```krl
select when manifold uninstallapp
```

</details>
