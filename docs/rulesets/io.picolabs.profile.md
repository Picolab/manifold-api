# io.picolabs.profile

The owner's name, email, and phone, on the Owner pico. A thin layer over the  
pico's PDS profile (io.picolabs.pds), kept for Manifold code that reads owner  
contact details; new code can use PDS directly.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [profile:update](#profileupdate) · [profile:clear](#profileclear)  
**Queries:** [getProfile](#getprofile--map) · [getEmail](#getemail--string) · [getPhone](#getphone--string)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `profile:update`

Set the owner's name, email, or phone. Send only the fields to change; empty or missing values are left as they are.

**Send:** `profile:update`  
**Rule:** `update_profile`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | no |  |
| `email` | String | no |  |
| `phone` | String | no | where SMS notifications go |

**Examples:**

- **contact info:** `{"email":"<email>","phone":"<phone>"}`
- **rename:** `{"name":"<name>"}`

**Acts when:** `any_provided`

**May emit** (possible, not guaranteed):

- raises `pds:updated_profile` on this pico — when it acts

<details><summary>Select expression</summary>

```krl
select when profile update
```

</details>

### `profile:clear`

Clear one profile field.

**Send:** `profile:clear`  
**Rule:** `clear_profile_field`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `field` | String | yes | name, email, or phone |

**Examples:**

- **clear phone:** `{"field":"phone"}`

**Acts when:** `field && (profile_fields >< field)`

**May emit** (possible, not guaranteed):

- raises `pds:updated_profile` on this pico — when it acts

<details><summary>Select expression</summary>

```krl
select when profile clear
```

</details>

## Queries

### `getProfile()` → Map

The owner's PDS profile: name, email, phone, and the other PDS profile fields.

**Call:** `GET /sky/query/<eci>/io.picolabs.profile/getProfile`, or `<alias>:getProfile()` from KRL with `use module io.picolabs.profile alias <alias>`

### `getEmail()` → String

The owner's email.

**Call:** `GET /sky/query/<eci>/io.picolabs.profile/getEmail`, or `<alias>:getEmail()` from KRL with `use module io.picolabs.profile alias <alias>`

### `getPhone()` → String

The owner's phone number (where SMS notifications go).

**Call:** `GET /sky/query/<eci>/io.picolabs.profile/getPhone`, or `<alias>:getPhone()` from KRL with `use module io.picolabs.profile alias <alias>`
