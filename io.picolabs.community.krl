ruleset io.picolabs.community {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    shares things, queryThing, sequences, description
  }
  global {

    things = function() {
      subscription:established().filter(function(sub) {
        sub{"Tx_role"} == "thing"
      }).map(function(sub) {
        cached = ent:thingInfo.defaultsTo({}){sub{"Id"}}.defaultsTo({});
        name = cached{"name"} || wrangler:skyQuery(sub{"Tx"}, "io.picolabs.wrangler", "myself"){"name"};
        sub.put(cached).put({"name": name})
      })
    }

    queryThing = function(id, rid, func, params) {
      eci = subscription:established("picoID", id)[0]{"Tx"};
      (eci) => wrangler:skyQuery(eci, rid, func, params.decode()) | null
    }

    sequences = function() {
      ent:sequences
    }

    description = function() {
      ent:description
    }

  } // end global

  rule initialized {
    select when wrangler ruleset_installed
    fired {
      ent:sequences := ent:sequences.defaultsTo({})
    }
  }

  rule onStartup {
    select when system online
    fired {
      ent:sequences := ent:sequences.defaultsTo({})
    }
  }

  rule autoAcceptManifold {
    select when wrangler inbound_pending_subscription_added
    if event:attr("Tx_Rx_Type") == "Manifold" then
    noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }

  rule autoAcceptThing {
    select when wrangler inbound_pending_subscription_added
    if event:attr("Tx_Rx_Type") == "Community" then
    noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }

  rule installApp {
    select when manifold installapp
    pre {}
    noop()
    fired{
      raise wrangler event "install_rulesets_requested"
        attributes event:attrs;
    }
  }

  rule uninstallApp {
    select when manifold uninstallapp
    pre {}
    noop();
    fired {
      raise wrangler event "uninstall_rulesets_requested"
        attributes event:attrs;
    }
  }

  rule setDescription {
    select when community new_description
    pre {
      desc = event:attr("description")
    }
    if not desc.isnull() then noop()
    fired {
      ent:description := desc
    }
  }

  rule addThing {
    select when community add_thing
    pre {
      thing_host = event:attr("host") || null
      thing_eci = event:attr("eci")
      thing = wrangler:skyQuery(thing_eci, "io.picolabs.wrangler", "myself")
    }
    if thing then
    event:send({
      "eci": thing_eci, "eid": "subscription",
      "domain": "wrangler", "type": "subscription",
      "attrs": {
        "name"        : wrangler:myself(){"name"} + ":" + thing{"name"},
        "picoID"      : thing{"id"},
        "Rx_role"     : "thing",
        "Tx_role"     : "community",
        "Tx_Rx_Type"  : "Community",
        "channel_type": "Community",
        "wellKnown_Tx": subscription:wellKnown_Rx(){"id"},
        "Tx_host"     : meta:host
      }
    }, host = thing_host);
  }

  rule thingAdded {
    select when wrangler subscription_added
    pre {
      isCommunity = event:attr("Tx_role") == "thing"
      thing = isCommunity => wrangler:skyQuery(event:attr("Tx"), "io.picolabs.wrangler", "myself") | null
    }
    if isCommunity && thing then noop()
    fired {
      ent:thingInfo{event:attr("Id")} := {
        "id"  : thing{"id"},
        "name": thing{"name"}
      }
    }
  }

  rule thingRemoved {
    select when wrangler subscription_removed
    pre {
      Id = event:attr("Id")
    }
    if not ent:thingInfo.defaultsTo({}){Id}.isnull() then noop()
    fired {
      ent:thingInfo := ent:thingInfo.filter(function(v,k) { k != Id })
    }
  }

  rule raiseThingEvent {
    select when community raise_thing_event
    pre {
      id = event:attr("id")
      domain = event:attr("domain")
      type = event:attr("type")
      attrs = event:attr("attrs").decode()
      eci = subscription:established("picoID", id)[0]{"Tx"}
    }
    if eci then
    event:send({
      "eci": eci, "eid": "community_to_thing",
      "domain": domain, "type": type, "attrs": attrs
    })
  }

  rule raiseAllThingsEvent {
    select when community raise_all_things_event
    foreach things() setting(thing)
    pre {
      domain = event:attr("domain")
      type = event:attr("type")
      attrs = event:attr("attrs").decode()
    }
    event:send({
      "eci": thing{"Tx"}, "eid": "community_to_thing",
      "domain": domain, "type": type, "attrs": attrs
    })
  }

  rule broadcastThingEvent {
    select when community thing_event_occurred
    foreach things() setting(thing)
    pre {
      sender_id = event:attr("sender_id")
      domain = event:attr("domain")
      type = event:attr("type")
      attrs = event:attr("attrs")
    }
    if sender_id.isnull() || thing{"id"} != sender_id then
    event:send({
      "eci": thing{"Tx"}, "eid": "community_broadcast",
      "domain": domain, "type": type, "attrs": attrs
    })
  }

  rule addEventSequence {
    select when community add_sequence
    pre {
      trigger = event:attr("trigger_event")
      de = (event:attr("dispatch_events") == "") => null | event:attr("dispatch_events")
      dispatch = (de.typeof() == "Array") => de |
                (de.typeof() == "String") => de.split(re#,#) | null
      isNew = ent:sequences{trigger} == null
      sequence = (isNew) => dispatch
              | dispatch.filter(function(x) {
                  not (ent:sequences{trigger} >< x)
                })
    }
    if dispatch then noop()
    fired {
      ent:sequences{trigger} := sequence if isNew;
      ent:sequences{trigger} := ent:sequences{trigger}.append(sequence) if not isNew
    }
  }

  rule removeEventSequence {
    select when community remove_sequence
    pre {
      trigger = event:attr("trigger_event")
      de = (event:attr("dispatch_events") == "") => null | event:attr("dispatch_events")
      dispatch = (de.typeof() == "Array") => de |
                (de.typeof() == "String") => de.split(re#,#) | null
    }
    if dispatch then noop()
    fired {
      ent:sequences{trigger} := ent:sequences{trigger}.filter(function(x) {
        not (dispatch >< x)
      })
    }
    else {
      ent:sequences := ent:sequences.filter(function(v,k) { k != trigger })
    }
  }

  rule handleError {
    select when system error
    pre {
      level = event:attr("level")
      data = event:attr("data")
      rid = event:attr("rid")
      rule_name = event:attr("rule_name")
      genus = event:attr("genus")
      info = {
        "level": level,
        "data": data,
        "source": rid+":"+rule_name,
        "genus": genus,
        "time": time:now()
      }
    }
    always {
      log error info.encode()
    }
  }
}
