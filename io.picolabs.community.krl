ruleset io.picolabs.community {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    use module io.picolabs.pds alias pds
    shares things, queryThing, sequences, description
  }
  global {

    thingMemberRef = function(sub) {
      sub{"layer2"} == true && sub{"Tx_did"} => sub{"Tx_did"} | sub{"Tx"}
    }

    pds_name = function(ref) {
      wrangler:picoQuery(ref, "io.picolabs.pds", "profile", "name"){"profile"}
    }

    liveThingMemberName = function(sub) {
      sub{"layer2"} == true => layer2ThingMemberName(sub) | l1ThingMemberName(sub)
    }

    l1ThingMemberName = function(sub) {
      ref = sub{"Tx"}
      pds_name(ref)
        || wrangler:picoQuery(ref, "io.picolabs.wrangler", "myself"){"name"}
    }

    layer2ThingMemberName = function(sub) {
      subscription:queryOnSub(sub{"Id"}, "io.picolabs.pds", "profile", {}){"profile"}{"name"}
        || subscription:queryOnSub(sub{"Id"}, "io.picolabs.wrangler", "myself", {}){"name"}
    }

    thingMemberName = function(sub) {
      cached = ent:thingInfo.defaultsTo({}){sub{"Id"}}.defaultsTo({});
      cached{"name"} || liveThingMemberName(sub)
    }

    things = function() {
      subscription:established().filter(function(sub) {
        sub{"Tx_role"} == "thing"
      }).map(function(sub) {
        cached = ent:thingInfo.defaultsTo({}){sub{"Id"}}.defaultsTo({});
        sub.put(cached).put({"name": thingMemberName(sub)})
      })
    }

    queryThing = function(id, rid, func, params) {
      sub = subscription:established("picoID", id)[0]
      sub.isnull() => null |
      subscription:queryOnSub(sub{"Id"}, rid, func, params.decode())
    }

    sequences = function() {
      ent:sequences
    }

    description = function() {
      pds:profile("description"){"profile"}
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
    pre {
      // Tx_Rx_Type is set by addThing but may not survive the subscription
      // handshake attrs; role pair is the reliable signal for thing members.
      tx_rx_type = event:attr("Tx_Rx_Type")
      rx_role = event:attr("Rx_role")
      tx_role = event:attr("Tx_role")
      is_thing_member = (tx_rx_type == "Community")
                     || (rx_role == "community" && tx_role == "thing")
    }
    if is_thing_member then noop()
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
      raise pds event "updated_profile" attributes {"description": desc}
    }
  }

  rule addThing {
    select when community add_thing
    pre {
      thing_host = event:attr("host") || null
      thing_eci = event:attr("eci")
      thing = wrangler:picoQuery(thing_eci, "io.picolabs.pds", "profile")
      thing_id = wrangler:picoQuery(thing_eci, "io.picolabs.wrangler", "myself"){"id"}
      thing_name = thing{"profile"}{"name"}
                    || wrangler:picoQuery(thing_eci, "io.picolabs.wrangler", "myself"){"name"}
      query_ok = thing && thing{"picoQueryError"}.isnull() && thing_id
    }
    if query_ok then every {
      send_directive("requesting community-thing subscription", {
        "thing_eci": thing_eci,
        "thing_id": thing_id,
        "thing_name": thing_name
      })
      event:send({
        "eci": thing_eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": {
          "name"        : wrangler:myself(){"name"} + ":" + thing_name,
          "picoID"      : thing_id,
          "Rx_role"     : "thing",
          "Tx_role"     : "community",
          "Tx_Rx_Type"  : "Community",
          "channel_type": "Community",
          "wellKnown_Tx": subscription:wellKnown_Rx(){"id"},
          "Tx_host"     : meta:host
        }
      }, host = thing_host)
    }
    notfired {
      error warn <<add_thing failed: could not query thing at #{thing_eci}: #{thing.encode()}>>;
    }
  }

  rule thingAdded {
    select when wrangler subscription_added
    pre {
      isCommunity = event:attr("Tx_role") == "thing"
      thing = isCommunity => wrangler:picoQuery(event:attr("Tx"), "io.picolabs.pds", "profile") | null
      thing_id = isCommunity => wrangler:picoQuery(event:attr("Tx"), "io.picolabs.wrangler", "myself"){"id"} | null
      thing_name = thing && thing{"profile"} => thing{"profile"}{"name"}
                    | wrangler:picoQuery(event:attr("Tx"), "io.picolabs.wrangler", "myself"){"name"}
      link_name = event:attr("name")
        .defaultsTo(event:attr("channel_name"))
        .defaultsTo(wrangler:myself(){"name"} + ":" + thing_name)
    }
    if isCommunity && thing_id then noop()
    fired {
      ent:thingInfo{event:attr("Id")} := {
        "id"  : thing_id,
        "name": link_name
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

  // Disabled pending redesign: automatic fan-out of thing_event_occurred to other
  // community members caused feedback loops (e.g. sensor-network with multiple
  // sensors). Use community raise_thing_event / raise_all_things_event explicitly.
  // rule broadcastThingEvent {
  //   select when community thing_event_occurred
  //   foreach things() setting(thing)
  //   pre {
  //     sender_id = event:attr("sender_id")
  //     domain = event:attr("domain")
  //     type = event:attr("type")
  //     attrs = event:attr("attrs")
  //   }
  //   if sender_id.isnull() || thing{"id"} != sender_id then
  //   event:send({
  //     "eci": thing{"Tx"}, "eid": "community_broadcast",
  //     "domain": domain, "type": type, "attrs": attrs
  //   })
  // }

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
