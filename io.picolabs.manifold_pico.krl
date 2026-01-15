ruleset io.picolabs.manifold_pico {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    shares __testing, getManifoldInfo, isAChild, getThings
    provides __testing, getManifoldInfo, getThings
  }//end meta

  global {
    
    thingRids = "io.picolabs.thing"
    communityRids = "io.picolabs.community"
    thing_role = "manifold_thing"
    community_role = "manifold_community"
    max_picos = 100

    getManifoldInfo = function() {
      {
        "things": getThings(),
        "communities": getCommunities()
      }
    }

    getThings = function() {
      ent:things.defaultsTo({}).map(function(value, key) {
        sub = subscription:established("Id", value{"subID"})[0];
        sub.put(value)
           .put("picoId",key)
      })
    }


    hasTutorial = function() {
      ent:tutorial.defaultsTo(false);
    }

    getCommunities = function() {
      ent:communities.defaultsTo({}).map(function(value, key) {
        sub = subscription:established("Id", value{"subID"})[0];
        sub.put(value)
      })
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
                   "name"        : event:attr("name"),
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

    isAChild = function(picoID) {
      children = wrangler:children();
      childIDs = children.map(function(child) {
        child{"id"}
      });
      childIDs >< picoID
    }

    isAThing = function(picoID) {
      ent:things.defaultsTo({}).keys() >< picoID
    }

    isACommunity = function(picoID) {
      ent:communities.defaultsTo({}).keys() >< picoID
    }

    initializationRids = ["io.picolabs.notifications",
                          "io.picolabs.prowl_notifications",
                          "io.picolabs.twilio_notifications",
                          "io.picolabs.manifold.email_notifications"
                        ]
    
    appChannelName = "Manifold"
    appChannelType = "App"

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
      picoID = ctx:query(eci,"io.picolabs.wrangler","myself"){"id"}.klog("PicoID"); // may be better ways to do this
    }
    // initiate_subscription(event:attr("eci"), event:attr("name"), subscription:wellKnown_Rx(){"id"}, thing_role);
    event:send({
          "eci": eci, 
          "eid": "subscription",
          "domain": "wrangler", 
          "type": "subscription",
          "attrs": {
                   "name"        : event:attr("name"),
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

  rule trackThingSubscription {
    select when wrangler subscription_added where event:attr("Tx_role") == thing_role
    pre {
      subID = event:attr("Id");
      name = event:attr("name");
      picoID = event:attr("picoID");
      obj_structure = {
        "name": name,
        "subID": subID,
        "picoID": picoID,
        "color": "#eceff1"//default color
      }
    }
    if subID && name && picoID then
      send_directive("Tracking subscription", { "info": obj_structure })
    fired {
      ent:things := ent:things.defaultsTo({}).put([picoID], obj_structure);
    }
  }

  rule createCommunity {
    select when manifold create_community
    if event:attr("name") then every {
      send_directive("Attempting to create new Community",{"community":event:attr("name")})
    }
    fired{
      raise wrangler event "new_child_request"
        attributes event:attrs.put({"event_type": "manifold_create_community"})
                                .put({"rids": communityRids})
    }
  }

  rule communityCompleted {
    select when wrangler child_initialized
      where event:name == "manifold_create_community" 
    initiate_subscription(event:attr("eci"), event:attr("name"), subscription:wellKnown_Rx(){"id"}, community_role);
  }

  rule trackCommSubscription {
    select when wrangler subscription_added where event:attr("Tx_role") == community_role
    pre {
      subID = event:attr("Id");
      name = event:attr("name");
      picoID = event:attr("picoID");
      obj_structure = {
        "name": name,
        "subID": subID,
        "picoID": picoID,
        "color": "#87cefa" //default community color
      };
    }
    if subID && name && picoID then
      send_directive("Tracking subscription", { "info": obj_structure })
    fired {
      ent:communities := ent:communities.defaultsTo({}).put([picoID], obj_structure);
    }
  }

  rule removeThingSubscription {
    select when manifold remove_thing
    pre {
      picoID = event:attr("picoID");
      subID = subIDFromPicoID(picoID, ent:things).klog("found subID: ");
      sub = subscription:established("Id", subID)[0].klog("found sub: ");
    }

    if picoID && subID && sub then
      every {
        event:send({ "eci" : sub{"Tx"}, "domain" : "apps", "type" : "cleanup", "attrs" : {} }); //Jace added this event send to allow each app a chance to clean up.
        send_directive("Attempting to cancel subscription to Thing", { "thing": ent:things{[picoID, "name"]} })
      }
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Id": sub{"Id"}, "picoID": picoID, "event_type": "thing_deletion"}
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
      raise wrangler event "child_deletion"
        attributes { "id": picoID } //lowercase "id" is wrangler's way to delete a child by picoID
    }
  }

  rule removeCommunity {
    select when manifold remove_community
    pre {
      picoID = event:attr("picoID");
      subID = subIDFromPicoID(picoID, ent:things).klog("found subID: ");
      sub = subscription:established("Id", event:attr("subID"))[0].klog("found sub: ");
    }
    if picoID && subID && sub then
      send_directive("Attempting to cancel subscription to Community", {"community":event:attr("name")})
    fired{
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
      raise wrangler event "child_deletion"
        attributes { "id": picoID } //lowercase "id" is wrangler's way to delete a child by picoID
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

    if not (picoID.isnull() || changedName.isnull()) then
      send_directive("THINGS", { "things list" : ent:things });

    fired {
      ent:things := ent:things.put([picoID, "name"], changedName);
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
  
  rule createAppChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      existing_channels = wrangler:channels();
      app_channel = existing_channels.filter(function(chan){
        chan{"name"} == appChannelName && chan{"type"} == appChannelType
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
             "io.picolabs.prowl_notifications",
             "io.picolabs.twilio_notifications",
             "io.picolabs.manifold.email_notifications",
             "io.picolabs.manifold.text_message_notifications"].difference(wrangler:installedRulesets()).klog("needed") setting(rid)
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
