# Manifold KRL Rulesets

**⚠️ Version 1.0 Pico Engine Update**

This directory contains updated KRL (Kynetx Rules Language) rulesets for the Manifold application, updated for compatibility with **Pico Engine version 1.0**. These rulesets define the behavior of Pico devices in the Manifold ecosystem.

## Updated Files (v1.0 Compatible)

The following files have been reviewed and updated for Pico Engine 1.0 compatibility:

- ✅ **`io.picolabs.manifold_owner.krl`** - Updated to use modern Wrangler API:
  - Removed deprecated `rids` attribute from `new_child_request`
  - Updated to use `install_ruleset_request` (singular) with `absoluteURL` attribute
  - Updated channel creation to use modern Wrangler patterns
  - Uses `meta:rulesetURI` for absolute URL derivation
  - Updated to set pico name to "owner" during initialization

- ✅ **`io.picolabs.manifold_pico.krl`** - Updated to use modern Wrangler API:
  - Added `initializationRids` array for self-contained initialization
  - Updated initialization rule to use `foreach` with `install_ruleset_request` (singular)
  - Updated channel creation to use synchronous `wrangler:createChannel()` action
  - Uses `meta:rulesetURI` for absolute URL derivation
  - Fixed event attribute references (`rid` instead of `rids`)

- ✅ **`io.picolabs.profile.krl`** - Updated for Pico Engine 1.0 compatibility

- ✅ **`io.picolabs.thing.krl`** - Updated for Pico Engine 1.0 compatibility

- ✅ **`io.picolabs.safeandmine.krl`** - Partially updated for Pico Engine 1.0 compatibility. Tags are not yet working.

- ✅ **`io.picolabs.new_tag_registry.krl`** - Refactored for Pico Engine version 1.0 compatibility.

## Files Pending Review

The following files have **not yet** been reviewed for Pico Engine 1.0 compatibility and may need updates:
- ⚠️ `io.picolabs.community.krl`
- ⚠️ `io.picolabs.collection.krl`
- ⚠️ `io.picolabs.notifications.krl`
- ⚠️ `io.picolabs.prowl_notifications.krl`
- ⚠️ `io.picolabs.twilio_notifications.krl`
- ⚠️ `io.picolabs.manifold.email_notifications.krl`
- ⚠️ `io.picolabs.manifold.text_message_notifications`
- ⚠️ `io.picolabs.manifold.text_messenger.krl`
- ⚠️ `io.picolabs.manifold.pico_mailer.krl`
- ⚠️ `io.picolabs.manifold.smart_mirror.krl`
- ⚠️ `io.picolabs.manifold.disk_space_monitor.krl`
- ⚠️ `io.picolabs.google_signin.krl`
- ⚠️ `io.picolabs.github_signin.krl`
- ⚠️ `io.picolabs.alexa.krl`
- ⚠️ `io.picolabs.google_assistant.krl`
- ⚠️ `io.picolabs.weather.krl`
- ⚠️ `io.picolabs.community_thing.krl`
- ⚠️ `io.picolabs.manifold_import.krl`
- ⚠️ `org.sovrin.manifold_cloud_agent.krl`
- ⚠️ `aurora_api.krl`
- ⚠️ `io.github.picolab.manifold_disk.krl`
- ⚠️ `io.picolabs.neighborhood_temps`
- ⚠️ `io.picolabs.wovyn_base`

---

This directory contains the KRL (Kynetx Rules Language) rulesets used by the Manifold application. These rulesets define the behavior of Pico devices in the Manifold ecosystem.

## Bootstrap Process

### Bootstrap Architecture (Three-Part Initialization)

1. **Tag registry pico** — Create a tag registry pico as a child of the **root pico**, and install the `io.picolabs.new_tag_registry` ruleset in it. This should create a channel called `registration`.

2. **Owner pico** — Create a pico to represent the owner as a child of the **root pico**, and install the `io.picolabs.manifold_owner` ruleset in it. Installing `manifold_owner` in the owner pico initializes Manifold (creates an initialization channel, creates the Manifold child pico, etc.).

3. **Tag server registration** — The tag registry's `registration` ECI must be stored in the owner pico by raising the `manifold:new_tag_server` event to the owner pico **before any things are created**. This initializes the tag server reference so the owner (and Manifold) can use the tag registry.

### Primary Ruleset: `io.picolabs.manifold_owner`

**`io.picolabs.manifold_owner`** is the primary entry point for bootstrapping a new Manifold instance. This ruleset is installed on the **owner pico**, which is a child of the root pico (not on the root pico itself).

