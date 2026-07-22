# Manifold

**Source:** [Picolab/manifold-api](https://github.com/Picolab/manifold-api) on GitHub  
**Product site:** [manifold.picolabs.io](https://manifold.picolabs.io/)  
**Runtime:** [Pico Engine](https://github.com/Picolab/pico-engine) 1.4+  
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
- **Shared services** — centralized notifications, tag registry, skills directory
- **Data conventions** — profile and app data via [PDS](./Managing_PDS.md) on every pico

Manifold is not a single application. It is a **platform of KRL rulesets** that domain projects (SafeAndMine, sensor networks, custom IoT stacks) install and extend.

**Source code:** all Manifold platform rulesets, bootstrap logic, and integration tests are maintained in **[github.com/Picolab/manifold-api](https://github.com/Picolab/manifold-api)**.

---

## Architecture

Manifold organizes a personal network of picos as a small graph under the engine's **root pico**. Solid lines are **parent/child** relationships (Wrangler hierarchy). Dashed lines are **subscriptions** — membership links used for event routing between peers.

```
Root Pico (engine)
  ├─ Tag Registry pico
  ├─ Skills Registry pico
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
| **Skills Registry** | `io.picolabs.manifold.skills_registry` | Named skills (ruleset IDs, MCP tool defs) installable on things |
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
2. Bootstrap creates the tag registry, skills registry, and owner pico (which in turn creates the Manifold pico).
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

### Skills registry

A queryable directory of **skills** — named capabilities (ruleset RIDs, optional install URLs, MCP tool metadata) that can be added to thing picos. Manifold and domain rulesets consult it when extending a thing.

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

**Example: [sensor-network](https://github.com/windley/sensor-network)** — temperature/sensor communities:

- Installs `io.picolabs.sensor.network_bootstrap` on the Manifold pico
- Raises **`sensor create_community`**; Manifold creates the community child and installs base + sensor rulesets
- Raises **`sensor initiation`**; Manifold creates thing picos, installs sensor router rulesets, wires subscriptions

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
| `io.picolabs.manifold.skills_registry` | Skills registry | Skills directory |
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

- [Pico Engine](https://github.com/Picolab/pico-engine) **1.4+** (Docker or npm install)
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
- **[Picolab/pico-engine](https://github.com/Picolab/pico-engine)** — runtime and Developer UI
- **[Managing PDS](./Managing_PDS.md)** — data model and events on every pico
- **[Managing Subscriptions](https://picolabs.atlassian.net/wiki/spaces/docs/pages/186843209/Managing+Subscriptions)** — cross-pico event routing
- **[Developer Tips for Pico Engine](https://picolabs.atlassian.net/wiki/spaces/docs/pages/31544297/Developer+Tips+for+Pico+Engine)** — Docker, parsing KRL, local development
