# io.picolabs.journal

Attach notes to a Manifold thing. Each entry has a title and body text;  
use this to record maintenance history, packing lists, or anything else  
you want to keep with the thing.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [journal:new_entry](#journalnew_entry) · [journal:delete_entry](#journaldelete_entry) · [journal:edit_entry](#journaledit_entry)  
**Queries:** [getEntry](#getentrytitle--any)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `journal:new_entry`

Add a journal entry to this thing. Its timestamp (when it was added) is its id for edit_entry and delete_entry.

**Send:** `journal:new_entry`  
**Rule:** `new_entry`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | String | yes |  |
| `content` | String | yes | the note |

**Examples:**

- **note:** `{"title":"<title>","content":"<text>"}`

**Acts when:** always, once selected

<details><summary>Select expression</summary>

```krl
select when journal new_entry
```

</details>

### `journal:delete_entry`

Delete a journal entry. Does nothing if no entry has that timestamp.

**Send:** `journal:delete_entry`  
**Rule:** `delete_entry`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `timestamp` | String | yes | the entry's timestamp (from getEntry) |

**Acts when:** `toDeleteIndex >= 0`

<details><summary>Select expression</summary>

```krl
select when journal delete_entry
```

</details>

### `journal:edit_entry`

Replace a journal entry's content. Does nothing if no entry has that timestamp.

**Send:** `journal:edit_entry`  
**Rule:** `edit_entry`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `timestamp` | String | yes | the entry's timestamp (from getEntry) |
| `newContent` | String | yes |  |

**Acts when:** `found`

<details><summary>Select expression</summary>

```krl
select when journal edit_entry
```

</details>

## Queries

### `getEntry(title?)` → Any

One journal entry by title, or all entries if no title is given. Each entry has timestamp, title, and content.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `title` | String | no |  | entry title; omit for all |

**Examples:**

- **all:** `{}`
- **one:** `{"title":"<title>"}`

**Call:** `GET /sky/query/<eci>/io.picolabs.journal/getEntry?title=…`, or `<alias>:getEntry(title?)` from KRL with `use module io.picolabs.journal alias <alias>`
