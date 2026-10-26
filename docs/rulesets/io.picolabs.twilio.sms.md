# io.picolabs.twilio.sms

Utility methods for sending SMS with Twilio, plus the Manifold "SMS" notification  
channel. Configured ONCE per Manifold pico (the owner's Twilio account); the  
recipient is supplied per-send by the notifications orchestrator.

*Version 0.2.0. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [twilio:configuration](#twilioconfiguration)  

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `twilio:configuration`

Configure the Manifold-wide Twilio account used for SMS notifications. Ignored unless all three values are given.

**Send:** `twilio:configuration`  
**Rule:** `save_config`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `twilio_account_sid` | String | yes |  |
| `twilio_auth_token` | String | yes |  |
| `twilio_from_number` | String | yes | the Twilio number, E.164 format (+1…) |

**Acts when:** `not auth_token.isnull() || account_sid.isnull() || from_number.isnull()`

<details><summary>Select expression</summary>

```krl
select when twilio configuration
```

</details>
