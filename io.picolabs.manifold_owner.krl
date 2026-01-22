ruleset io.picolabs.manifold_owner {
  meta {
    use module io.picolabs.subscription alias Subscriptions
    use module io.picolabs.wrangler alias wrangler
    shares __testing, getManifoldPico
  }
  global {

    config={"pico_name" : "Manifold", 
            "URI" : ["io.picolabs.manifold_pico.krl"], 
            "channel_type":"App"
          };

    getManifoldPico = function(){
      children = wrangler:children().filter(function(x) {
        x{"name"} == config{"pico_name"}
      });
      children.length() > 0 => children[0].klog("child") | "No Manifold Pico"
    }
    
    getManifoldEci = function(channels){
      manifolds = channels.filter(function(chan){
                    chan{"name"} == config{"pico_name"} && chan{"type"} == config{"channel_type"}
                  });
      manifolds.head(){"eci"} || "";
    }
    
    getManifoldEciFromChild = function(child){
      channels = wrangler:skyQuery(child{"eci"}, "io.picolabs.wrangler", "channels", {});
      channels.isnull() => null | getManifoldEci(channels)
    }
  } //end global

  rule manifold_needed {
    select when manifold channel_needed
    pre {
      child = getManifoldPico();
    }
    if child == "No Manifold Pico" then every {
      send_directive("manifold still being created",{})
    }fired{last}
  }

  rule new_channel_check {
    select when manifold channel_needed
    pre {
      child = getManifoldPico();
      eci = getManifoldEciFromChild(child);
    }
    if not eci && child != "No Manifold Pico" then every {
      send_directive("manifold channel not found", {
        "message": "Channel will be created by manifold_pico initialization"
      })
    }
    fired {
      last
    }
  }
  rule return_existing_channel {
    select when manifold channel_needed
    pre {
      child = getManifoldPico();
      eci = getManifoldEciFromChild(child);
    }
    if eci then
      send_directive("manifold channel", {
        "eci": eci.klog("manifold eci:")
      })
    fired {
      last
    }
  }
  rule initialization {
    select when wrangler ruleset_installed where event:attr("rids").klog("rids") >< ctx:rid.klog("meta rid")
    pre {
      manifoldPico =  getManifoldPico()
    }
    if manifoldPico == "No Manifold Pico" then
      noop()
    fired {
      raise wrangler event "name_changed"
        attributes { "name": "owner" };
      raise wrangler event "new_child_request"
        attributes { "name": config{"pico_name"}, "color": "#7FFFD4", "event_type": "manifold_create_owner" }
    }
  }

   rule createChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName = "initialization"
      eventPolicy = {"allow": [], "deny": [{"domain": "*", "name": "*"}]}
      queryPolicy = {"allow":[{"rid": meta:rid, "name": "getManifoldPico"}], "deny": []}
      existing_channels = wrangler:channels();
      app_channel = existing_channels.filter(function(chan){
        chan{"name"} == channelName 
      });
      channel_exists = app_channel.length() > 0;
    }
    if not channel_exists then
      wrangler:createChannel([channelName], eventPolicy, queryPolicy) setting(channel)
    fired {
      ent:init_channel_eci := channel{"id"}
    }
  }

  rule install_manifold_pico_ruleset {
    select when wrangler child_initialized where event:attr("event_type") == "manifold_create_owner"
    pre {
      child = getManifoldPico().klog("returned Child")
      child_eci = child != "No Manifold Pico" => child{"eci"}.klog("ECI") | null
      absoluteURL = meta:rulesetURI;
    }
    if child_eci && absoluteURL then
      event:send({
        "eci": child_eci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": { 
          "rid": "io.picolabs.manifold_pico",
          "absoluteURL": absoluteURL
        }
      })
  }

}
