ruleset io.picolabs.notifications {
  meta {
    name "Manifold notifications"
    description <<
      The notification platform, installed on the Manifold pico. Things,
      communities, and apps raise manifold:add_notification; this ruleset records it
      in the Manifold inbox and fans it out to whichever channels are enabled for the
      subject pico: SMS (io.picolabs.twilio.sms), Prowl (io.picolabs.prowl), and
      Home Assistant (io.picolabs.homeassistant). Channels are opt-in per subject pico.
    >>
    use module io.picolabs.wrangler alias wrangler
    shares getNotifications, getBadgeNumber, getState, getSettings
  }
  global {
    // Canonical notification delivery channels. Case matters: these are the exact
    // keys used in ent:notification_settings{picoId}{<channel>} and gated in
    // addNotification. Any externally-supplied channel name is validated against
    // this list.
    channels = [
      "Manifold",       // record in the in-app inbox (ent:notifications) + badge count
      "SMS",            // send an SMS via the owner's Twilio account (io.picolabs.twilio.sms)
      "Prowl",          // send a push notification via the owner's Prowl account (io.picolabs.prowl)
      "HomeAssistant"   // forward to HA integration channel (io.picolabs.homeassistant)
    ];

    // Default settings for a subject pico, derived from `channels`: the in-app
    // "Manifold" channel starts on, every external channel starts off. Dormant for
    // now (notifications are opt-in); intended for the sensor-network bootstrap RS.
    default_settings = function() {
      channels.reduce(function(acc, channel) {
        acc.put(channel, channel == "Manifold")
      }, {})
    }

    // A channel is active for a subject pico only when explicitly set true.
    isEnabled = function(picoId, channel) {
      ent:notification_settings{picoId}{channel} == true
    }

    /**
     * The Manifold inbox, newest first. Each notification has id, time, and the
     * attrs it was added with (thing, picoId, app, message, ruleset, …).
     * @returns Array
     */
    getNotifications = function () {
      ent:notifications.defaultsTo([]).reverse();
    }

    /**
     * How many notifications are in the inbox.
     * @returns Number
     */
    getBadgeNumber = function () {
      ent:notifications.length()
    }

    /**
     * The state map stored with a notification (its state attr), by notification id.
     * @param id String "notification id"
     * @returns Map
     */
    getState = function (id) {
      ent:notification_state{id};
    }

    /**
     * Which channels are on for a subject pico: { Manifold, SMS, Prowl, HomeAssistant }
     * with true for each one that is on. Null if never set (everything off).
     * @param id String "the subject pico's id"
     * @returns Map
     * @example "one pico" { "id": "<picoId>" }
     */
    getSettings = function(id) {
      ent:notification_settings{id}
    }
  }

  /**
   * Turn one delivery channel on or off for a subject pico (it toggles). Channels:
   * Manifold (the inbox), SMS, Prowl, HomeAssistant. Every channel starts off. An
   * unknown channel name is ignored with a warning.
   * @attr id String "the subject pico's wrangler id"
   * @attr option String "Manifold, SMS, Prowl, or HomeAssistant (case matters)"
   * @example "toggle inbox" { "id": "<picoId>", "option": "Manifold" }
   * @example "toggle SMS" { "id": "<picoId>", "option": "SMS" }
   */
  rule toggleNotificationSetting {
    select when manifold change_notification_setting
    pre {
      id = event:attr("id");
      option = event:attr("option");
      is_valid_channel = channels >< option;
      currently_on = (ent:notification_settings{id}{option} == true);
    }
    if is_valid_channel then noop()
    fired {
      ent:notification_settings := ent:notification_settings.set([id, option], not currently_on);
    }
    else {
      error warn <<ignoring change_notification_setting: unknown channel #{option}>>;
    }
  }

  /**
   * Notify the owner about a subject pico. Recorded in the inbox and sent on each
   * channel that is on for picoId (see change_notification_setting); does nothing
   * on channels that are off. SMS goes to the phone in the owner pico's PDS profile.
   * Domain rulesets should raise this rather than calling Twilio or Prowl directly.
   * @attr picoId String "the subject pico's id (whose channel settings apply)"
   * @attr thing String "subject name shown to the owner"
   * @attr app String "app that raised it"
   * @attr message String "the notification text"
   * @attr ruleset String optional "ruleset that raised it (informational)"
   * @attr state Map optional "app state to keep with the notification (getState)"
   * @example "notify" { "picoId": "<picoId>", "thing": "<name>", "app": "<app>", "message": "<message>" }
   */
  rule addNotification {
    select when manifold add_notification

    pre {
      thing = event:attr("thing");
      picoId = event:attr("picoId");
      app = event:attr("app");
      message = event:attr("message");
      rs = event:attr("ruleset");      // informational only; not used for keying (yet)
      state = event:attr("state").defaultsTo({});

      notificationID = random:uuid();
      time_stamp = time:now();
      notification = event:attrs.put("id", notificationID).put("time", time_stamp);

      // SMS recipient is the owner's phone from the profile on the parent (owner)
      // pico. Only resolved when SMS is actually enabled for this subject.
      sms_on = isEnabled(picoId, "SMS");
      ha_on = isEnabled(picoId, "HomeAssistant");
      to_phone = sms_on => wrangler:picoQuery(wrangler:parent_eci(),
                                             "io.picolabs.pds",
                                             "profile",
                                             "phone"){"profile"}
                         | null;

      // Superset of attrs the delivery channels might need; each channel ruleset
      // reads only the keys it cares about, so one shape serves them all.
      notify_attrs = {"Body": message, "to": to_phone,
                      "application": app, "thing": thing, "id": picoId};
    }

    if (thing && picoId && app && message) then noop();

    // Fan-out is gated per channel via isEnabled against the canonical `channels`,
    // keyed by the subject picoId. External raises stay explicit because KRL
    // requires a static event domain in `raise` (twilio/prowl).
    fired {
      ent:notifications := ent:notifications.defaultsTo([]).append(notification)
        if isEnabled(picoId, "Manifold");
      ent:notification_state := ent:notification_state.defaultsTo({});
      ent:notification_state{notificationID} := state
        if isEnabled(picoId, "Manifold");
      raise twilio event "notify_through_twilio" attributes notify_attrs
        if sms_on;
      raise prowl event "notify_through_prowl" attributes notify_attrs
        if isEnabled(picoId, "Prowl");
      raise homeassistant event "notify_through_homeassistant" attributes notification
        if ha_on
    }
  }

  /**
   * Remove a notification from the inbox.
   * @attr notificationID String "its id"
   */
  rule removeNotification {
    select when manifold remove_notification

    pre {
      id = event:attr("notificationID")
    }

    if id then noop();

    fired {
      ent:notifications := ent:notifications.defaultsTo([]).filter(function(x) {
        (x["id"] != id)
      });
    }
  }
}
