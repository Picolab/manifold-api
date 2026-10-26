# io.picolabs.safeandmine

Electronic name tag for a Manifold thing. Register QR or NFC tags on the  
thing, set owner contact information, and let finders scan a tag to see  
how to return the item. You receive a notification when a tag is scanned.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [safeandmine:update](#safeandmineupdate) · [safeandmine:delete](#safeandminedelete) · [safeandmine:new_tag](#safeandminenew_tag) · [safeandmine:deregister](#safeandminederegister) · [safeandmine:notify](#safeandminenotify)  
**Queries:** [getInformation](#getinformationinfo--any) · [getTags](#gettags--map)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `safeandmine:update`

Set the owner contact information shown when this thing's tag is scanned. Send only the fields to change. name, email, and phone are cut to 100 characters, message to 250. The share flags say which fields a finder sees.

**Send:** `safeandmine:update`  
**Rule:** `information_update`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | no |  |
| `email` | String | no |  |
| `phone` | String | no |  |
| `message` | String | no | shown to the finder |
| `shareName` | Boolean | no |  |
| `sharePhone` | Boolean | no |  |
| `shareEmail` | Boolean | no |  |

**Examples:**

- **contact:** `{"name":"<name>","phone":"<phone>","message":"Please call if found","shareName":true,"sharePhone":true}`

**Acts when:** always, once selected

**May emit** (possible, not guaranteed):

- raises `pds:new_data_available` on this pico — always

<details><summary>Select expression</summary>

```krl
select when safeandmine update
```

</details>

### `safeandmine:delete`

Remove one contact field, or all contact information if toDelete is omitted.

**Send:** `safeandmine:delete`  
**Rule:** `information_delete`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `toDelete` | String | no | field to remove |

**Examples:**

- **one field:** `{"toDelete":"phone"}`
- **everything:** `{}`

**Acts when:** `toDelete`

**May emit** (possible, not guaranteed):

- raises `pds:new_data_available` on this pico — when it acts
- raises `pds:remove_old_data` on this pico — when it doesn't act

<details><summary>Select expression</summary>

```krl
select when safeandmine delete
```

</details>

### `safeandmine:new_tag`

Register a QR or NFC tag on this thing. Creates a channel for the tag and registers it with the mesh's tag registry; the tag appears in getTags() once the registry confirms. Tag IDs are stored in upper case.

**Send:** `safeandmine:new_tag`  
**Rule:** `new_tag`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `tagID` | String | yes |  |
| `domain` | String | yes | tag domain, e.g. qr or nfc |
| `pico_host` | String | no | this engine's public URL, if the registry is elsewhere |

**Examples:**

- **QR tag:** `{"tagID":"<tag id>","domain":"qr"}`

**Acts when:** `tagID.length() > 0`

**May emit** (possible, not guaranteed):

- raises `safeandmine:new_tag_channel` on this pico — when it acts

**Other rules on the same event:**

- `check_tag_registry` — acts when `eci.isnull()`

<details><summary>Select expression</summary>

```krl
select when safeandmine new_tag
```

</details>

### `safeandmine:deregister`

Remove a tag from this thing and from the tag registry.

**Send:** `safeandmine:deregister`  
**Rule:** `deregister_tag`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `tagID` | String | yes |  |
| `domain` | String | yes |  |

**Acts when:** `tagToDelete && domain && registry_eci`

**May emit** (possible, not guaranteed):

- sends `?` to `registry_eci`

**Other rules on the same event:**

- `deregister_tag_cleanup` — acts when `tagToDelete && channelToDelete`

<details><summary>Select expression</summary>

```krl
select when safeandmine deregister
```

</details>

### `safeandmine:notify`

A tag on this thing was scanned: notify the owner through Manifold (manifold:add_notification), with the thing's name and "Your tag … has been scanned". Sent by the scan flow on the tag's channel.

**Send:** `safeandmine:notify`  
**Rule:** `notify`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `tagID` | String | yes | the scanned tag |

**Acts when:** `tagID && picoId && app && rid && name && message && toSend`

**May emit** (possible, not guaranteed):

- sends `manifold:add_notification` to `toSend`

<details><summary>Select expression</summary>

```krl
select when safeandmine notify
```

</details>

## Queries

### `getInformation(info?)` → Any

The owner contact information shown to someone who scans this thing's tag: name, email, phone, message, and shareName / sharePhone / shareEmail flags. With info, just that field.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `info` | String | no |  | one field; omit for all |

**Examples:**

- **all:** `{}`
- **message:** `{"info":"message"}`

**Call:** `GET /sky/query/<eci>/io.picolabs.safeandmine/getInformation?info=…`, or `<alias>:getInformation(info?)` from KRL with `use module io.picolabs.safeandmine alias <alias>`

### `getTags()` → Map

Tags registered on this thing: tag IDs by domain.

**Call:** `GET /sky/query/<eci>/io.picolabs.safeandmine/getTags`, or `<alias>:getTags()` from KRL with `use module io.picolabs.safeandmine alias <alias>`
