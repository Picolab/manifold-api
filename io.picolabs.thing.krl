ruleset io.picolabs.thing {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    shares communities
  }
  global {

    app = {"name":"thing","version":"0.0"/* img: , pre: , ..*/};

    communities = function() {
      subscription:established().filter(function(sub) {
        sub{"Tx_role"} == "community"
      }).map(function(sub) {
        cached = ent:communityInfo.defaultsTo({}){sub{"Id"}}.defaultsTo({});
        name = cached{"name"} || wrangler:skyQuery(sub{"Tx"}, "io.picolabs.wrangler", "myself"){"name"};
        description = cached{"description"} || wrangler:skyQuery(sub{"Tx"}, "io.picolabs.community", "description");
        sub.put(cached).put({"name": name, "description": description})
      })
    }

  }

  //rule discovery { select when manifold apps send_directive("app discovered...", {"app": app, "rid": meta:rid, "bindings": bindings(), "iconURL": "https://cdn0.iconfinder.com/data/icons/app-pack-1-musket-monoline/32/app-22-cog-512.png"} ); }

  rule autoAcceptCommunity {
    select when wrangler inbound_pending_subscription_added
    pre {
      attrs = event:attrs
    }
    if attrs{"Rx_role"} == "community" then
    noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes attrs
    }
  }

  rule communityRemoved {
    select when wrangler subscription_removed
    pre {
      id = event:attr("Id")
    }
    if not ent:communityInfo.defaultsTo({}){id}.isnull() then noop()
    fired {
      ent:communityInfo := ent:communityInfo.filter(function(v,k) { k != id })
    }
  }

  rule communityAdded {
    select when wrangler subscription_added
    pre {
      isCommunity = event:attr("Tx_role") == "community"
      community_eci = event:attr("Tx")
      name = isCommunity => wrangler:skyQuery(community_eci, "io.picolabs.wrangler", "myself"){"name"} | null
      description = isCommunity => wrangler:skyQuery(community_eci, "io.picolabs.community", "description") | null
    }
    if isCommunity then noop()
    fired {
      ent:communityInfo{event:attr("Id")} := {
        "name"       : name,
        "description": description
      }
    }
  }

  rule notifyCommunity {
    select when thing community_notify
    foreach communities() setting(com)
    pre {
      domain = event:attr("domain")
      type = event:attr("type")
      attrs = event:attr("attrs")
      sender_id = wrangler:myself(){"id"}
    }
    event:send({
      "eci": com{"Tx"}, "eid": "thing_to_community",
      "domain": "community", "type": "thing_event_occurred",
      "attrs": { "domain": domain, "type": type, "attrs": attrs, "sender_id": sender_id }
    })
  }

  rule initialization {
    select when wrangler ruleset_installed where event:attr("rids").klog("rids") >< ctx:rid.klog("meta rid")
    pre {
        absoluteURL = meta:rulesetURI;
    }
    if absoluteURL then noop();
    fired{
      raise wrangler event "install_ruleset_request"
      attributes {
        "rid" : "io.picolabs.safeandmine",
        "absoluteURL": absoluteURL // getting this from the same repo as this ruleset
      }
    }
  }

  rule installApp {
    select when manifold installapp
    pre {
        absoluteURL = meta:rulesetURI;
    }
    if absoluteURL then noop()
    fired{
      raise wrangler event "install_ruleset_request"
       attributes {
        "rid" : event:attr("rid"),
        "absoluteURL": absoluteURL // getting this from the same repo as this ruleset
      }
    }
  }

  rule uninstallApp {
    select when manifold uninstallapp
    pre {}
    noop();
    fired {
      raise wrangler event "uninstall_ruleset_request"
        attributes {
          "rid" : event:attr("rid")
        }
    }
  }


}//end ruleset
