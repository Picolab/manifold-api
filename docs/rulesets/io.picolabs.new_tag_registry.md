# io.picolabs.new_tag_registry

Maps NFC/QR tags to the thing picos they identify, per tag domain, with a  
redirect URL for scans. Installed on the Tag Registry pico by bootstrap; things  
register tags through SafeAndMine.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [safeandmine:register_tag](#safeandmineregister_tag) · [safeandmine:deregister_tag](#safeandminederegister_tag) · [safeandmine:redirect](#safeandmineredirect)  
**Queries:** [get_tag_store](#get_tag_store--map) · [scan_tag](#scan_tagtagid-domain--map)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `safeandmine:register_tag`

Register a tag to a thing, unless the tag is already registered in that domain. The thing is told with safeandmine:tag_register_response on DID.

**Send:** `safeandmine:register_tag`  
**Rule:** `register_tag`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `tagID` | String | yes |  |
| `domain` | String | yes | tag domain, e.g. qr or nfc |
| `DID` | String | yes | the thing's channel for the response |
| `redirect_url` | String | no | where scans go (default: the SafeAndMine app) |
| `pico_host` | String | no | the thing's engine URL |

**Acts when:** `tagID && domain && did`

**May emit** (possible, not guaranteed):

- sends `?` to `did`

<details><summary>Select expression</summary>

```krl
select when safeandmine register_tag
```

</details>

### `safeandmine:deregister_tag`

Remove a tag's registration.

**Send:** `safeandmine:deregister_tag`  
**Rule:** `deregister_tag`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `tagID` | String | yes |  |
| `domain` | String | yes |  |

**Acts when:** `tagID && domain && isRegistered`

<details><summary>Select expression</summary>

```krl
select when safeandmine deregister_tag
```

</details>

### `safeandmine:redirect`

Look up a scanned tag and answer with a _redirect directive to its redirect URL (or the SafeAndMine app if it isn't registered).

**Send:** `safeandmine:redirect`  
**Rule:** `redirect`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `tagID` | String | yes |  |
| `domain` | String | yes |  |

**Acts when:** always, once selected

<details><summary>Select expression</summary>

```krl
select when safeandmine redirect
```

</details>

## Queries

### `get_tag_store()` → Map

Every registered tag, by domain then tagID.

**Call:** `GET /sky/query/<eci>/io.picolabs.new_tag_registry/get_tag_store`, or `<alias>:get_tag_store()` from KRL with `use module io.picolabs.new_tag_registry alias <alias>`

### `scan_tag(tagID, domain)` → Map

What a tag is registered to: { did, pico_host, redirect_url }, or null.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `tagID` | String | yes |  |  |
| `domain` | String | yes |  | tag domain, e.g. qr or nfc |

**Call:** `GET /sky/query/<eci>/io.picolabs.new_tag_registry/scan_tag?tagID=…&domain=…`, or `<alias>:scan_tag(tagID, domain)` from KRL with `use module io.picolabs.new_tag_registry alias <alias>`
