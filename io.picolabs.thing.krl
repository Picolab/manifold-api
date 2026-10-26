ruleset io.picolabs.thing {
  meta {
    name "Manifold thing"
    description <<
      Base ruleset for a Manifold thing pico: a trackable object or device. Accepts
      community membership, keeps community names, notifies communities of its
      events, and installs app rulesets. Installed by Manifold when it creates a
      thing.
    >>
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    shares communities
  }
  global {

    app = {"name":"thing","version":"0.0"/* img: , pre: , ..*/};

    /**
     * The communities this thing belongs to: its established relationships with
     * Tx_role community, each with the community's name and description.
     * @returns Array
     */
    communityProfileFromEci = function(eci) {
      wr = wrangler:picoQuery(eci, "io.picolabs.wrangler", "myself", {});
      wr.typeof() == "Map" && wr{"name"} => {"name": wr{"name"}} | {}
    }

    communityLinkName = function(sub, cached, pds_profile) {
      thing_nm = wrangler:myself(){"name"};
      comm_nm = pds_profile{"name"}
                  || wrangler:picoQuery(sub{"Tx"}, "io.picolabs.wrangler", "myself", {}){"name"};
      link_default = comm_nm + ":" + thing_nm;
      cached_nm = cached{"name"};
      cached_nm && cached_nm.split(re#:#).length() > 1 => cached_nm | link_default
    }

    communities = function() {
      subscription:established().filter(function(sub) {
        sub{"Tx_role"} == "community"
      }).map(function(sub) {
        cached = ent:communityInfo.defaultsTo({}){sub{"Id"}}.defaultsTo({});
        pds_profile = communityProfileFromEci(sub{"Tx"});
        name = communityLinkName(sub, cached, pds_profile);
        description = cached{"description"} || pds_profile{"description"}
                    || wrangler:picoQuery(sub{"Tx"}, "io.picolabs.community", "description", {});
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
      bus = event:attr("bus").defaultsTo({})
      isCommunity = event:attr("Tx_role") == "community"
      community_eci = event:attr("Tx")
      pds_profile = isCommunity => communityProfileFromEci(community_eci) | {}
      name = isCommunity => pds_profile{"name"}
                    || wrangler:picoQuery(community_eci, "io.picolabs.wrangler", "myself"){"name"} | null
      description = isCommunity => pds_profile{"description"}
                    || wrangler:picoQuery(community_eci, "io.picolabs.community", "description") | null
      link_name = event:attr("channel_name")
        .defaultsTo(bus{"channel_name"})
        .defaultsTo(event:attr("name"))
        .defaultsTo(bus{"name"})
        .defaultsTo(name + ":" + wrangler:myself(){"name"})
    }
    if isCommunity then noop()
    fired {
      ent:communityInfo{event:attr("Id")} := {
        "name"       : link_name,
        "description": description
      }
    }
  }

  /**
   * Send an event to this thing's communities, which receive it as
   * community:thing_event_occurred with domain, type, attrs, and this thing's id
   * as sender_id. Goes to all of them unless community_eci names one.
   * @attr domain String "domain of the event to report"
   * @attr type String "type of the event to report"
   * @attr attrs Map optional "its attributes"
   * @attr community_eci String optional "only this community (its Tx channel)"
   * @example "all communities" { "domain": "<domain>", "type": "<type>", "attrs": {} }
   * @example "one community" { "domain": "<domain>", "type": "<type>", "attrs": {}, "community_eci": "<eci>" }
   */
  rule notifyCommunity {
    select when thing community_notify
    // if community_eci is provided, notify only that community; otherwise notify all
    foreach communities().filter(function(com) {
      community_eci = event:attr("community_eci");
      community_eci.isnull() || com{"Tx"} == community_eci
    }) setting(com)
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

  /**
   * Install an app ruleset on this thing. The ruleset must be in the same
   * directory as io.picolabs.thing (the manifold-api rulesets).
   * @attr rid String "the app ruleset's id"
   * @example "SafeAndMine" { "rid": "io.picolabs.safeandmine" }
   */
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

  /**
   * Uninstall an app ruleset from this thing.
   * @attr rid String "the app ruleset's id"
   */
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
