# io.picolabs.prowl

Provide a means of sending prowl notifications to an iPhone, plus the Manifold  
"Prowl" notification channel. Configured ONCE per Manifold pico (the owner's  
Prowl account).

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [prowl:configuration](#prowlconfiguration) · [prowl:test](#prowltest)  

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `prowl:configuration`

Configure the Manifold-wide Prowl account used for push notifications. Ignored unless apikey and providerkey are given.

**Send:** `prowl:configuration`  
**Rule:** `save_config`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `apikey` | String | yes |  |
| `providerkey` | String | yes |  |
| `application` | String | no | shown in Prowl (default Pico Labs) |

**Acts when:** `not apikey.isnull() || providerkey.isnull() || application.isnull()`

<details><summary>Select expression</summary>

```krl
select when prowl configuration
```

</details>

### `prowl:test`

Send a test Prowl notification with the configured account.

**Send:** `prowl:test`  
**Rule:** `test_config`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `msg` | String | no | text to include |

**Examples:**

- **test:** `{"msg":"hello"}`

**Acts when:** always, once selected

**May emit** (possible, not guaranteed):

<details><summary>Select expression</summary>

```krl
select when prowl test
```

</details>
