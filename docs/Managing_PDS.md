# Managing PDS (Pico Data Services)

**Ruleset:** `io.picolabs.pds`  
**Source:** [`io.picolabs.pds.krl`](../io.picolabs.pds.krl) (local copy; upstream lives in [Picolab/wrangler](https://github.com/Picolab/wrangler/blob/master/PDS.krl))  
**Related:** [Managing Subscriptions](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186843209/Managing+Subscriptions)

> **Status (2026):** Installed on all Manifold-created picos; `io.picolabs.pds.krl` in this repo is the Engine 1.0 fork under active use. The **model and event/query contract** on this page are the developer contract.

---

## Table of contents

1. [Introduction to PDS](#introduction-to-pds)
2. [What belongs in PDS (and what doesn't)](#what-belongs-in-pds-and-what-doesnt)
3. [Installing and using PDS in KRL](#installing-and-using-pds-in-krl)
4. [Reading data (queries)](#reading-data-queries)
5. [Writing profile data](#writing-profile-data)
6. [Writing general (namespaced) data](#writing-general-namespaced-data)
7. [Writing settings data](#writing-settings-data)
8. [Reacting to data changes](#reacting-to-data-changes)
9. [Clearing data](#clearing-data)
10. [Advanced example: app data on a thing pico](#advanced-example-app-data-on-a-thing-pico)
11. [PDS data model](#pds-data-model)
12. [Namespace conventions (Manifold)](#namespace-conventions-manifold)
13. [Understanding the protocol](#understanding-the-protocol)
14. [Security model](#security-model)

---

# Introduction to PDS

Subscriptions answer the question **“how do two picos talk to each other?”** PDS answers **“where does a pico keep its data, and how do rulesets read and write it consistently?”**

Without PDS, each application ruleset creates its own entity variables (`ent:contactInfo`, `ent:thingInfo`, …). Display names end up in Wrangler metadata, contact cards in one RS, config in another. PDS provides a **single, shared data service on every pico** with three layers:

| Layer | Entity variable | Purpose |
|-------|-----------------|---------|
| **Profile** | `ent:profile` | **This pico’s** display identity (name, description, photo) — not a person’s profile unless this pico represents a person |
| **General** | `ent:general` | Namespaced app/domain key-value data |
| **Settings** | `ent:settings` | Per-ruleset configuration keyed by RID |

**Design principles:**

- **PDS owns the data.** Apps do not write `ent:profile`, `ent:general`, or `ent:settings` directly. They raise **`pds`** domain events; PDS rules persist and notify.
- **Reads go through shared functions.** Other rulesets `use module io.picolabs.pds` and call query functions (`profile`, `items`, `config_value`, …).
- **Writes are event-driven.** Raise `pds updated_profile`, `pds new_data_available`, etc.; select on `pds profile_updated`, `pds data_added`, … to react.
- **One PDS per pico.** Manifold bootstrap and creation flows install `io.picolabs.pds` on every pico they create (owner, Manifold hub, registries, things, communities) before domain rulesets. Engine default-install is the long-term target.

PDS does **not** replace subscriptions, channels, or Wrangler. It complements them: subscriptions are the wire; PDS is the notebook each pico keeps about itself.

See [What belongs in PDS (and what doesn't)](#what-belongs-in-pds-and-what-doesnt) before migrating app data — not everything needs to move into PDS.

---

# What belongs in PDS (and what doesn't)

PDS is the **canonical data plane for a pico** — but application rulesets still have their own
`ent:*` variables. Use PDS when the data is **shared, queryable, or part of display identity**.
Keep data **local to an RS** when it is private, derived, ephemeral, or high-churn.

This split also aligns with **pico mirrors** (see [`MEMORY.md`](../MEMORY.md)): long-term replay
is driven by a **selective event log**, not by copying every `ent:*` on every ruleset. PDS writes
(`pds updated_profile`, `pds new_data_available`, …) are good log candidates. App-only `ent:*`
can be rebuilt when those events (or wrangler/manifold events) are replayed. **Do not migrate
data into PDS general solely “because mirroring”** — migrate when there is a sharing or platform
contract reason; register app events for mirror when data stays on the RS.

## Default: profile on every pico

**Put in PDS profile** (`pds updated_profile` / `pds:profile()`):

| Data | Examples |
|------|----------|
| Display name | Thing, community, owner, registry labels in UI lists and notifications |
| Short description | Community blurb, thing subtitle |
| Photo / avatar | Owner photo, thing icon |
| Owner contact (owner pico only) | `email`, `phone` for SMS and future email channels |

Profile is the **stable cross-pico read surface** — Manifold, notifications, and peer picos use
`wrangler:picoQuery(eci, "io.picolabs.pds", "profile", …)` without knowing each app’s internal
layout. On install, PDS seeds `name` from Wrangler when empty so it stays aligned with the child
name set at creation.

Prefer **`pds:profile("name")`** over **`wrangler:name()`** in application rulesets for anything
shown to humans outside Wrangler internals.

## When to use PDS general

**Put in PDS general** (`pds new_data_available`, namespace + key):

| Situation | Example |
|-----------|---------|
| **Two or more rulesets** on the same pico need the data | Contact card read by SafeAndMine and a future public query channel |
| **Cross-pico query** via `picoQuery(..., "io.picolabs.pds", "items", …)` | Registry ECI stored on a thing for tag lookup |
| **Stable namespace contract** documented for the platform | `general.safeandmine.contact`, `general.sensor.last_reading` |
| **Simple mirror snapshot** needs one export surface | Optional — a PDS snapshot is convenient but not the only replay strategy |

**Keep in app `ent:*`** (raise normal app-domain events; mirror those events if needed):

| Situation | Example |
|-----------|---------|
| **Single RS, single writer**, never read elsewhere | Internal tag channel list, pending UI state |
| **Derived cache** rebuilt from subscriptions + PDS reads | `ent:thingInfo`, `ent:communityInfo` on thing/community picos |
| **Hub index / presentation** rebuilt from wrangler events | `ent:things`, `ent:communities` on the Manifold pico (names mirror subscription attrs; canonical name lives in each child’s PDS profile) |
| **Ephemeral UI state** | Grid `pos`, default `color`, badge counts, notification inbox rows |
| **High-volume telemetry** | Raw sensor readings — prefer opt-in **domain event logging**; use PDS general only if other rulesets must query the latest value |

SafeAndMine **`general.safeandmine.contact`** is in PDS because it is part of the public lost-and-found contract and may be queried across channels; it is not there only for mirrors — replaying `safeandmine update` would rebuild the same state whether stored in PDS or `ent:contactInfo`.

## When to use PDS settings

**Put in PDS settings** (`pds add_settings`, keyed by ruleset RID):

- Per-app **configuration** and feature flags (`shareEmail`, thresholds, notification toggles stored as settings rather than general).
- Data the owning ruleset reads via **`pds:config_value("key")`** (`meta:callingRID()` scopes the read).

Keep **runtime operational state** (last run id, debounce timers, in-flight maps) in the app RS unless another ruleset must read it.

## Decision checklist

```
Need cross-RS or cross-pico read with a stable API?
  → yes: PDS (profile, general, or settings by shape)
  → no:  app ent:*

Display identity for this pico in UI or notifications?
  → PDS profile

Only this ruleset ever touches it, and mirrors can replay the app event?
  → app ent:* + register event for mirror (future)

Rebuilt automatically from subscription/wrangler/manifold events?
  → derived app ent:* (do not duplicate in PDS)

Layout, cache, or inbox scratch state?
  → app ent:*
```

## Mirroring (how this fits)

| Mechanism | Role |
|-----------|------|
| **Selective event log** | Source of truth for **living** and **network** mirrors — replay wrangler, manifold, `pds:*`, and opt-in app events |
| **PDS snapshot** | Convenient **simple mirror** export (`profile` + `general` + `settings` + installed RIDs) |
| **App `ent:*`** | Materialized views — repopulated on replay; not required in a snapshot if events are complete |

PDS **`pds:*` write events** belong in the platform log. App **`ent:*`** updates that are *only*
side effects of those events do not need separate logging if replay re-raises the same events.

---

# Installing and using PDS in KRL

PDS is **default-installed by pico-engine** on the root pico and on every child pico at creation
(via `io.picolabs.wrangler` `initialize_child_after_creation`). Manifold bootstrap and creation
flows no longer send explicit PDS install requests (Phase F).

Manifold still ships `io.picolabs.pds.krl` in this repo for development and flush during mount
iteration; the engine-bundled copy is canonical for runtime picos created without a manifold-api
mount.

**Historical install hooks (pre–Phase F):**

| Pico | Ruleset | When |
|------|---------|------|
| Tag Registry | `io.picolabs.manifold_bootstrap` | ~~PDS before `new_tag_registry`~~ engine default |
| Skills Registry | `io.picolabs.manifold_bootstrap` | ~~PDS before `skills_registry`~~ engine default |
| Owner | `io.picolabs.manifold_bootstrap` | ~~PDS before `profile`~~ engine default |
| Manifold hub | `io.picolabs.manifold_owner` | ~~PDS before `manifold_pico`~~ engine default |
| Thing | `io.picolabs.manifold_pico` | ~~PDS before `thing`~~ engine default |
| Community | `io.picolabs.manifold_pico` | ~~PDS before `community`~~ engine default |

`manifold_pico` `updateManifoldVersion` ensures notification RS are present; PDS is not re-installed.

When `io.picolabs.pds` installs, it creates a **`pds`-tagged channel** on that pico:

- **Events:** `pds:*` (writes such as `updated_profile`, `new_data_available`)
- **Queries:** `io.picolabs.pds:*` (reads such as `profile`, `items`)

Use that channel ECI for HTTP/sky access. The engine UI channel does **not** allow PDS queries. Same-pico KRL uses `use module io.picolabs.pds` instead. Cross-pico reads use `wrangler:picoQuery(eci, …)` on a channel whose query policy allows `io.picolabs.pds`.

In any ruleset that needs to read PDS data on **the same pico**:

```krl
meta {
  use module io.picolabs.pds alias pds
}
```

To read PDS on **another pico**, use `wrangler:picoQuery()` (same pattern as subscription and Wrangler queries):

```krl
displayName = wrangler:picoQuery(thing_eci, "io.picolabs.pds", "profile", "name"){"profile"};
```

Use the **thing’s query channel** (subscription `Tx` or UI channel), subject to that channel’s query policy allowing `io.picolabs.pds`.

---

# Reading data (queries)

PDS shares several query functions. All return a map with a `"status"` key (`"success"` or `"failed"`) and a payload key (`"profile"`, `"general"`, or `"settings"`) unless noted.

## Profile

**Function:** `profile(key)`

The profile is **this pico’s profile** — how the pico identifies and presents itself in UIs, lists, and notifications. It is **not** automatically a human’s profile.

| Pico type | What `ent:profile` represents | Example `name` |
|-----------|------------------------------|----------------|
| **Owner** pico | The person who owns this Manifold (may include contact fields) | `"Phil Windley"` |
| **Thing** pico | The trackable object or device | `"Blue Backpack"` |
| **Community** pico | The group or collection | `"Garden Sensors"` |
| **Manifold** pico | The hub pico itself (rarely shown in UI) | `"Manifold"` |
| **Registry** pico | The registry service | `"Tag Registry"` |

Each pico has its **own** `ent:profile`. A thing’s name is not the owner’s name unless you explicitly copy or link them in application logic. Human contact information for notifications belongs on the **owner** pico (today via `io.picolabs.profile`, eventually extended PDS profile fields there).

| Call | Returns |
|------|---------|
| `profile()` | Full `ent:profile` map for **this** pico |
| `profile("name")` | Single field wrapped in `"profile"` |

```krl
use module io.picolabs.pds alias pds

allProfile = pds:profile(){"profile"};
name = pds:profile("name"){"profile"};
```

Default profile shape when empty:

```json
{
  "name": "",
  "description": "",
  "photo": "https://s3.amazonaws.com/k-mycloud/a169x672/unknown.png"
}
```

On any Manifold pico, **`profile("name")`** is the canonical display label for that pico in UI lists and notifications (e.g. a thing’s name in `getThings()`, a community name in `getCommunities()`). Prefer `pds:profile("name")` over `wrangler:name()` in application rulesets — but remember you are reading **the pico’s name**, not the owner’s name, unless you are querying the owner pico’s PDS.

## General items (namespaced data)

**Function:** `items(namespace, key)`

| Call | Returns |
|------|---------|
| `items(null, null)` | Entire `ent:general` tree (use sparingly) |
| `items("myapp", null)` | All keys under namespace `"myapp"` |
| `items("myapp", "contact")` | Single value at `ent:general{"myapp", "contact"}` |

```krl
card = pds:items("safeandmine", "contact"){"general"};
allTags = pds:items("safeandmine", null){"general"};
```

If `namespace` is null, status is `"failed"`.

## Settings

**Functions:**

| Function | Purpose |
|----------|---------|
| `settings(rid, key, detail)` | Full settings entry or sub-key for ruleset `rid` |
| `setting_data(rid)` | The `"Data"` map for `rid` |
| `setting_data_value(rid, setKey)` | One key inside `"Data"` |
| `config_value(setKey)` | **`meta:callingRID()`** — caller’s own settings data key |

The **`config_value`** pattern is the idiomatic way for a ruleset to read its own preferences without hard-coding its RID:

```krl
use module io.picolabs.pds alias pds

threshold = pds:config_value("threshold");
shareEmail = pds:config_value("shareEmail");
```

---

# Writing profile data

Profile updates are **partial merges** on **this pico’s** `ent:profile`. Omitted attributes keep their previous values. PDS sets `_created` on first write and `_modified` on every successful update.

When updating a thing or community, you are setting **that pico’s display identity**, not the owner’s. To update the person’s contact info, target the **owner** pico (and the appropriate profile or general namespace there).

## Updating profile

Raise **`pds updated_profile`** with any subset of profile fields:

```krl
raise pds event "updated_profile"
  attributes {
    "name": "Blue Backpack",
    "description": "Phil's day pack",
    "photo": "https://example.com/photo.jpg"
  };
```

PDS merges with the existing profile and raises **`pds profile_updated`** with a `_status` attribute (`"success"` or `"failure"`).

## Reacting to profile changes

```krl
rule onProfileUpdated {
  select when pds profile_updated
  pre {
    name = event:attr("name");
    status = event:attr("_status");
  }
  if status == "success" then
    send_directive("profile saved", {"name": name});
}
```

---

# Writing general (namespaced data)

General data is organized as **`namespace` + `key` → value**. Values may be scalars or maps. Use namespaces to avoid collisions between apps (e.g. `safeandmine`, `sensor`, `manifold`).

## Add or replace an item

**Event:** `pds new_data_available`

```krl
raise pds event "new_data_available"
  attributes {
    "namespace": "safeandmine",
    "key": "contact",
    "value": {
      "email": "owner@example.com",
      "phone": "555-0100",
      "message": "Please return this item.",
      "shareName": true,
      "shareEmail": false
    }
  };
```

PDS raises **`pds data_added`** with `namespace` and `keyvalue` attributes.

## Update nested fields inside a map item

**Event:** `pds updated_data_available`

The `value` attribute is a map of sub-keys to merge into the existing item (similar to a patch):

```krl
raise pds event "updated_data_available"
  attributes {
    "namespace": "safeandmine",
    "key": "contact",
    "value": {
      "phone": "555-0199"
    }
  };
```

PDS raises **`pds data_updated`** (once per foreach iteration; `if last` on the final notification).

## Replace an entire namespace map

**Event:** `pds map_item`

```krl
raise pds event "map_item"
  attributes {
    "namespace": "safeandmine",
    "mapvalues": {"tag1": "eci-abc", "tag2": "eci-def"}.encode()
  };
```

`mapvalues` is JSON-encoded. PDS decodes and stores the map at `ent:general{namespace}`. Raises **`pds new_map_added`**.

## Remove an item or namespace

**Remove one key:**

```krl
raise pds event "remove_old_data"
  attributes {
    "namespace": "safeandmine",
    "key": "contact"
  };
```

Raises **`pds data_deleted`**.

**Remove entire namespace:**

```krl
raise pds event "remove_namespace"
  attributes {"namespace": "safeandmine"};
```

Raises **`pds namespace_deleted`**.

---

# Writing settings data

Settings are keyed by **ruleset RID**. Each entry has `name`, `rid`, `data` (map), and optional `schema`.

**Event:** `pds add_settings`

```krl
raise pds event "add_settings"
  attributes {
    "name": "SafeAndMine",
    "keyed_rid": "io.picolabs.safeandmine",
    "schema": [],
    "data_key": "shareEmail",
    "value": true
  };
```

PDS raises **`pds settings_added`** with the original attrs.

For bulk config, prefer multiple `add_settings` events or a planned `pds update_settings_data` event (future) that merges into `ent:settings{rid}{"Data"}`.

---

# Reacting to data changes

Subscribe to **`pds`** domain events to reconfigure or notify when data changes:

| Event | Fired when |
|-------|------------|
| `pds data_added` | New general item |
| `pds data_updated` | General item patched |
| `pds data_deleted` | General item removed |
| `pds namespace_deleted` | Entire namespace removed |
| `pds new_map_added` | Namespace replaced with map |
| `pds profile_updated` | Profile merge completed |
| `pds settings_added` | Settings entry updated |

Example: refresh a UI when contact card changes:

```krl
rule refreshContactUI {
  select when pds data_updated
    where event:attr("namespace") == "safeandmine"
      && event:attr("keyvalue") == "contact"
  always {
    raise engine_ui event "refresh" attributes {};
  }
}
```

---

# Clearing data

**Event:** `pds clear_all_data`

Clears **`ent:general`**, **`ent:profile`**, and **`ent:settings`** on this pico. Intended for **tests and dev tools**, not routine app uninstall.

On ruleset uninstall, prefer clearing only the app’s namespace (`remove_namespace`) and settings for that RID — profile should usually survive app removal.

---

# Advanced example: app data on a thing pico

This example shows idiomatic PDS usage on a Manifold **thing** pico running a domain ruleset. The app keeps its lost-and-found card in **general** data, uses **profile** for the thing name in Manifold, and reads **settings** for share flags.

Assume both `io.picolabs.pds` and `io.picolabs.safeandmine` are installed.

##### **Save contact card (write through PDS)**

```krl
meta {
  use module io.picolabs.pds alias pds
}

rule information_update {
  select when safeandmine update
  pre {
    email = event:attr("email").defaultsTo("").substr(0, 100)
    phone = event:attr("phone").defaultsTo("").substr(0, 100)
    message = event:attr("message").defaultsTo("").substr(0, 250)
    card = {
      "email": email,
      "phone": phone,
      "message": message,
      "shareName": event:attr("shareName").as("Boolean").defaultsTo(false),
      "sharePhone": event:attr("sharePhone").as("Boolean").defaultsTo(false),
      "shareEmail": event:attr("shareEmail").as("Boolean").defaultsTo(false)
    }
  }
  always {
    raise pds event "new_data_available"
      attributes {
        "namespace": "safeandmine",
        "key": "contact",
        "value": card
      };
  }
}
```

##### **Read public contact info (compose profile + card + share flags)**

```krl
rule getInformation {
  select when safeandmine getInformation
  pre {
    card = pds:items("safeandmine", "contact"){"general"}.defaultsTo({});
    profileName = pds:profile("name"){"profile"};
    publicName = card{"shareName"} => profileName | null;
    result = card.put("name", publicName);
  }
  always {
    send_directive("contact info", result);
  }
}
```

##### **Notification uses profile name, not app ent var**

```krl
rule notify {
  select when safeandmine notify
  pre {
    thingName = pds:profile("name"){"profile"};
    tagID = event:attr("tagID");
    picoId = wrangler:myself(){"id"};
    message = "Your tag " + tagID + " has been scanned";
  }
  if tagID && picoId && thingName then
    event:send({
      "eci": manifold_eci,
      "domain": "manifold",
      "type": "add_notification",
      "attrs": {
        "picoId": picoId,
        "thing": thingName,
        "app": "SafeAndMine",
        "message": message,
        "ruleset": meta:rid
      }
    });
}
```

This keeps **Manifold display identity** in PDS profile and **app-specific public data** in `general.safeandmine`, matching the separation described in Manifold architecture docs.

---

# PDS data model

PDS persists three entity variables. **Only PDS rules should write these directly.** For guidance
on what to store here versus in application rulesets, see
[What belongs in PDS (and what doesn't)](#what-belongs-in-pds-and-what-doesnt).

## `ent:profile`

**This pico’s** display identity — one profile map per pico, not one profile per person for the whole Manifold tree:

```json
{
  "name": "Blue Backpack",
  "description": "Phil's hiking pack",
  "photo": "https://…",
  "_created": "20260609T120000+0000",
  "_modified": "20260609T153000+0000"
}
```

The example above is a **thing** pico’s profile. An **owner** pico might instead look like:

```json
{
  "name": "Phil Windley",
  "description": "",
  "photo": "https://…",
  "email": "phil@example.com",
  "phone": "+1-555-0100"
}
```

Optional profile fields (`email`, `phone`) may be set on any pico via `pds updated_profile` — e.g. owner contact info, or a thing that exposes its own reachability. Manifold's initial use is owner migration from `io.picolabs.profile`; thing and community picos often use `name`, `description`, and `photo` only.

## `ent:general`

Tree of namespaces and keys:

```
ent:general
  "safeandmine"
    "contact"  → { email, phone, message, shareName, … }
    "registry_eci" → "channel-eci-…"
  "sensor"
    "last_reading" → { … }
```

Path syntax in KRL: `ent:general{[namespace, key]}` or nested maps under a namespace via `map_item`.

## `ent:settings`

Per-ruleset configuration:

```json
{
  "io.picolabs.safeandmine": {
    "name": "SafeAndMine",
    "rid": "io.picolabs.safeandmine",
    "data": {
      "shareEmail": false,
      "threshold": 60
    },
    "schema": []
  }
}
```

---

# Namespace conventions (Manifold)

Use predictable namespace strings so apps coexist on one pico:

| Namespace | Owner | Examples |
|-----------|-------|----------|
| `manifold` | Platform / bootstrap | delegation rcn stash (if moved from app RS) |
| `safeandmine` | SafeAndMine app | `contact`, `tags`, `registry_eci` |
| `sensor` | Sensor network | cached readings, community refs |
| `<app-rid>` | General rule | match ruleset RID for clarity |

Do not store secrets in PDS general data unless query policies restrict access. Channel ECIs are capabilities — treat them as sensitive.

---

# Understanding the protocol

## Write path

1. Application ruleset raises a **`pds`** domain event (`updated_profile`, `new_data_available`, …).
2. PDS rule selects, validates attrs, updates the appropriate `ent:*` variable.
3. PDS raises a **notification event** (`profile_updated`, `data_added`, …) on the same pico.
4. Other rulesets (or UI) select on notification events to react.

Apps **never** assign `ent:profile`, `ent:general`, or `ent:settings` in their own rules. This keeps persistence and audit in one place.

## Read path

1. Same pico: `use module io.picolabs.pds` → call shared functions.
2. Other pico: `wrangler:picoQuery(eci, "io.picolabs.pds", function, params)` on an allowed channel.

## Comparison to subscriptions

| | Subscriptions | PDS |
|--|---------------|-----|
| **Problem** | Cross-pico communication | Intra-pico data storage |
| **Mechanism** | Channels + subscription RS | Events + shared queries |
| **Identity** | Tx, Rx, roles | Profile name, namespaces |
| **Install** | Preinstalled with Wrangler | Installed on every Manifold pico (target) |

Use **subscriptions** to send events between picos. Use **PDS** so each pico exposes a consistent profile and app data API to its own rulesets and to authorized queries from peers.

## Event flow (profile update)

```
App RS                    PDS                         Other RS on same pico
  |                        |                                    |
  |-- pds updated_profile ->|                                    |
  |                        |-- merge ent:profile                |
  |                        |-- pds profile_updated ----------->| (optional select)
  |                        |                                    |
```

## Event flow (general item add)

```
App RS                    PDS
  |                        |
  |-- pds new_data_available (namespace, key, value) ->|
  |                        |-- ent:general.put([namespace, key], value)
  |                        |-- pds data_added
```

---

# Security model

PDS is a **data contract**, not a hardened authorization layer. Understand where enforcement actually lives.

## Entity variable isolation

KRL entity variables are **scoped to the ruleset (RID)**, not shared across the pico. PDS stores
`ent:profile`, `ent:general`, and `ent:settings` inside **`io.picolabs.pds` only**. Another
ruleset's `ent:contactInfo` (or any other `ent:*` name) is a separate variable in that ruleset's
namespace — it cannot overwrite PDS storage directly.

Apps reach PDS data through:

- **Reads:** `use module io.picolabs.pds` (module closure over PDS entity vars), or
  `wrangler:picoQuery(..., "io.picolabs.pds", ...)` on another pico.
- **Writes:** raise **`pds`** domain events; only PDS rules mutate PDS entity vars.

## What is enforced today

| Layer | Mechanism | What it protects |
|-------|-----------|------------------|
| **Cross-pico access** | ECI + channel event/query policy | Remote events and queries (including PDS queries) |
| **Install trust** | Wrangler / Manifold bootstrap | Which rulesets run on the pico |
| **Same-pico PDS writes** | *(none in PDS rules today)* | — |

Any **installed ruleset on the same pico** can raise `pds updated_profile`, `pds new_data_available`,
`pds clear_all_data`, and similar events. PDS accepts them without checking which ruleset raised the
event (`meta:callingRID()` is used on settings **reads**, not on writes). Security therefore depends
on **trusting every ruleset installed on that pico**.

Cross-pico callers need an ECI whose policy allows the relevant `pds` events or
`io.picolabs.pds` queries — uncommon for writes today; reads follow normal query policy.

**Human authentication** (owner login, OIDC session) is separate: it governs who uses the UI, not
which ruleset may write PDS on a thing pico.

## Practical guidance

- **Curate installs.** Manifold should only install known platform and domain rulesets on production picos.
- **Use namespaces consistently** so apps do not duplicate canonical data in their own `ent:*` vars.
- **Follow [What belongs in PDS](#what-belongs-in-pds-and-what-doesnt)** — profile for identity; general when shared; derived caches stay on the app RS.
- **Restrict query channels** when PDS general data includes sensitive fields; ECIs are bearer capabilities.
- **Treat `pds clear_all_data` as destructive** — avoid raising it outside test harnesses.

## Planned improvements

See [`MEMORY.md`](../MEMORY.md) for the full roadmap. Summary:

- **PDS write authorization** — check `meta:callingRID()` on write events (e.g. only the owning app
  RID writes its `general` namespace; platform RIDs for profile on owner/thing picos).
- **Engine boundary** — SPIFFE workload identity and optional Cedar policy before events reach rulesets
  (cross-pico impersonation, sensitive channels).
- **Channel templates and install allowlists** — limit what application rulesets can declare at runtime.

---

# See also

- [Managing Subscriptions](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186843209/Managing+Subscriptions) — cross-pico channels and roles
- [Managing Channels](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186810389/Managing+Channels) — ECI and channel policies
- Manifold [`README.md`](../README.md) — architecture and pico types
- [`MEMORY.md`](../MEMORY.md) — PDS security mitigations, install policy, SPIFFE/Cedar roadmap

---

*Copyright Picolabs | Licensed under Creative Commons.*
