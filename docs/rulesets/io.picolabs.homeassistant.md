# io.picolabs.homeassistant

Delivers Manifold notifications to a Home Assistant integration via a  
dedicated channel on the Manifold pico. On install this ruleset creates  
a channel tagged "homeassistant" and forwards enabled notifications to it.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [homeassistant:ensure_channel](#homeassistantensure_channel)  
**Queries:** [homeassistantChannel](#homeassistantchannel--map) · [getPendingNotifications](#getpendingnotifications--array)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `homeassistant:ensure_channel`

Create the Home Assistant channel if it's missing (normally created on install).

**Send:** `homeassistant:ensure_channel`  
**Rule:** `ensure_homeassistant_channel`

No attributes.

**Acts when:** `existing.isnull()`

**May emit** (possible, not guaranteed):

- calls module action `wrangler:createChannel`

<details><summary>Select expression</summary>

```krl
select when homeassistant ensure_channel
```

</details>

## Queries

### `homeassistantChannel()` → Map

The channel the Home Assistant integration uses: tagged exactly "homeassistant". Null until this ruleset is installed (or ensure_channel).

**Call:** `GET /sky/query/<eci>/io.picolabs.homeassistant/homeassistantChannel`, or `<alias>:homeassistantChannel()` from KRL with `use module io.picolabs.homeassistant alias <alias>`

### `getPendingNotifications()` → Array

The most recent notifications delivered to Home Assistant (up to 100), newest first, for the integration to read. Each is the full notification map (thing, picoId, app, message, ruleset, id, time, …).

**Call:** `GET /sky/query/<eci>/io.picolabs.homeassistant/getPendingNotifications`, or `<alias>:getPendingNotifications()` from KRL with `use module io.picolabs.homeassistant alias <alias>`
