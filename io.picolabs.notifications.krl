ruleset io.picolabs.notifications {
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares getNotifications, getBadgeNumber, getState, getSettings
  }
  global {
    // Canonical notification delivery channels. Case matters: these are the exact
    // keys used in ent:notification_settings{picoId}{<channel>} and gated in
    // addNotification. Any externally-supplied channel name is validated against
    // this list.
    channels = [
      "Manifold", // record in the in-app inbox (ent:notifications) + badge count
      "SMS",      // send an SMS via the owner's Twilio account (io.picolabs.twilio.sms)
      "Prowl"     // send a push notification via the owner's Prowl account (io.picolabs.prowl)
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

    getNotifications = function () {
      ent:notifications.defaultsTo([]).reverse();
    }

    getBadgeNumber = function () {
      ent:notifications.length()
    }

    getState = function (id) {
      ent:notification_state{id};
    }

    getSettings = function(id) {
      ent:notification_settings{id}
    }
  }

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
      to_phone = sms_on => wrangler:picoQuery(wrangler:parent_eci(),
                                             "io.picolabs.profile",
                                             "getOwnerPhone")
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
        if isEnabled(picoId, "Prowl")
    }
  }

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