### Step-by-Step Bootstrap

1. **Root pico setup**: On the root pico, create two child picos and install rulesets:
   - Create a **tag registry** child pico and install `io.picolabs.new_tag_registry` in it.
   - Create an **owner** child pico and install `io.picolabs.profile` and `io.picolabs.manifold_owner` in it.

2. **Owner/Manifold initialization**: When `io.picolabs.manifold_owner` is installed on the owner pico, its `initialization` rule:
   - Sets the owner pico name to "owner"
   - Checks if a "Manifold" child pico already exists
   - If not, creates a new child pico named "Manifold" (with no initial rulesets)

3. **Manifold child setup**: After the Manifold child is created, the `install_manifold_pico_ruleset` rule:
   - Installs `io.picolabs.manifold_pico` on the Manifold child
   - Uses `meta:rulesetURI` to derive the absolute URL for ruleset installation

4. **Manifold pico self-initialization**: When `io.picolabs.manifold_pico` is installed, its `initialization` rule:
   - Installs all required rulesets from `initializationRids` array
   - Creates the "Manifold" App channel if it doesn't exist

5. **Tag server registration (required before creating things)**: Raise `manifold:new_tag_server` with the tag registry's `registration` ECI so it is stored in the owner pico. This must be done **before any things are created**.

### Bootstrap Flow (v1.0)

```
Root Pico
  │
  ├─ Create Child: Tag Registry Pico
  │   └─ Install: io.picolabs.new_tag_registry
  │
  └─ Create Child: Owner Pico
       ├─ Install: io.picolabs.profile
       └─ Install: io.picolabs.manifold_owner
            │
            │ (initialization rule fires)
            │
            ├─ Sets pico name to "owner"
            │
            └─ Creates Child: "Manifold" (empty, no rulesets)
                 │
                 │ (install_manifold_pico_ruleset rule fires)
                 │
                 └─ Installs: io.picolabs.manifold_pico
                      │
                      │ (manifold_pico initialization rule fires)
                      │
                      └─ Self-installs & creates "Manifold" App channel

Before creating any things:
  └─ Raise manifold:new_tag_server with registry's registration ECI
     (stores it in owner pico for tag registry access)
```

## Dependencies

### Owner Pico Dependencies
The `io.picolabs.manifold_owner` ruleset requires:
- `io.picolabs.wrangler` (standard pico engine module - for pico management)
- `io.picolabs.subscription` (standard pico engine module - for subscriptions)
- `io.picolabs.profile` (for owner profile management - typically installed with signin rulesets)

### Manifold Pico Dependencies
The `io.picolabs.manifold_pico` ruleset requires:
- `io.picolabs.wrangler` (standard pico engine module)
- `io.picolabs.subscription` (standard pico engine module)

### Standard Pico Engine Modules
These are provided by the pico engine and don't need to be installed separately:
- `io.picolabs.wrangler` - Core pico management
- `io.picolabs.subscription` - Subscription management

## Quick Start Guide

### Option 1: Manual Installation (via pico engine UI)

1. Start your pico engine and use your **root pico** as the top-level parent.
2. **Tag registry**: Create a child pico (e.g. "Tag Registry") and install `io.picolabs.new_tag_registry` in it.
3. **Owner**: Create a child pico (e.g. "Owner") and install in order:
   ```
   io.picolabs.profile
   io.picolabs.manifold_owner
   ```
4. The Manifold child pico will be created automatically under the owner pico.
5. **Before creating any things**: Raise `manifold:new_tag_server` on the owner pico with the tag registry's `registration` ECI so it is stored for tag registry access.

### Option 2: Programmatic Installation (via API)

Create a tag registry child and an owner child under the root pico, install rulesets on each, then raise `manifold:new_tag_server` on the owner with the registry's `registration` ECI before creating any things. Use wrangler events to create children and `install_ruleset_request` with `absoluteURL` for ruleset installation.

### Option 3: Using KRL Developer UI

1. Register the rulesets in your pico engine.
2. From the **root pico**: create a tag registry child pico and install `io.picolabs.new_tag_registry`; create an owner child pico and install `io.picolabs.profile` and `io.picolabs.manifold_owner`.
3. The initialization rule on the owner pico will automatically create the Manifold child pico.
4. Raise `manifold:new_tag_server` on the owner pico with the tag registry's `registration` ECI before creating any things.

## Ruleset Architecture

### Core Rulesets

