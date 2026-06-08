# Manifold integration tests

Local TypeScript tests for Manifold KRL rulesets. Tests run on your machine against a **real
pico-engine** in a **single Docker container**. Ruleset source is bind-mounted from this repo so
you can edit KRL, re-run, and iterate without rebuilding the image.

See also `MEMORY.md` → **WHERE WE ARE** for project status and planned phases.

## What happens when you run tests

```
npm test
  │
  ├─ 1. Parse gate     krl-compiler --verify on every *.krl under configured mounts
  │                    (respects parseExclude; fails fast before Docker)
  │
  ├─ 2. Docker up      one container, random port 5001–6999, TESTING=1
  │                    repo → /var/manifold-api inside container
  │                    pico state → /tmp/manifold-api-pico-test-<id> on host
  │
  ├─ 3. Scenarios      TypeScript functions in t/scenarios/
  │                    signal events, query picos, assert outcomes
  │
  └─ 4. Teardown       pass  → stop container, delete pico home (unless --retain-logs)
                       fail  → leave container running for inspection
                       --keep → never stop container
```

## Prerequisites

1. **Docker** — running and reachable from your shell (`docker ps`).
2. **Node.js 18+** — for `npm` and `tsx`.
3. **A pico-engine image** — default `picolabs/pico-engine:latest`.

Check for a local image:

```bash
docker images picolabs/pico-engine
```

