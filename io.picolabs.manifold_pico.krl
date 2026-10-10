ruleset io.picolabs.manifold_pico {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    shares getManifoldInfo, isAChild, getThings, getCommunities, getTagServer,
      thingRegistryKey, communityRegistryKey
    provides getManifoldInfo, getThings, getCommunities, thingRegistryKey,
      communityRegistryKey
  }//end meta

  global {
    
    thingRids = "io.picolabs.thing"
    communityRids = "io.picolabs.community"
    thing_role = "manifold_thing"
    community_role = "manifold_community"
    max_picos = 100
    appChannelName = "Manifold"
    appChannelType = "App"

    /** Relationships tab name on child picos: counterparty + local display name. */
    manifoldLinkName = function(childName) {
      childName.isnull() || childName == "" => appChannelName |
      appChannelName + ":" + childName
    }

    /** ent:things/communities display name from link bus name (no cross-pico query). */
    registryNameFromLink = function(linkName) {
      linkName.isnull() || linkName == "" => null |
      linkName.substr(0, appChannelName.length() + 1) == appChannelName + ":" =>
        linkName.substr(appChannelName.length() + 1) |
      linkName
    }

    /** App channel accepts manifold domain; subscription/wellKnown channels do not. */
    manifoldAppEci = function() {
      ent:app_channel_eci.defaultsTo(
        wrangler:channels()
          .filter(function(c) { c{"name"} == appChannelName })
          .head(){"id"}
      )
    }

    getManifoldInfo = function() {
      {
        "things": getThings(),
        "communities": getCommunities()
      }
    }

    thingSubscriptionRows = function() {
      subscription:established().filter(function(b) {
        b{"Tx_role"} == thing_role
      })
    }

    communitySubscriptionRows = function() {
      subscription:established().filter(function(b) {
        b{"Tx_role"} == community_role
      })
    }

    getThings = function() {
      entMap = ent:things.defaultsTo({})
      thingSubscriptionRows().reduce(function(acc, b) {
        picoID = b{"picoID"}
        stored = entMap{picoID}.defaultsTo({})
        name = registryNameFromLink(b{"name"}).defaultsTo(b{"name"})
        queryEci = stored{"queryEci"}.defaultsTo(b{"Tx"})
        row = stored.put(b)
          .put("name", name)
          .put("subID", b{"Id"})
          .put("picoID", picoID)
          .put("picoId", picoID)
          .put("queryEci", queryEci)
          .put("Tx", queryEci)
          .put("color", stored{"color"}.defaultsTo("#eceff1"))
        acc.put(picoID, row)
      }, {})
    }

    hasTutorial = function() {
      ent:tutorial.defaultsTo(false);
    }

    getCommunities = function() {
      entMap = ent:communities.defaultsTo({})
      communitySubscriptionRows().reduce(function(acc, b) {
        picoID = b{"picoID"}
        stored = entMap{picoID}.defaultsTo({})
        name = registryNameFromLink(b{"name"}).defaultsTo(b{"name"})
        row = stored.put(b)
          .put("name", name)
          .put("subID", b{"Id"})
          .put("picoID", picoID)
          .put("color", stored{"color"}.defaultsTo("#87cefa"))
        acc.put(picoID, row)
      }, {})
    }

    // NOt using this in things anymore. Still used in communities, but that needs to be refactored to not use this
    initiate_subscription = defaction(eci, channel_name, wellKnown, role_type, optionalHost = meta:host) {
      every{
        event:send({
          "eci": eci, 
          "eid": "subscription",
          "domain": "wrangler", 
          "type": "subscription",
          "attrs": {
                   "name"        : manifoldLinkName(event:attr("name")),
                   "picoID"      : event:attr("id"),
                   "Rx_role"     : role_type,
                   "Tx_role"     : "manifold_pico",
                   "Tx_Rx_Type"  : "Manifold" , // auto_accept
                   "channel_type": "Manifold",
                   "wellKnown_Tx": wellKnown, //this should by best practice be the parent's or the pico being requested's wellknown eci
                   "Tx_host"     : meta:host 
                  } //allow cross engine subscriptions
          }.klog("Subscription parameters"), 
          host = optionalHost)
      }
    }
    
    subIDFromPicoID = function(picoID, theMapToCheck) {
      theMapToCheck.defaultsTo({}){[picoID, "subID"]}
    }

    /** Manifold ↔ thing bus on this pico (registry subID may be stale after failed import). */
    thingManifoldSub = function(picoID) {
      subID = subIDFromPicoID(picoID, ent:things)
      byId = subID.isnull() == false && subID != ""
        => subscription:established("Id", subID)[0]
        | null
      byId.isnull() == false => byId |
      subscription:established("picoID", picoID)[0].isnull() == false
        => subscription:established("picoID", picoID)[0] |
      subscription:established().filter(function(b) {
        b{"Tx_role"} == thing_role && b{"picoID"} == picoID
      }).head()
    }

    isAChild = function(picoID) {
      children = wrangler:children() // .klog("Children in isAChild()");
      childIDs = children.map(function(child) {
        child{"eci"}
      });
      childIDs >< picoID
    }

    isAThing = function(picoID) {
      ent:things.defaultsTo({}).keys() >< picoID
    }

    isACommunity = function(picoID) {
      ent:communities.defaultsTo({}).keys() >< picoID
    }

    /** ent:things key (family channel ECI) for remove_thing / getThings. */
    thingRegistryKey = function(ref) {
      ref.isnull() || ref == "" => null |
      ent:things.defaultsTo({}).keys() >< ref => ref |
      ent:things.defaultsTo({}).keys().filter(function(k) {
        row = ent:things{k}
        row{"queryEci"} == ref || row{"picoID"} == ref
      }).head()
    }

    communityRegistryKey = function(ref) {
      ref.isnull() || ref == "" => null |
      ent:communities.defaultsTo({}).keys() >< ref => ref |
      ent:communities.defaultsTo({}).keys().filter(function(k) {
        row = ent:communities{k}
        row{"picoID"} == ref
      }).head()
    }

    getTagServer = function() {
      parent = wrangler:parent_eci().klog("parent") // ask mom
      tag_pico = wrangler:picoQuery(parent, "io.picolabs.manifold_owner", "getTagServer")
      tag_pico
    }

    PORTABLE_SUBTREE_RID = "io.picolabs.portable_subtree"
    MANIFOLD_PORTABLE_THING_RID = "io.picolabs.manifold_portable_thing"

    enginePortableSubtreeUrl = function() {
      meta:host + "/krl/io.picolabs.portable_subtree.krl"
    }

    initializationRids = ["io.picolabs.notifications",
                          "io.picolabs.twilio.sms",
                          "io.picolabs.prowl",
                          "io.picolabs.homeassistant"
                        ]

  } //end global

  


  rule createThing {
    select when manifold create_thing
    if event:attr("name") && wrangler:children().length() <= max_picos then
      send_directive("Attempting to create new Thing", { "thing":event:attr("name") })
    fired {
      raise wrangler event "new_child_request"
        attributes event:attrs.put({ "event_name": "manifold_create_thing" })
    }
  }

  rule install_thing_ruleset {
    select when wrangler child_initialized where event:attr("event_name") == "manifold_create_thing"
    pre {
      absoluteURL = meta:rulesetURI;
      child_eci = event:attr("eci");
    }
    if child_eci && absoluteURL then
      event:send({
        "eci": child_eci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": { 
          "rid": "io.picolabs.thing",
          "absoluteURL": absoluteURL
        }
      })
  }

  rule thingCompleted {
    select when wrangler child_initialized where event:attr("event_name") == "manifold_create_thing"
    pre {
      eci = event:attr("eci");
      wellKnown = subscription:wellKnown_Rx(){"id"};
      role_type = thing_role;
      children = wrangler:children();
      picoID = eci // ctx:query(eci,"io.picolabs.wrangler","myself"){"id"}.klog("PicoID"); // may be better ways to do this
    }
    // initiate_subscription(event:attr("eci"), event:attr("name"), subscription:wellKnown_Rx(){"id"}, thing_role);
    event:send({
          "eci": eci, 
          "eid": "subscription",
          "domain": "wrangler", 
          "type": "subscription",
          "attrs": {
                   "name"        : manifoldLinkName(event:attr("name")),
                   "picoID"      : picoID,
                   "Rx_role"     : role_type,
                   "Tx_role"     : "manifold_pico",
                   "Tx_Rx_Type"  : "Manifold" , // auto_accept
                   "channel_type": "Manifold",
                   "wellKnown_Tx": wellKnown, //this should by best practice be the parent's or the pico being requested's wellknown eci
                   "Tx_host"     : meta:host 
                  } //allow cross engine subscriptions
          } // .klog("Subscription parameters")
      )
  }

  rule autoAcceptSubscriptions {
    select when wrangler inbound_pending_subscription_added
      where event:attr("Tx_Rx_Type") == "Manifold"
    always {
      raise wrangler event "pending_subscription_approval" attributes event:attrs.klog("sub attrs"); // Simplified and idiomatic subscription acceptance
    }
  }

  // Portable import (and other flows) may index a thing before subscription_added.
  rule registerThingIndex {
    select when manifold register_thing_index
    pre {
      picoID = event:attr("picoID")
      name = event:attr("name")
      queryEci = event:attr("queryEci")
      prior = ent:things.defaultsTo({}){picoID}
    }
    if picoID && name then
      send_directive("Register thing in Manifold index", {
        "picoID": picoID,
        "name": name
      })
    fired {
      ent:things := ent:things.defaultsTo({});
      ent:things{picoID} := {
        "name": name,
        "picoID": picoID,
        "queryEci": queryEci,
        "subID": prior{"subID"},
        "color": prior{"color"}.defaultsTo("#eceff1")
      }
    }
  }

  rule deferTrackThingSubscription {
    select when wrangler subscription_added where event:attr("Tx_role") == thing_role
    pre {
      app_eci = manifoldAppEci()
    }
    if app_eci then
      event:send({
        "eci": app_eci,
        "domain": "manifold",
        "type": "track_thing_subscription",
        "attrs": {
          "Id": event:attr("Id"),
          "picoID": event:attr("picoID"),
          "Tx": event:attr("Tx"),
          "name": event:attr("name")
        }
      })
  }

  rule trackThingSubscription {
    select when manifold track_thing_subscription
    pre {
      subID = event:attr("Id");
      picoID = event:attr("picoID");
      thingQueryEci = event:attr("Tx");
      name = registryNameFromLink(event:attr("name"))
        .defaultsTo(event:attr("name"));
      obj_structure = {
        "name": name,
        "subID": subID,
        "picoID": picoID,
        "queryEci": thingQueryEci,
        "color": "#eceff1"//default color
      }
    }
    fired {
      ent:things := ent:things.defaultsTo({});
      ent:things{picoID} := obj_structure;
    }
  }

  // Thing-creation delegation: when a create_thing request carries both a
  // callback_eci and a correlation id (rcn), remember them keyed by the new
  // pico's eci so the delegating pico can be notified once the thing is ready.
  // Requests without these attrs never populate this map, preserving the
  // traditional Manifold flow unchanged.
  rule stashThingCallback {
    select when wrangler child_initialized where event:attr("event_name") == "manifold_create_thing"
    pre {
      eci = event:attr("eci");
      callback_eci = event:attr("callback_eci");
      rcn = event:attr("rcn");
    }
    if eci && callback_eci && rcn then
      send_directive("Registering thing-creation callback", { "rcn": rcn })
    fired {
      ent:pending_callbacks := ent:pending_callbacks.defaultsTo({});
      ent:pending_callbacks{eci} := {
        "callback_eci": callback_eci,
        "rcn": rcn
      };
    }
  }

  // Fire the delegation callback once the thing's manifold_thing subscription
  // is established, but only when a callback was registered for this thing.
  rule deferFireThingCreatedCallback {
    select when wrangler subscription_added where event:attr("Tx_role") == thing_role
    pre {
      app_eci = manifoldAppEci()
    }
    if app_eci then
      event:send({
        "eci": app_eci,
        "domain": "manifold",
        "type": "fire_thing_created_callback",
        "attrs": event:attrs
      })
  }

  rule fireThingCreatedCallback {
    select when manifold fire_thing_created_callback
    pre {
      bus = event:attr("bus").defaultsTo({})
      picoID = event:attr("picoID") || bus{"picoID"}
      thing_eci = event:attr("Tx") || bus{"Tx"}
      cb = ent:pending_callbacks.defaultsTo({}){picoID}
      thing_wrangler_id = thing_eci
        => wrangler:picoQuery(thing_eci, "io.picolabs.wrangler", "myself", {}){"id"}
        | null
    }
    if cb then every {
      event:send({
        "eci": cb{"callback_eci"},
        "eid": "thing_created",
        "domain": "community",
        "type": "thing_created",
        "attrs": {
          "rcn": cb{"rcn"},
          "thingPicoID": picoID,
          "thing_eci": thing_eci,
          "thingWranglerId": thing_wrangler_id
        }
      });
      event:send({
        "eci": cb{"callback_eci"},
        "eid": "thing_completed",
        "domain": "community",
        "type": "thing_completed",
        "attrs": {
          "rcn": cb{"rcn"},
          "thingPicoID": picoID,
          "thing_eci": thing_eci,
          "thingWranglerId": thing_wrangler_id
        }
      })
    }
    fired {
      ent:pending_callbacks := ent:pending_callbacks.filter(function(v, k) { k != picoID });
    }
  }

  rule createCommunity {
    select when manifold new_community
    if event:attr("name") && wrangler:children().length() <= max_picos then
      send_directive("Attempting to create new Community", {"community": event:attr("name"), "description": event:attr("description")})
    fired {
      raise wrangler event "new_child_request"
        attributes event:attrs.put({"event_name": "manifold_new_community"})
    }
  }

  rule install_community_ruleset {
    select when wrangler child_initialized where event:attr("event_name") == "manifold_new_community"
    pre {
      absoluteURL = meta:rulesetURI
                   || wrangler:rulesetByRID("io.picolabs.manifold_pico"){"url"}
      child_eci = event:attr("eci")
    }
    if child_eci && absoluteURL then every {
      send_directive("installing io.picolabs.community on new community",
                     {"child_eci": child_eci, "absoluteURL": absoluteURL});
      event:send({
        "eci": child_eci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": {
          "rid": "io.picolabs.community",
          "absoluteURL": absoluteURL
        }
      })
    }
    notfired {
      error warn <<install_community_ruleset skipped: child_eci=#{child_eci} absoluteURL=#{absoluteURL}>>;
    }
  }

  // Community-creation delegation: same callback_eci + rcn pattern as things.
  rule stashCommunityCallback {
    select when wrangler child_initialized where event:attr("event_name") == "manifold_new_community"
    pre {
      eci = event:attr("eci");
      callback_eci = event:attr("callback_eci");
      rcn = event:attr("rcn");
    }
    if eci && callback_eci && rcn then
      send_directive("Registering community-creation callback", { "rcn": rcn })
    fired {
      ent:pending_community_callbacks := ent:pending_community_callbacks.defaultsTo({});
      ent:pending_community_callbacks{eci} := {
        "callback_eci": callback_eci,
        "rcn": rcn
      };
    }
  }

  rule communityCompleted {
    select when wrangler child_initialized where event:attr("event_name") == "manifold_new_community"
    pre {
      eci = event:attr("eci");
      wellKnown = subscription:wellKnown_Rx(){"id"};
      picoID = eci;
      description = event:attr("description");
    }
    every {
      event:send({
        "eci": eci,
        "eid": "subscription",
        "domain": "wrangler",
        "type": "subscription",
        "attrs": {
          "name"        : manifoldLinkName(event:attr("name")),
          "picoID"      : picoID,
          "Rx_role"     : community_role,
          "Tx_role"     : "manifold_pico",
          "Tx_Rx_Type"  : "Manifold",
          "channel_type": "Manifold",
          "wellKnown_Tx": wellKnown,
          "Tx_host"     : meta:host
        }
      });
      event:send({
        "eci": eci,
        "eid": "set_description",
        "domain": "community",
        "type": "new_description",
        "attrs": { "description": description }
      });
      event:send({
        "eci": eci,
        "eid": "pds_profile",
        "domain": "pds",
        "type": "updated_profile",
        "attrs": {
          "name": event:attr("name"),
          "description": description
        }
      })
    }
  }

  rule deferFireCommunityCreatedCallback {
    select when wrangler subscription_added where event:attr("Tx_role") == community_role
    pre {
      app_eci = manifoldAppEci()
    }
    if app_eci then
      event:send({
        "eci": app_eci,
        "domain": "manifold",
        "type": "fire_community_created_callback",
        "attrs": event:attrs
      })
  }

  // Notify delegating pico once the community's manifold subscription exists.
  rule fireCommunityCreatedCallback {
    select when manifold fire_community_created_callback
    pre {
      bus = event:attr("bus").defaultsTo({})
      picoID = event:attr("picoID") || bus{"picoID"}
      community_eci = event:attr("Tx") || bus{"Tx"}
      cb = ent:pending_community_callbacks.defaultsTo({}){picoID}
    }
    if cb then
      event:send({
        "eci": cb{"callback_eci"},
        "eid": "community_completed",
        "domain": "community",
        "type": "community_completed",
        "attrs": {
          "rcn": cb{"rcn"},
          "communityPicoID": picoID,
          "community_eci": community_eci
        }
      })
    fired {
      ent:pending_community_callbacks := ent:pending_community_callbacks.filter(function(v, k) { k != picoID });
    }
  }

  rule addThingToCommunity {
    select when manifold add_thing_to_community
    pre {
      thingPicoID = event:attr("thingPicoID");
      communityPicoID = event:attr("communityPicoID");
      commSub = subscription:established("Id", ent:communities.defaultsTo({}){[communityPicoID, "subID"]})[0];
      thingSub = subscription:established("Id", ent:things.defaultsTo({}){[thingPicoID, "subID"]})[0];
      community_eci = commSub{"Tx"};
      thing_eci = thingSub{"Tx"};
    }
    if community_eci && thing_eci then
      event:send({
        "eci": community_eci, "eid": "add_thing_to_community",
        "domain": "community", "type": "add_thing",
        "attrs": { "eci": thing_eci }
      })
  }

  rule removeThingFromCommunity {
    select when manifold remove_thing_from_community
    pre {
      thingPicoID = event:attr("thingPicoID");
      communityPicoID = event:attr("communityPicoID");
      commSub = subscription:established("Id", ent:communities.defaultsTo({}){[communityPicoID, "subID"]})[0];
      thingSub = subscription:established("Id", ent:things.defaultsTo({}){[thingPicoID, "subID"]})[0];
      community_eci = commSub{"Tx"};
      thing_eci = thingSub{"Tx"};
      member_subs = thing_eci => wrangler:picoQuery(thing_eci, "io.picolabs.thing", "communities", {}) | [];
      community_member_sub = member_subs.filter(function(s) { s{"Tx_role"} == "community" }).head();
    }
    if community_member_sub && thing_eci then
      event:send({
        "eci": thing_eci,
        "domain": "wrangler",
        "type": "subscription_cancellation",
        "attrs": { "Id": community_member_sub{"Id"} }
      })
  }

  rule deferTrackCommSubscription {
    select when wrangler subscription_added where event:attr("Tx_role") == community_role
    pre {
      app_eci = manifoldAppEci()
    }
    if app_eci then
      event:send({
        "eci": app_eci,
        "domain": "manifold",
        "type": "track_comm_subscription",
        "attrs": {
          "Id": event:attr("Id"),
          "picoID": event:attr("picoID"),
          "name": event:attr("name")
        }
      })
  }

  rule trackCommSubscription {
    select when manifold track_comm_subscription
    pre {
      subID = event:attr("Id");
      picoID = event:attr("picoID");
      name = registryNameFromLink(event:attr("name"))
        .defaultsTo(event:attr("name"));
      obj_structure = {
        "name": name,
        "subID": subID,
        "picoID": picoID,
        "color": "#87cefa" //default community color
      };
    }
    fired {
      ent:communities := ent:communities.defaultsTo({});
      ent:communities{picoID} := obj_structure;
    }
  }

  rule reconcileThingRegistry {
    select when manifold reconcile_thing_registry
    fired {
      ent:things := getThings()
    }
  }

  rule reconcileCommunityRegistry {
    select when manifold reconcile_community_registry
    fired {
      ent:communities := getCommunities()
    }
  }

  rule scheduleRegistryReconcile {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      app_eci = manifoldAppEci()
    }
    if app_eci then every {
      event:send({
        "eci": app_eci,
        "domain": "manifold",
        "type": "reconcile_thing_registry",
        "attrs": {}
      });
      event:send({
        "eci": app_eci,
        "domain": "manifold",
        "type": "reconcile_community_registry",
        "attrs": {}
      })
    }
  }

  rule seedRegistryAfterUpgrade {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    fired {
      ent:things := getThings()
      ent:communities := getCommunities()
    }
  }

  rule removeThingSubscription {
    select when manifold remove_thing
    pre {
      rawPicoID = event:attr("picoID");
      picoID = thingRegistryKey(rawPicoID).defaultsTo(rawPicoID);
      sub = thingManifoldSub(picoID);
    }

    if picoID && sub.isnull() == false then every {
      send_directive("Attempting to cancel subscription to Thing", {
        "thing": ent:things{[picoID, "name"]}
      })
    }
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Id": sub{"Id"}, "picoID": picoID, "event_type": "thing_deletion"}
    }
  }

  rule removeThingOrphan {
    select when manifold remove_thing
    pre {
      rawPicoID = event:attr("picoID");
      picoID = thingRegistryKey(rawPicoID).defaultsTo(rawPicoID);
      indexed = picoID.isnull() == false
        && ent:things.defaultsTo({}).keys() >< picoID;
      child = picoID.isnull() == false && isAChild(picoID);
      sub = thingManifoldSub(picoID);
      orphan = sub.isnull() && (indexed || child);
    }
    if picoID && orphan then
      send_directive("Removing thing without established Manifold subscription", {
        "picoID": picoID,
        "name": ent:things{[picoID, "name"]},
        "indexed": indexed,
        "child": child
      })
    fired {
      ent:things := ent:things.filter(function(thing, key) { key != picoID });
    }
  }

  rule removeThingOrphanChild {
    select when manifold remove_thing
    pre {
      rawPicoID = event:attr("picoID");
      picoID = thingRegistryKey(rawPicoID).defaultsTo(rawPicoID);
      sub = thingManifoldSub(picoID);
      child = picoID.isnull() == false && isAChild(picoID);
    }
    if picoID && sub.isnull() && child then
      send_directive("Removing orphan Thing child pico", {
        "thing": ent:things{[picoID, "name"]},
        "picoID": picoID
      })
    fired {
      raise wrangler event "child_deletion_request"
        attributes { "eci": picoID }
    }
  }

  rule deleteThing {
    select when wrangler subscription_removed where event:attr("event_type") == "thing_deletion"
    pre {
      picoID = event:attr("picoID");
    }
    if picoID && isAChild(picoID) then
      send_directive("Attempting to remove Thing", { "thing": ent:things{[picoID, "name"]}, "picoID": picoID })
    fired {
      ent:things := ent:things.filter(function(thing, key){ key != picoID});
      raise wrangler event "child_deletion_request"
        attributes { "eci": picoID } 
    }
  }

  rule removeCommunity {
    select when manifold remove_community
    pre {
      picoID = event:attr("picoID");
      subID = subIDFromPicoID(picoID, ent:communities).klog("found subID: ");
      sub = subscription:established("Id", subID)[0].klog("found sub: ");
    }
    if picoID && subID && sub then every {
      send_directive("Attempting to cancel subscription to Community", {
        "community": ent:communities{[picoID, "name"]}.defaultsTo(event:attr("name"))
      })
    }
    fired {
      raise wrangler event "subscription_cancellation"
        attributes { "Id": sub{"Id"}, "picoID": picoID, "event_type": "community_deletion" }
    }
  }
  rule deleteCommunity {
    select when wrangler subscription_removed where event:attr("event_type") == "community_deletion"
    pre{
      picoID = event:attr("picoID");
    }
    if picoID && isAChild(picoID) then
      send_directive("Attempting to remove Community", { "community": ent:communities{[picoID, "name"]}, "picoID": picoID })
    fired{
      ent:communities := ent:communities.filter(function(thing){ thing{"subID"} != event:attr("Id")});
      raise wrangler event "child_deletion_request"
        attributes { "eci": picoID }
    }
  }

  rule updateThingLocation {
    select when manifold move_thing
    pre {
      picoID = event:attr("picoID");
    }
    if picoID && isAThing(picoID) then
      send_directive("Updating Thing Location", { "attrs": event:attrs })
    fired {
      ent:things{[picoID, "pos"]} := {
        "x": event:attr("x").as("Number"),
        "y": event:attr("y").as("Number"),
        "w": event:attr("w").as("Number"),
        "h": event:attr("h").as("Number"),
        "minw": 3,
        "minh": 2.25,
        "maxw": 8,
        "maxh": 5
      };
    }
  }

  rule updateCommunityLocation {
    select when manifold move_community
    pre {
      picoID = event:attr("picoID");
    }
    if picoID && isACommunity(picoID) then
      send_directive("Updating Community Location", { "attrs": event:attrs })
    fired {
      ent:communities{[picoID, "pos"]} := {
        "x": event:attr("x").as("Number"),
        "y": event:attr("y").as("Number"),
        "w": event:attr("w").as("Number"),
        "h": event:attr("h").as("Number"),
        "minw": 3,
        "minh": 2.25,
        "maxw": 8,
        "maxh": 5
      };
    }
  }

  rule devReset {
    select when manifold devReset
    always{
      clear ent:things;
      clear ent:communities;
    }
  }

  rule changeThingName {
    select when manifold change_thing_name

    pre {
      picoID = event:attr("picoID");
      changedName = event:attr("changedName");
    }

    if not (picoID.isnull() || changedName.isnull()) then every {
      send_directive("THINGS", { "things list" : ent:things });
      event:send({
        "eci": picoID,
        "domain": "pds",
        "type": "updated_profile",
        "attrs": {"name": changedName}
      })
    }

    fired {
      ent:things{[picoID, "name"]} := changedName;
    }
  }

  // initialization rulesets

  rule initialization {
    select when wrangler ruleset_installed where event:attr("rids").klog("rid") >< ctx:rid.klog("meta rid")
    foreach initializationRids setting(rid)
      pre {
        absoluteURL = meta:rulesetURI;
      }
      if absoluteURL then noop();
      fired {
        raise wrangler event "install_ruleset_request"
          attributes {
            "rid": rid.klog("Installing "),
            "absoluteURL": absoluteURL
          }
      }
  }

  // Opt-in portable thing move (engine portable_subtree + manifold_portable_thing; not part of bootstrap)
  rule enable_portable_thing_install_engine_rs {
    select when manifold enable_portable_thing
    pre {
      installed = wrangler:installedRIDs()
      needPortable = not (installed >< PORTABLE_SUBTREE_RID)
      needWrapper = not (installed >< MANIFOLD_PORTABLE_THING_RID)
    }
    if needPortable then noop()
    fired {
      ent:enablePortableThing := needWrapper
      raise wrangler event "install_ruleset_request"
        attributes {
          "rid": PORTABLE_SUBTREE_RID,
          "absoluteURL": enginePortableSubtreeUrl()
        }
    }
  }

  rule enable_portable_thing_install_wrapper_rs {
    select when manifold enable_portable_thing
    pre {
      installed = wrangler:installedRIDs()
      havePortable = installed >< PORTABLE_SUBTREE_RID
      needWrapper = not (installed >< MANIFOLD_PORTABLE_THING_RID)
      absoluteURL = meta:rulesetURI
    }
    if havePortable && needWrapper && absoluteURL then noop()
    fired {
      raise wrangler event "install_ruleset_request"
        attributes {
          "rid": MANIFOLD_PORTABLE_THING_RID,
          "absoluteURL": absoluteURL
        }
    }
  }

  rule enable_portable_thing_finish_after_portable {
    select when wrangler ruleset_installed
    pre {
      eventRids = event:attr("rids")
      installed = wrangler:installedRIDs()
      pending = ent:enablePortableThing.defaultsTo(false)
      absoluteURL = meta:rulesetURI
      needWrapper = not (installed >< MANIFOLD_PORTABLE_THING_RID)
    }
    if pending && (eventRids >< PORTABLE_SUBTREE_RID) && needWrapper && absoluteURL then noop()
    fired {
      ent:enablePortableThing := false
      raise wrangler event "install_ruleset_request"
        attributes {
          "rid": MANIFOLD_PORTABLE_THING_RID,
          "absoluteURL": absoluteURL
        }
    }
  }

   rule set_tag_server {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      parent = wrangler:channels("system,child").head(){"id"}.klog("parent")
      tag_pico = wrangler:picoQuery(parent, "io.picolabs.manifold_owner", "getTagServer")
    }
    noop();
    always {
      ent:tag_pico := tag_pico
    }
  }
  
  rule createAppChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      existing_channels = wrangler:channels();
      app_channel = existing_channels.filter(function(chan){
        chan{"name"} == appChannelName
      });
      channel_exists = app_channel.length() > 0;
    }
    if not channel_exists then
      wrangler:createChannel([appChannelName], null, null) setting(channel)
    fired {
      ent:app_channel_eci := channel{"id"}
    }
  }

  rule updateManifoldVersion {
    select when manifold update_version
    foreach ["io.picolabs.notifications",
             "io.picolabs.twilio.sms",
             "io.picolabs.prowl",
             "io.picolabs.homeassistant"].difference(wrangler:installedRulesets()).klog("needed") setting(rid)
      pre {
        absoluteURL = meta:rulesetURI;
      }
      if absoluteURL then noop();
      fired {
        raise wrangler event "install_ruleset_request"
          attributes {
            "rid": rid,
            "absoluteURL": absoluteURL
          }
      }
  }

}//end ruleset
