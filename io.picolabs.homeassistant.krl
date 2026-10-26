ruleset io.picolabs.homeassistant {
  meta {
    name "Home Assistant Module"
    description <<
      Delivers Manifold notifications to a Home Assistant integration via a
      dedicated channel on the Manifold pico. On install this ruleset creates
      a channel tagged "homeassistant" and forwards enabled notifications to it.
    >>
    author "Pico Labs"

    use module io.picolabs.wrangler alias wrangler

    shares homeassistantChannel, getPendingNotifications
  }

  global {
    channelTag = "homeassistant"

    // Keep only the most recent notifications for the integration to read.
    pendingLimit = 100

    haEventPolicy = {
      "allow": [
        {"domain": "homeassistant", "name": "notification"}
      ],
      "deny": []
    }

    haQueryPolicy = {
      "allow": [
        {"rid": "io.picolabs.homeassistant", "name": "homeassistantChannel"},
        {"rid": "io.picolabs.homeassistant", "name": "getPendingNotifications"}
      ],
      "deny": []
    }

    /**
     * The channel the Home Assistant integration uses: tagged exactly
     * "homeassistant". Null until this ruleset is installed (or ensure_channel).
     * @returns Map "the channel, including its id"
     */
    homeassistantChannel = function() {
      wrangler:channels([channelTag]).filter(function(c) {
        c{"tags"}.length() == 1
      }).head()
    }

    /**
     * The most recent notifications delivered to Home Assistant (up to 100), newest
     * first, for the integration to read. Each is the full notification map (thing,
     * picoId, app, message, ruleset, id, time, …).
     * @returns Array
     */
    getPendingNotifications = function() {
      ent:pending.defaultsTo([]).reverse()
    }
  }

  rule create_homeassistant_channel {
    select when wrangler ruleset_installed
      where event:attr("rids") >< meta:rid

    pre {
      existing = homeassistantChannel()
    }

    if existing.isnull() then
      wrangler:createChannel(
        [channelTag],
        haEventPolicy,
        haQueryPolicy
      ) setting(channel)

    fired {
      ent:channel_eci := channel{"id"}
    }
  }

  /**
   * Create the Home Assistant channel if it's missing (normally created on install).
   */
  rule ensure_homeassistant_channel {
    select when homeassistant ensure_channel

    pre {
      existing = homeassistantChannel()
    }

    if existing.isnull() then
      wrangler:createChannel(
        [channelTag],
        haEventPolicy,
        haQueryPolicy
      ) setting(channel)

    fired {
      ent:channel_eci := channel{"id"}
    }
  }

  rule receive_notification {
    select when homeassistant notification

    pre {
      pending = ent:pending.defaultsTo([]).append(event:attrs)
      n = pending.length()
    }

    always {
      ent:pending := n > pendingLimit => pending.slice(n - pendingLimit, n - 1) | pending
    }
  }

  // Manifold "HomeAssistant" notification channel. The notifications orchestrator
  // raises this with the full notification map (thing, picoId, app, message,
  // ruleset, id, time, ...).
  rule notify_through_homeassistant {
    select when homeassistant notify_through_homeassistant

    pre {
      channel = homeassistantChannel();
      toSend = channel{"id"};
    }

    if toSend then
      event:send({
        "eci": toSend,
        "domain": "homeassistant",
        "name": "notification",
        "attrs": event:attrs
      });

    fired {
      log info <<Home Assistant notification sent to channel #{toSend}>>
    }
  }
}