Build or pull if needed ([pico-engine Dockerfile](https://github.com/Picolab/pico-engine)):

```bash
docker build -t picolabs/pico-engine:latest https://github.com/Picolab/pico-engine.git
```

Override the image without editing config:

```bash
export PICO_ENGINE_IMAGE=pjw/pico-engine:latest
```

One-time setup from the repo root:

```bash
npm install
```

## Running tests

All commands are run from the **repo root** (`manifold-api/`), not from `t/`.

| Command | What it does |
|---------|----------------|
| `npm test` | Full run: parse → Docker → scenarios → teardown |
| `npm run test:parse` | Parse gate only (no Docker) |
| `npm run test:keep` | Full run but leave container up afterward |
| `npm run test:cleanup` | Remove all test containers and `/tmp` pico homes for this repo |
| `npm test -- --help` | List flags |

### Common flag combinations

```bash
# Fast syntax check while editing KRL
npm run test:parse

# Docker smoke test without parse (e.g. parse known-broken pending RSs)
npm test -- --skip-parse

# Parse only, no container (same as test:parse)
npm test -- --skip-docker

# After a failure — container was left running; inspect then clean up
cat t/.runtime.json
open $(node -p "require('./t/.runtime.json').baseUrl")   # engine UI
docker rm -f $(node -p "require('./t/.runtime.json').containerName")

# Keep pico DB/logs on disk after success for post-mortem
npm test -- --retain-logs

# Leave container running even when everything passes
npm run test:keep

# Remove containers and logs left by test:keep or failed runs
npm run test:cleanup
npm run test:cleanup -- --dry-run
```

### Flags reference

| Flag | Effect |
|------|--------|
| `--keep` | Never stop the container (success or failure) |
| `--retain-logs` | After **success**, keep `/tmp/manifold-api-pico-test-*` on disk |
| `--skip-docker` | Skip container start/stop; run parse (and any non-Docker scenarios) only |
| `--skip-parse` | Skip `krl-compiler` verification |
| `--config <path>` | Use a different config file instead of `t/config.json` |

Environment:

| Variable | Effect |
|----------|--------|
| `PICO_ENGINE_IMAGE` | Overrides `dockerImage` in `t/config.json` |

## Inspecting a failed run

When any scenario throws, teardown **leaves the container running** and prints:

- Container name and ID
- Base URL (engine UI and HTTP API)
- Path to pico engine home on the host

**Runtime state** is saved in `t/.runtime.json` (gitignored):

```json
{
  "containerName": "manifold-api-pico-test-a1b2c3d4",
  "hostPort": 5847,
  "baseUrl": "http://localhost:5847",
  "picoEngineHome": "/tmp/manifold-api-pico-test-a1b2c3d4",
  "mounts": [ ... ]
}
```

Useful next steps:

1. Open **http://localhost:&lt;hostPort&gt;** — pico-engine developer UI.
2. Read the engine log: `$PICO_ENGINE_HOME/pico-engine.log` (on the host path from `.runtime.json`).
3. `docker logs manifold-api-pico-test-...`
4. When done: `docker rm -f <containerName>` and optionally `rm -rf <picoEngineHome>`.

After a **successful** run, the container and pico home are removed by default (unless
`--retain-logs` or `--keep`).

### Bulk cleanup (`npm run test:cleanup`)

After `test:keep` or a failed run, remove **all** test resources for this repo:

```bash
npm run test:cleanup              # stop containers + delete /tmp/...-pico-test-* dirs
npm run test:cleanup -- --dry-run # preview only
```

**How resources are identified:**

| Resource | Pattern |
|----------|---------|
| Container name | `<repoName>-pico-test-<runId>` (e.g. `manifold-api-pico-test-a1b2c3d4`) |
| Docker labels | `io.picolabs.test=1`, `io.picolabs.test.repo=<repoName>` |
| Pico home on host | `/tmp/<repoName>-pico-test-<runId>` |

Cleanup finds containers by label and name prefix, and scans `/tmp` for matching home
directories (including orphans where the container was removed manually). Clears
`t/.runtime.json` if it references a removed resource.

## Configuration (`t/config.json`)

```json
{
  "repoName": "manifold-api",
  "dockerImage": "picolabs/pico-engine:latest",
  "mounts": [
    {
      "name": "manifold-api",
      "hostPath": ".",
      "containerPath": "/var/manifold-api",
      "parseExclude": ["OLD/**", "fix/**"]
    }
  ],
  "dependsOn": []
}
```

| Field | Meaning |
|-------|---------|
| `repoName` | Used in container name and `/tmp/<repoName>-pico-test-*` paths |
| `dockerImage` | Docker image to run (overridable via `PICO_ENGINE_IMAGE`) |
| `mounts[].hostPath` | Directory on the host, relative to repo root |
| `mounts[].containerPath` | Mount point inside the container (e.g. `/var/manifold-api`) |
| `mounts[].parseExclude` | [minimatch](https://github.com/isaacs/minimatch) patterns, relative to mount root, skipped during parse |
| `dependsOn` | Other repos to mount (for `temperature-network/t` later) |

Rulesets installed during tests should use **file URLs** inside the container, e.g.:

```
file:///var/manifold-api/io.picolabs.manifold_pico.krl
```

Helper: `toFileRulesetUrl()` in `t/lib/config.ts`.

## Parse gate

Before Docker starts, every `*.krl` file under each mount is verified with
[`krl-compiler --verify`](https://picolabs.atlassian.net/wiki/spaces/docs/pages/31544297/Developer+Tips+for+Pico+Engine#Parsing-KRL)
(same tool the engine uses). This catches syntax and compile errors early.

- Walks all subdirectories under each mount root.
- Skips paths matching `parseExclude` (e.g. `OLD/**`, `fix/**`).
- A single failure aborts the run with file path and error message.

To exclude a file temporarily while it is under review, add a pattern to `parseExclude`:

```json
"parseExclude": ["OLD/**", "fix/**", "io.picolabs.alexa.krl"]
```

Prefer fixing the ruleset over excluding it.

## Writing scenarios

Scenarios live in `t/scenarios/` and use Node's built-in test runner (`node:test`):
`describe` groups related checks; `it` defines one test with a clear name in the
report output. Shared fixtures (`RuntimeState`, bootstrap context) come from
`t/lib/test-context.ts`, populated by `t/run.ts` before scenario modules load.

Example:

```typescript
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getTestState } from "../lib/test-context.js";

describe("health", () => {
  it("engine is reachable over HTTP", async () => {
    const state = getTestState();
    const resp = await fetch(state.baseUrl);
    assert.ok(resp.ok || resp.status === 404);
  });
});
```

Import new scenario modules from `t/run.ts` after any required setup (e.g. bootstrap
install). Tests run sequentially (`concurrency: 1`) so shared state in a `describe`
block remains valid.

On Node 20+, the built-in `spec` reporter is used. On Node 18, `t/lib/run-tests.ts`
falls back to a simple custom reporter (you may also see TAP output from the runner).

### HTTP helpers (`t/lib/engine.ts`)

Use these to interact with the engine during scenarios:

```typescript
import { query, signal, waitFor } from "../lib/engine.js";

// Query a pico
const communities = await query(state, manifoldEci, "io.picolabs.manifold_pico", "getCommunities");

// Send an event
await signal(state, manifoldEci, "manifold", "new_community", { name: "Test" });

// Poll until a condition is true (subscriptions, child picos, etc.)
await waitFor(
  async () => {
    const subs = await query(state, communityEci, "io.picolabs.community", "things");
    return subs.length > 0 ? subs : null;
  },
  { timeoutMs: 30_000, label: "community thing subscription" }
);
```

Event URL shape: `POST {baseUrl}/sky/event/{eci}/{eid}/{domain}/{type}` with JSON attrs.

Query URL shape: `GET {baseUrl}/c/{eci}/query/{rid}/{name}?arg=...`

## Test mode and KRL (`TESTING=1`)

The container sets **`TESTING=1`** for setup scripts. KRL rulesets **cannot read process
environment variables** directly.

To make rulesets test-aware:

- Pass **`config: { "testing": true }`** when installing a ruleset; read
  `meta:rulesetConfig{"testing"}` in KRL, or
- Install a **test-only ruleset** (e.g. open channel policies, scenario conductor) during setup
  only.

Planned: setup will install test helpers when bootstrap scenarios land (Phase 2).

## Directory layout

```
t/
  README.md          ← this file
  config.json        ← mounts, image, parse excludes
  run.ts             ← orchestrator (parse → setup → scenarios → teardown)
  parse.ts           ← parse-only entry point
  setup.ts           ← start Docker, write .runtime.json
  teardown.ts        ← per-run stop/remove; retention policy
  cleanup.ts         ← remove all leftover test containers and pico homes
  .runtime.json      ← gitignored; last run connection info
  lib/
    config.ts        ← load config, repo paths, file:// URLs
    docker.ts        ← container lifecycle, port pick, health wait
    bootstrap.ts     ← install bootstrap, wait for init, resolve UI ECIs
    manifold.ts        ← create thing/community, subscriptions, teardown helpers
    assert.ts        ← test helpers (assert, assertIncludes)
    test-context.ts  ← shared fixtures (state, bootstrap) for scenario modules
    run-tests.ts     ← node:test runner with spec reporter
    expected-rulesets.ts ← expected app rulesets per bootstrap pico
    parse-krl.ts     ← walk mounts, krl-compiler --verify
    engine.ts        ← signal, query, waitFor
    cli.ts           ← flag parsing
    runtime.ts       ← read/write .runtime.json
    types.ts
  scenarios/
    health.test.ts         ← engine reachable
    bootstrap.test.ts      ← Manifold bootstrap (4 separate checks)
    thing-community.test.ts ← thing + community lifecycle
```

### Bootstrap scenarios (`bootstrap.test.ts`)

Installs `io.picolabs.manifold_bootstrap` on the root pico, waits for init, then runs
four separate tests:

| Test | Verifies |
|------|----------|
| `testTagRegistryPico` | "Tag Registry" child; `io.picolabs.new_tag_registry`; registration ECI in bootstrap status |
| `testSkillsRegistryPico` | "Skills Registry" child; `io.picolabs.manifold.skills_registry` |
| `testOwnerPico` | "Owner" child; `io.picolabs.profile` + `io.picolabs.manifold_owner` |
| `testManifoldPico` | "Manifold" child under owner; `io.picolabs.manifold_pico` plus init rulesets (`notifications`, `twilio.sms`, `prowl`) |

Picos are found by **UI channel ECI** (`pico-engine-ui/pico` + `name`). Rulesets are
read from `pico-engine-ui/pico` → `rulesets`. Family-channel ECIs in
`getBootstrapStatus` are not HTTP-queryable from the test runner.

### Thing / community scenarios (`thing-community.test.ts`)

After bootstrap, exercises the full Manifold thing and community lifecycle:

| Test | Verifies |
|------|----------|
| `testCreateThingPico` | `manifold create_thing`; `io.picolabs.thing` + `io.picolabs.safeandmine`; Manifold↔thing subscription |
| `testCreateCommunityPico` | `manifold new_community`; `io.picolabs.community`; name + description; Manifold↔community subscription |
| `testAddThingToCommunity` | `manifold add_thing_to_community`; community↔thing subscription on both sides |
| `testRemoveThingFromCommunity` | `manifold remove_thing_from_community`; membership subscription removed; picos remain |
| `testDeleteCommunityAndThing` | `manifold remove_community` / `remove_thing`; child picos and Manifold subscriptions gone |

Manifold queries (`getThings`, `getCommunities`) use the **Manifold app channel** (tag
`manifold`), not the UI channel. Thing/community membership queries use each pico's
Manifold subscription `Tx` channel.

## Roadmap

| Phase | Status | Content |
|-------|--------|---------|
| 1 | Done | Docker harness, parse gate, health scenario, teardown policy |
| 2 | Done | Manifold bootstrap scenarios (tag registry, skills, owner, manifold) |
| 3 | In progress | Thing/community scenarios done; `temperature-network/t` with `dependsOn` planned |
| 4 | Planned | Test RS / open channels for async multi-pico flows |

## Troubleshooting

| Problem | Likely cause | What to do |
|---------|----------------|------------|
| `docker run failed` | No image / wrong name | `docker images`; set `PICO_ENGINE_IMAGE` |
| Parse errors | Invalid KRL | Fix file or add to `parseExclude` temporarily |
| `Engine not ready` | Slow start / port conflict | Re-run; check `docker logs` |
| Tests pass but manual engine differs | Stale compiled rulesets in an old dotfile | Test uses fresh `/tmp/...-pico-test-*` each run |
| Container left running | Failed scenario or `--keep` | `npm run test:cleanup` or read `t/.runtime.json` |

## Related docs

- [Developer Tips for Pico Engine — Parsing KRL](https://picolabs.atlassian.net/wiki/spaces/docs/pages/31544297/Developer+Tips+for+Pico+Engine#Parsing-KRL)
- [Pico Engine Docker notes](https://picolabs.atlassian.net/wiki/spaces/docs/pages/31544297/Developer+Tips+for+Pico+Engine#Using-Docker) (same Confluence page)
- Repo root `MEMORY.md` — migration status and harness decisions
