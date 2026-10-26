# io.picolabs.notifications

The notification platform, installed on the Manifold pico. Things,  
communities, and apps raise manifold:add_notification; this ruleset records it  
in the Manifold inbox and fans it out to whichever channels are enabled for the  
subject pico: SMS (io.picolabs.twilio.sms), Prowl (io.picolabs.prowl), and  
Home Assistant (io.picolabs.homeassistant). Channels are opt-in per subject pico.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Operations:** [manifold:change_notification_setting](#manifoldchange_notification_setting) · [manifold:add_notification](#manifoldadd_notification) · [manifold:remove_notification](#manifoldremove_notification)  
**Queries:** [getNotifications](#getnotifications--array) · [getBadgeNumber](#getbadgenumber--number) · [getState](#getstateid--map) · [getSettings](#getsettingsid--map)

## Operations

Events you can send to a pico with this ruleset installed. Whether an operation acts, and what it emits, depends on its condition and the pico's state when the event arrives.

### `manifold:change_notification_setting`

Turn one delivery channel on or off for a subject pico (it toggles). Channels: Manifold (the inbox), SMS, Prowl, HomeAssistant. Every channel starts off. An unknown channel name is ignored with a warning.

**Send:** `manifold:change_notification_setting`  
**Rule:** `toggleNotificationSetting`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | String | yes | the subject pico's wrangler id |
| `option` | String | yes | Manifold, SMS, Prowl, or HomeAssistant (case matters) |

**Examples:**

- **toggle inbox:** `{"id":"<picoId>","option":"Manifold"}`
- **toggle SMS:** `{"id":"<picoId>","option":"SMS"}`

**Acts when:** `is_valid_channel`

<details><summary>Select expression</summary>

```krl
select when manifold change_notification_setting
```

</details>

### `manifold:add_notification`

Notify the owner about a subject pico. Recorded in the inbox and sent on each channel that is on for picoId (see change_notification_setting); does nothing on channels that are off. SMS goes to the phone in the owner pico's PDS profile. Domain rulesets should raise this rather than calling Twilio or Prowl directly.

**Send:** `manifold:add_notification`  
**Rule:** `addNotification`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `picoId` | String | yes | the subject pico's id (whose channel settings apply) |
| `thing` | String | yes | subject name shown to the owner |
| `app` | String | yes | app that raised it |
| `message` | String | yes | the notification text |
| `ruleset` | String | no | ruleset that raised it (informational) |
| `state` | Map | no | app state to keep with the notification (getState) |

**Examples:**

- **notify:** `{"picoId":"<picoId>","thing":"<name>","app":"<app>","message":"<message>"}`

**Acts when:** `thing && picoId && app && message`

**May emit** (possible, not guaranteed):

- raises `twilio:notify_through_twilio` on this pico — when it acts, if `sms_on`
- raises `prowl:notify_through_prowl` on this pico — when it acts, if `isEnabled(picoId, "Prowl")`
- raises `homeassistant:notify_through_homeassistant` on this pico — when it acts, if `ha_on`

<details><summary>Select expression</summary>

```krl
select when manifold add_notification
```

</details>

### `manifold:remove_notification`

Remove a notification from the inbox.

**Send:** `manifold:remove_notification`  
**Rule:** `removeNotification`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `notificationID` | String | yes | its id |

**Acts when:** `id`

<details><summary>Select expression</summary>

```krl
select when manifold remove_notification
```

</details>

## Queries

### `getNotifications()` → Array

The Manifold inbox, newest first. Each notification has id, time, and the attrs it was added with (thing, picoId, app, message, ruleset, …).

**Call:** `GET /sky/query/<eci>/io.picolabs.notifications/getNotifications`, or `<alias>:getNotifications()` from KRL with `use module io.picolabs.notifications alias <alias>`

### `getBadgeNumber()` → Number

How many notifications are in the inbox.

**Call:** `GET /sky/query/<eci>/io.picolabs.notifications/getBadgeNumber`, or `<alias>:getBadgeNumber()` from KRL with `use module io.picolabs.notifications alias <alias>`

### `getState(id)` → Map

The state map stored with a notification (its state attr), by notification id.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | String | yes |  | notification id |

**Call:** `GET /sky/query/<eci>/io.picolabs.notifications/getState?id=…`, or `<alias>:getState(id)` from KRL with `use module io.picolabs.notifications alias <alias>`

### `getSettings(id)` → Map

Which channels are on for a subject pico: { Manifold, SMS, Prowl, HomeAssistant } with true for each one that is on. Null if never set (everything off).

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | String | yes |  | the subject pico's id |

**Examples:**

- **one pico:** `{"id":"<picoId>"}`

**Call:** `GET /sky/query/<eci>/io.picolabs.notifications/getSettings?id=…`, or `<alias>:getSettings(id)` from KRL with `use module io.picolabs.notifications alias <alias>`
