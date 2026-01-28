ruleset io.picolabs.manifold_owner {
  meta {
    use module io.picolabs.subscription alias Subscriptions
    use module io.picolabs.wrangler alias wrangler
    shares getManifoldPico, getManifoldPicoEci, getTagServer
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
      children.length() > 0 => children[0].klog("Manifold Pico") 
                             | "No Manifold Pico"
    }

     getManifoldPicoEci = function(){
      children = wrangler:children().filter(function(x) {
        x{"name"} == config{"pico_name"}
      });
      children.length() > 0 => getManifoldEciFromChild(children[0].klog("Manifold Pico")).klog("Manifold ECI") 
                             | "No Manifold Pico"
    }
    
    //deprecate? 
    getManifoldEci = function(channels){
      manifolds = channels.filter(function(chan){
                    chan{"name"} == "manifold" && chan{"type"} == config{"channel_type"}
                  });
      manifolds.head(){"eci"} || "";
    }
    
    getManifoldEciFromChild = function(child){
      channels = wrangler:picoQuery(child{"eci"}, "io.picolabs.wrangler", "channels", {"tags": "manifold"}).klog("Channels");
      channels.isnull() => null | channels.head(){"id"}
    }


    getTagServer = function() {
      ent:tag_pico
    }
  } //end global

  rule configure_tag_server {
    select when manifold new_tag_server
    noop()
    always {
      ent:tag_pico := {"eci": event:attrs{"eci"},
                       "host_url": event:attrs{"host_url"} || meta:host
                      };
    }
  }

  rule manifold_needed {
    select when manifold channel_needed
    pre {
      child = getManifoldPico();
    }
    if child == "No Manifold Pico" then every {
      send_directive("manifold still being created",{})
    } fired{last}
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
      raise wrangler event "new_child_request"
        attributes { "name": config{"pico_name"}, "color": "#7FFFD4", "event_type": "manifold_create_owner" }
    }
  }

   rule createChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName = "initialization"
      eventPolicy = {"allow": [{"domain": "manifold", "name": "new_tag_server"}], "deny": []}
      queryPolicy = {"allow":[{"rid": meta:rid, "name": "getManifoldPico"},
                              {"rid": meta:rid, "name": "getManifoldPicoEci"},
                              {"rid": meta:rid, "name": "getTagServer"}
                             ], "deny": []}
      existing_channels = wrangler:channels().klog("Current channels");
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
