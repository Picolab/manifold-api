# Manifold

**Source:** [Picolab/manifold-api](https://github.com/Picolab/manifold-api) on GitHub  
**Product site:** [manifold.picolabs.io](https://manifold.picolabs.io/)  
**Runtime:** [Pico Engine](https://github.com/Picolab/pico-engine) 1.8+  
**Related:**

- [Managing Subscriptions](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186843209/Managing+Subscriptions)
- [Managing PDS](./Managing_PDS.md) (Pico Data Services)
- [Managing Channels](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186810389/Managing+Channels)

> **Status (2026):** Manifold is a production-ready KRL framework for building and operating **networks of picos** on the pico engine. Rulesets, bootstrap automation, integration tests, and documentation live in the [manifold-api](https://github.com/Picolab/manifold-api) repository.

---

## Table of contents

1. [What is Manifold?](#what-is-manifold)
2. [Architecture](#architecture)
3. [Core concepts](#core-concepts)
4. [Bootstrap](#bootstrap)
5. [Things and communities](#things-and-communities)
6. [Registries](#registries)
7. [Notifications](#notifications)
8. [PDS integration](#pds-integration)
9. [Extending Manifold](#extending-manifold)
10. [Core rulesets](#core-rulesets)
11. [Getting started](#getting-started)
12. [Further reading](#further-reading)

---

## What is Manifold?

**Manifold** is a framework layered on the [pico engine](https://github.com/Picolab/pico-engine) for creating, organizing, and operating **networks of picos** — persistent, event-driven agents that can represent people, places, devices, and groups.

Where the pico engine provides execution (rulesets, events, subscriptions, channels), Manifold provides:

- **Structure** — a consistent parent/child hierarchy under the engine root
- **Lifecycle** — automated bootstrap to stand up an owner, hub, and shared registries
- **Thing and community management** — create picos, track membership, route events
- **Shared services** — centralized notifications, tag registry
- **Data conventions** — profile and app data via [PDS](./Managing_PDS.md) on every pico

Manifold is not a single application. It is a **platform of KRL rulesets** that domain projects install and extend — for example:

- **Connected product / vehicle meshes** (Fuse-style multi-party car networks)
- **Household and personal IoT** with things and communities
- **Tagged objects and lost-and-found** (SafeAndMine on thing picos)
- **Home Assistant** and similar integrators (`io.picolabs.homeassistant` on the hub)
- **Sensor or facility monitoring** (dedicated repos add bootstrap rulesets on the Manifold pico)

**Source code:** platform rulesets, bootstrap, tests, and generated API docs live in **[github.com/Picolab/manifold-api](https://github.com/Picolab/manifold-api)** — see [`docs/llms.txt`](llms.txt) and [`docs/rulesets/`](rulesets/README.md).

---

## Architecture

Manifold organizes a personal network of picos as a small graph under the engine's **root pico**. Solid lines are **parent/child** relationships (Wrangler hierarchy). Dashed lines are **subscriptions** — membership links used for event routing between peers.

```
Root Pico (engine)
  ├─ Tag Registry pico
  └─ Owner pico
       └─ Manifold pico (operational hub)
            ├─ Thing picos  ··· subscribe ···► Community picos
            └─ ...
```

A detailed diagram ships with the repo: [`manifold_network.png`](https://github.com/Picolab/manifold-api/blob/main/manifold_network.png).

| Pico | Rulesets (typical) | Role |
|------|-------------------|------|
| **Root** | `io.picolabs.manifold_bootstrap` | One-time bootstrap; creates registries and owner |
| **Tag Registry** | `io.picolabs.new_tag_registry` | NFC/QR tag IDs → thing picos and redirect URLs |
| **Owner** | `io.picolabs.profile`, `io.picolabs.manifold_owner` | Human owner; contact info; owns the Manifold child |
| **Manifold** | `io.picolabs.manifold_pico`, `io.picolabs.notifications`, … | Creates things/communities; tracks inventory; notification hub |
| **Thing** | `io.picolabs.thing` + domain RSs | Trackable object or device; joins communities |
| **Community** | `io.picolabs.community` | Groups things; accepts members; can broadcast to them |

---

## Core concepts

### Picos and Wrangler

Every Manifold entity is a **pico** — a container for rulesets, entity variables, channels, and subscriptions. Parent/child relationships and pico lifecycle (create, name, delete) go through **`io.picolabs.wrangler`**.

### Subscriptions

**Subscriptions** connect picos for event exchange (e.g. Manifold ↔ thing, community ↔ thing). Roles (`Rx_role`, `Tx_role`) define who receives which events. See [Managing Subscriptions](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186843209/Managing+Subscriptions).

### Channels and ECIs

Each pico exposes **channels**; an **ECI** (Event Channel Identifier) is the address used in Sky Cloud queries and Sky Events. Manifold bootstrap returns ECIs for the registries and owner so clients and other rulesets can reach the right pico.

### Things vs communities

- A **thing** pico represents one trackable entity (backpack, sensor, appliance).
- A **community** pico groups related things (travel gear, home sensors, a project team).
- A thing may belong to **multiple** communities via subscriptions.

---

## Bootstrap

Manifold provides one-step bootstrap on the engine root pico.

1. Install **`io.picolabs.manifold_bootstrap`** on the root pico.
2. Bootstrap creates the tag registry and owner pico (which in turn creates the Manifold pico).
3. Query **`getBootstrapStatus()`** on the root pico's bootstrap channel for ECIs.

Manual step-by-step bootstrap (tag registry first, then owner, then tag-server registration) is documented in the [repository README](https://github.com/Picolab/manifold-api#bootstrap).

**Important:** register the tag registry with the owner (`manifold:new_tag_server`) **before** creating things that use NFC/QR tags.

---

## Things and communities

The **Manifold pico** (`io.picolabs.manifold_pico`) is the operational hub:

- **`createThing`** / **`createCommunity`** — Wrangler child picos with base rulesets installed
- **`getThings()`** / **`getCommunities()`** — inventory queries
- **Delegation** — domain bootstrap rulesets (e.g. sensor-network) can request thing creation via callback ECIs
- **Deletion** — coordinated child removal and subscription cleanup

Base behavior lives in:

- **`io.picolabs.thing`** — community membership, `notifyCommunity`, auto-accept patterns
- **`io.picolabs.community`** — `addThing`, `things()`, broadcast to members

---

## Registries

### Tag registry

Maps physical tag identifiers (NFC, QR) to thing picos and redirect URLs. Used by **SafeAndMine** and similar apps so a scanned tag resolves to the correct thing.

### Extensibility and discovery (1.8+)

Domain rulesets document shared events and queries with **`/** … */`** annotations. The pico engine exposes them via **ruleset schema** (UI Testing tab, `ruleset_schema` MCP tool, and `krl check`). Prefer that over ad hoc registries when agents or operators need to discover how to call your bootstrap rulesets.

---

## Notifications

Notification delivery is **centralized on the Manifold pico**. Bootstrap installs:

- `io.picolabs.notifications` — orchestrator
- `io.picolabs.twilio.sms` — SMS (Twilio)
- `io.picolabs.prowl` — push (Prowl)

Any thing, community, or domain ruleset raises **`manifold add_notification`** on the Manifold pico with a subject **`picoId`**, human-readable **`message`**, and identifying attrs (`thing`, `app`, `ruleset`). Manifold fans the alert to enabled channels:

| Channel | Behavior |
|---------|----------|
| **Manifold** | In-app inbox (`getNotifications()`) |
| **SMS** | Twilio, using owner phone from profile/PDS |
| **Prowl** | Push via owner's Prowl API key |

Channels are **opt-in per subject pico**. Domain rulesets should not call Twilio or Prowl directly — raise `manifold add_notification` and let Manifold route using owner credentials.

Toggle channels with **`manifold change_notification_setting`** and attrs `{ id: picoId, option: "Manifold" }` (or `"SMS"`, `"Prowl"`).

---

## PDS integration

**Pico Data Services** (`io.picolabs.pds`) is the shared data layer on each pico: profile (name, description, photo), namespaced general data, and per-ruleset settings.

As of pico-engine **1.4.0**, PDS is **default-installed** on the root pico and every child at creation. Manifold rulesets read display names and contact fields through PDS rather than ad hoc entity variables.

See **[Managing PDS](./Managing_PDS.md)** for queries, events, namespace conventions, and migration guidance.

---

## Extending Manifold

Manifold is designed to be extended by **domain repositories** that install additional rulesets on the Manifold pico and delegate setup to it.

**Reference app: [sensor-network](https://github.com/Picolab/sensor-network)** — LoRaWAN Dragino sensors on Manifold:

| Piece | Location |
|-------|----------|
| Bootstrap RS | `io.picolabs.sensor.network_bootstrap` on the **Manifold pico** |
| Community RS | `io.picolabs.sensor.community` on each sensor community child |
| Operator guide | [sensor-network README](https://github.com/Picolab/sensor-network/blob/main/README.md) (delegation flow, Sky event examples) |
| Integration tests | [sensor-network `t/`](https://github.com/Picolab/sensor-network/tree/main/t) — Docker harness with `dependsOn: manifold-api`, scenarios for community + thing creation |
| Discovery annotations | `/** … @attr … */` on shared events/queries (engine 1.8 `krl check` / MCP `ruleset_schema`) |

Flow in brief:

1. Install **`io.picolabs.sensor.network_bootstrap`** on the Manifold pico after Manifold bootstrap.
2. Raise **`sensor create_community`** on the Manifold **app** channel → `manifold new_community` → install `io.picolabs.sensor.community` on the child → opt into notifications.
3. Raise **`sensor initiation`** on the community **`sensor`** channel → `manifold create_thing` → `community thing_created` callback → `community add_thing` + router rulesets on the thing.

The pattern for new domains:

1. Add a bootstrap ruleset on the **Manifold pico** (not the root).
2. Use Manifold's thing/community creation APIs or events rather than calling Wrangler directly from scattered picos.
3. Raise **`manifold add_notification`** for user-visible alerts.
4. Store shared display data in **PDS profile**; keep high-churn or private state in app `ent:*` vars.
5. Add integration scenarios in your repo; reuse the [manifold-api test harness](https://github.com/Picolab/manifold-api/tree/main/t) via `dependsOn` and `manifoldApiPath`.

---

## Core rulesets

| Ruleset | Installed on | Purpose |
|---------|--------------|---------|
| `io.picolabs.manifold_bootstrap` | Root | Full network bootstrap |
| `io.picolabs.new_tag_registry` | Tag registry | Tag ID → thing mapping |
| `io.picolabs.profile` | Owner | Owner profile shim (PDS-backed) |
| `io.picolabs.manifold_owner` | Owner | Manifold child lifecycle |
| `io.picolabs.manifold_pico` | Manifold | Things, communities, delegation |
| `io.picolabs.notifications` | Manifold | Notification orchestrator |
| `io.picolabs.twilio.sms` | Manifold | SMS delivery |
| `io.picolabs.prowl` | Manifold | Prowl push |
| `io.picolabs.thing` | Thing | Base thing behavior |
| `io.picolabs.community` | Community | Base community behavior |
| `io.picolabs.pds` | All picos | Pico Data Services (engine default-install) |
| `io.picolabs.safeandmine` | Thing | SafeAndMine tag integration |

Full list and status notes: [manifold-api README — Ruleset Status](https://github.com/Picolab/manifold-api#ruleset-status).

---

## Getting started

### Prerequisites

- [Pico Engine](https://github.com/Picolab/pico-engine) **1.8+** (Docker or npm install); rulesets carry `/** */` discovery annotations, and `io.picolabs.journal` and `io.picolabs.safeandmine` build their discovery bindings with `wrangler:schemaBindings`, which is new in 1.8
- KRL rulesets from **[github.com/Picolab/manifold-api](https://github.com/Picolab/manifold-api)**

### Quick path

1. Clone the repository:

   ```bash
   git clone https://github.com/Picolab/manifold-api.git
   ```

2. Start a pico engine (Docker example):

   ```bash
   docker run -p 3000:3000 -v ~/pico-image:/var/pico-image -d picolabs/pico-engine:latest
   ```

3. Install **`io.picolabs.manifold_bootstrap`** on the root pico and complete bootstrap (Developer UI or Sky API).

4. Access picos via Sky Cloud / Sky Events, or the engine Developer UI.

### Integration tests

The repo includes a TypeScript harness that runs against a real engine in Docker:

```bash
cd manifold-api
npm install
npm test
```

See [`t/README.md`](https://github.com/Picolab/manifold-api/blob/main/t/README.md) for flags, scenario list, and cross-repo setup (sensor-network).

### API access

After bootstrap:

- **Queries:** `GET /sky/cloud/{eci}/{ruleset}/{function}`
- **Events:** `POST /sky/event/{eci}/{eid}/{domain}/{type}`

---

## Further reading

- **[Picolab/manifold-api](https://github.com/Picolab/manifold-api)** — source, README, integration tests
- **[Ruleset API (generated)](rulesets/README.md)** — annotated events and queries per RID
- **[llms.txt](llms.txt)** — machine-readable doc index for agents
- **[Picolab/pico-engine](https://github.com/Picolab/pico-engine)** — runtime, wrangler OS, operator guide
- **[Managing PDS](./Managing_PDS.md)** — data model and events on every pico
- **[Managing Subscriptions](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186843209/Managing+Subscriptions)** — cross-pico event routing
- **[Developer Tips for Pico Engine](https://picolabs.atlassian.net/wiki/spaces/docs/pages/31544297/Developer+Tips+for+Pico+Engine)** — Docker, parsing KRL, local development
