ruleset io.picolabs.community {
  meta {
    name "Manifold community"
    description <<
      Base ruleset for a Manifold community pico: a group of things. Accepts things
      as members, keeps their names, and sends events to one member or all of them.
      Installed by Manifold when it creates a community.
    >>
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
      resp = wrangler:picoQuery(ref, "io.picolabs.pds", "profile", {"key": "name"});
      resp.typeof() == "Map" && resp{"picoQueryError"}.isnull() => resp{"profile"} | null
    }

    liveThingMemberName = function(sub) {
      sub{"layer2"} == true => layer2ThingMemberName(sub) | l1ThingMemberName(sub)
    }

    l1ThingMemberName = function(sub) {
      ref = sub{"Tx"}
      pds_name(ref)
        || wrangler:picoQuery(ref, "io.picolabs.wrangler", "myself", {}){"name"}
    }

    layer2ThingMemberName = function(sub) {
      subscription:queryOnSub(sub{"Id"}, "io.picolabs.pds", "profile", {}){"profile"}{"name"}
        || subscription:queryOnSub(sub{"Id"}, "io.picolabs.wrangler", "myself", {}){"name"}
    }

    thingMemberLinkName = function(sub, cached) {
      thing_nm = liveThingMemberName(sub);
      comm_nm = pds:profile("name"){"profile"} || wrangler:myself(){"name"};
      link_default = comm_nm + ":" + thing_nm;
      cached_nm = cached{"name"};
      cached_nm && cached_nm.split(re#:#).length() > 1 => cached_nm | link_default
    }

    thingMemberName = function(sub) {
      cached = ent:thingInfo.defaultsTo({}){sub{"Id"}}.defaultsTo({});
      thingMemberLinkName(sub, cached)
    }

    /**
     * The things in this community: its established relationships with Tx_role
     * thing, each with the thing's name.
     * @returns Array
     */
    things = function() {
      subscription:established().filter(function(sub) {
        sub{"Tx_role"} == "thing"
      }).map(function(sub) {
        cached = ent:thingInfo.defaultsTo({}){sub{"Id"}}.defaultsTo({});
        sub.put(cached).put({"name": thingMemberName(sub)})
      })
    }

    /**
     * Query a function on one member thing over its community relationship. Null
     * if no member has that picoID.
     * @param id String "the thing's picoID"
     * @param rid String "ruleset id on the thing"
     * @param func String "shared function to call"
     * @param params String "its arguments, JSON-encoded"
     * @returns Any
     * @example "thing's name" { "id": "<thing picoID>", "rid": "io.picolabs.wrangler", "func": "name", "params": "{}" }
     */
    queryThing = function(id, rid, func, params) {
      sub = subscription:established("picoID", id)[0]
      sub.isnull() => null |
      subscription:queryOnSub(sub{"Id"}, rid, func, params.decode())
    }

    // Shared, but not discoverable: event sequences are stored by add_sequence /
    // remove_sequence, but no rule dispatches them yet.
    sequences = function() {
      ent:sequences
    }

    /**
     * This community's description, from its PDS profile.
     * @returns String
     */
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

  // TODO: raises wrangler install_rulesets_requested (plural), which wrangler 1.0
  // doesn't handle, so this does nothing. Not discoverable until fixed
  // (io.picolabs.thing's installApp shows the working pattern).
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

  /**
   * Set this community's description (stored in its PDS profile).
   * @attr description String
   * @example "set" { "description": "<description>" }
   */
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

  /**
   * Add a thing to this community: requests a relationship with the thing, which
   * the thing accepts automatically. Fails (logged) if the thing can't be queried
   * at eci.
   * @attr eci String "a channel on the thing that allows queries, e.g. its Manifold Tx (not its family channel)"
   * @attr host String optional "the thing's engine URL, if on another engine"
   * @example "same engine" { "eci": "<thing eci>" }
   */
  rule addThing {
    select when community add_thing
    pre {
      thing_host = event:attr("host") || null
      thing_eci = event:attr("eci")
      thing = wrangler:picoQuery(thing_eci, "io.picolabs.pds", "profile", {})
      thing_id = wrangler:picoQuery(thing_eci, "io.picolabs.wrangler", "myself", {}){"id"}
      thing_name = thing.typeof() == "Map" && thing{"profile"}{"name"}
                    || wrangler:picoQuery(thing_eci, "io.picolabs.wrangler", "myself", {}){"name"}
      query_ok = thing.typeof() == "Map" && thing{"picoQueryError"}.isnull() && thing_id
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
      bus = event:attr("bus").defaultsTo({})
      isCommunity = event:attr("Tx_role") == "thing"
      thing_eci = event:attr("Tx")
      thing = isCommunity => wrangler:picoQuery(thing_eci, "io.picolabs.pds", "profile", {}) | null
      thing_id = isCommunity => wrangler:picoQuery(thing_eci, "io.picolabs.wrangler", "myself", {}){"id"} | null
      thing_name = thing.typeof() == "Map" && thing{"profile"}{"name"}
                    || wrangler:picoQuery(thing_eci, "io.picolabs.wrangler", "myself", {}){"name"}
      link_name = event:attr("channel_name")
        .defaultsTo(bus{"channel_name"})
        .defaultsTo(event:attr("name"))
        .defaultsTo(bus{"name"})
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

  /**
   * Send an event to one member thing.
   * @attr id String "the thing's picoID"
   * @attr domain String
   * @attr type String
   * @attr attrs String "its attributes, JSON-encoded"
   * @example "one thing" { "id": "<thing picoID>", "domain": "<domain>", "type": "<type>", "attrs": "{}" }
   */
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

  /**
   * Send an event to every member thing.
   * @attr domain String
   * @attr type String
   * @attr attrs String "its attributes, JSON-encoded"
   * @example "all things" { "domain": "<domain>", "type": "<type>", "attrs": "{}" }
   */
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

  // Not discoverable: sequences are stored but nothing dispatches them yet.
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