- **`io.picolabs.manifold_owner`** - Owner/root pico ruleset that manages the Manifold child pico
- **`io.picolabs.manifold_pico`** - Core Manifold functionality (thing/community management)
- **`io.picolabs.thing`** - Base ruleset for "things" (installed on thing child picos)
- **`io.picolabs.community`** - Base ruleset for "communities" (installed on community child picos)
- **`io.picolabs.profile`** - User profile management

### Notification Rulesets

- **`io.picolabs.notifications`** - Core notification system
- **`io.picolabs.prowl_notifications`** - Prowl push notifications
- **`io.picolabs.twilio_notifications`** - Twilio SMS notifications
- **`io.picolabs.manifold.email_notifications`** - Email notifications
- **`io.picolabs.manifold.text_message_notifications`** - Text message notifications

### Integration Rulesets

- **`io.picolabs.google_signin`** - Google OAuth sign-in
- **`io.picolabs.github_signin`** - GitHub OAuth sign-in
- **`io.picolabs.alexa`** - Amazon Alexa integration
- **`io.picolabs.google_assistant`** - Google Assistant integration

### Application Rulesets

- **`io.picolabs.weather`** - Weather app
- **`io.picolabs.manifold.smart_mirror`** - Smart mirror app
- **`org.sovrin.manifold_cloud_agent`** - Sovrin cloud agent
- And many more...

## Manifold Pico Initialization Details

### Entity Variable Initialization

The `io.picolabs.manifold_pico` ruleset uses **lazy initialization** for entity variables:

- `ent:things` - Initialized as empty map `{}` on first access using `.defaultsTo({})`
- `ent:communities` - Initialized as empty map `{}` on first access using `.defaultsTo({})`

No explicit initialization rule is needed - variables are ready when first accessed.

### Subscription Auto-Accept

The `autoAcceptSubscriptions` rule automatically accepts subscriptions with `Tx_Rx_Type == "Manifold"`:

```krl
rule autoAcceptSubscriptions {
  select when wrangler inbound_pending_subscription_added
    where event:attr("rs_attrs"){"Tx_Rx_Type"} == "Manifold"
  always {
    raise wrangler event "pending_subscription_approval" 
      attributes event:attrs;
  }
}
```

### Post-Initialization State

After initialization, the Manifold pico:
- ✅ Has all required rulesets installed
- ✅ Has `ent:things` and `ent:communities` ready (empty maps, initialized on first access)
- ✅ Has "Manifold" App channel created
- ✅ Can accept subscriptions automatically
- ✅ Can create things and communities
- ✅ Is ready to receive events and queries

## Testing the Bootstrap

After installation, you can verify the bootstrap worked:

1. **Check for Manifold child pico**:
   ```javascript
   GET /sky/cloud/{owner_eci}/io.picolabs.manifold_owner/getManifoldPico
   ```
   Expected: A pico object with the Manifold child pico details

2. **Get Manifold info**:
   ```javascript
   GET /sky/cloud/{manifold_eci}/io.picolabs.manifold_pico/getManifoldInfo
   ```
   Expected: `{"things": {}, "communities": {}}`

3. **Check installed rulesets**:
   ```javascript
   GET /sky/cloud/{manifold_eci}/io.picolabs.wrangler/installedRulesets
   ```
   Should include:
   - `io.picolabs.manifold_pico`
   - `io.picolabs.notifications`
   - `io.picolabs.prowl_notifications`
   - `io.picolabs.twilio_notifications`

4. **Verify App channel exists**:
   The "Manifold" App channel should be automatically created during initialization

## Running Independently of GUI

To run these rulesets independently of the React GUI:

1. **Install on a pico engine**: These rulesets can run on any pico engine instance
2. **No GUI dependencies**: The rulesets are self-contained and don't require the React application
3. **API access**: Access functionality via:
   - Sky Cloud queries: `GET /sky/cloud/{eci}/{ruleset}/{function}`
   - Sky Events: `POST /sky/event/{eci}/{eid}/{domain}/{type}`
   - EXP API (when implemented): `GET /exp/{eci}`

## File Structure

- All rulesets use the `.krl` extension
- Ruleset IDs match the filename (e.g., `io.picolabs.manifold_owner.krl` has RID `io.picolabs.manifold_owner`)
- Some rulesets have no extension (legacy format) but are still valid KRL

## Contributing

When contributing KRL rulesets, please ensure:
- Rulesets follow KRL best practices
- Rulesets are properly documented
- Rulesets are tested before submission
- Dependencies are clearly stated in the meta section

For more information about KRL and Pico Labs, visit [PicoLabs.io](http://picolabs.io).
