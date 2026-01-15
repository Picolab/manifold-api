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

- ✅ **`io.picolabs.safeandmine.krl`** - Updated for Pico Engine 1.0 compatibility

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
- ⚠️ `io.picolabs.new_tag_registry.krl`
- ⚠️ `org.sovrin.manifold_cloud_agent.krl`
- ⚠️ `aurora_api.krl`
- ⚠️ `io.github.picolab.manifold_disk.krl`
- ⚠️ `io.picolabs.neighborhood_temps`
- ⚠️ `io.picolabs.wovyn_base`

---

This directory contains the KRL (Kynetx Rules Language) rulesets used by the Manifold application. These rulesets define the behavior of Pico devices in the Manifold ecosystem.

## Bootstrap Process

### Primary Ruleset: `io.picolabs.manifold_owner`

**`io.picolabs.manifold_owner`** is the primary entry point for bootstrapping a new Manifold instance. This ruleset should be installed on the **owner/root pico**.

### Step-by-Step Bootstrap

1. **Install Core Dependencies** on your root/owner pico:
   - `io.picolabs.profile` - Required for owner profile management
   - `io.picolabs.manifold_owner` - Primary bootstrap ruleset

2. **Automatic Initialization**: When `io.picolabs.manifold_owner` is installed, the `initialization` rule automatically:
   - Sets the owner pico name to "owner"
   - Checks if a "Manifold" child pico already exists
   - If not, creates a new child pico named "Manifold" (with no initial rulesets)

3. **Child Pico Setup**: After the child is created, the `install_manifold_pico_ruleset` rule:
   - Installs `io.picolabs.manifold_pico` on the child pico
   - Uses `meta:rulesetURI` to derive the absolute URL for ruleset installation

4. **Manifold Pico Self-Initialization**: When `io.picolabs.manifold_pico` is installed, its `initialization` rule:
   - Installs all required rulesets from `initializationRids` array:
     - `io.picolabs.manifold_pico` (already installed, skipped)
     - `io.picolabs.notifications`
     - `io.picolabs.prowl_notifications`
     - `io.picolabs.twilio_notifications`
   - Creates the "Manifold" App channel if it doesn't exist

### Bootstrap Flow (v1.0)

```
Root Pico
  │
  ├─ Install: io.picolabs.profile
  │
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
                 └─ Self-installs:
                      ├─ io.picolabs.notifications
                      ├─ io.picolabs.prowl_notifications
                      └─ io.picolabs.twilio_notifications
                 │
                 └─ Creates: "Manifold" App channel
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

1. Start your pico engine
2. Create or select a root/owner pico
3. Install the following rulesets in order:
   ```
   io.picolabs.profile
   io.picolabs.manifold_owner
   ```
4. The Manifold child pico will be automatically created

### Option 2: Programmatic Installation (via API)

```javascript
// Install owner ruleset on root pico (v1.0 - use install_ruleset_request with absoluteURL)
POST /sky/event/{root_eci}/eid/manifold/bootstrap/wrangler/install_ruleset_request
{
  "rid": "io.picolabs.profile",
  "absoluteURL": "https://raw.githubusercontent.com/your-repo/Manifold-api/"
}
// Then install manifold_owner similarly
```

### Option 3: Using KRL Developer UI

1. Register the rulesets in your pico engine
2. Install `io.picolabs.profile` on the root pico
3. Install `io.picolabs.manifold_owner` on the root pico
4. The initialization rule will automatically create the Manifold child pico

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
