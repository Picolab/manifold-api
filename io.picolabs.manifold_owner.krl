ruleset io.picolabs.manifold_owner {
  meta {
    name "Manifold owner"
    description <<
      Represents the human owner of a Manifold mesh. Installed on the Owner pico (a
      child of the root) with io.picolabs.profile. On install it creates the
      Manifold child pico and installs io.picolabs.manifold_pico there. Holds the
      tag-server configuration and the owner's LLM context.
    >>
    use module io.picolabs.subscription alias Subscriptions
    use module io.picolabs.wrangler alias wrangler
    shares getManifoldPico, getManifoldPicoEci, getTagServer, getLLMContext
  }
  global {

    config={"pico_name" : "Manifold", 
            "URI" : ["io.picolabs.manifold_pico.krl"], 
            "channel_type":"App"
          };

    /**
     * The owner's Manifold child pico ({ eci, name, parent_eci }), or the string
     * "No Manifold Pico" if it hasn't been created yet.
     * @returns Any
     */
    getManifoldPico = function(){
      children = wrangler:children().filter(function(x) {
        x{"name"} == config{"pico_name"}
      });
      children.length() > 0 => children[0].klog("Manifold Pico") 
                             | "No Manifold Pico"
    }

     /**
      * The ECI of the Manifold pico's manifold channel, for sending manifold events
      * to it; "No Manifold Pico" if it doesn't exist yet, null if the channel isn't
      * there yet.
      * @returns String
      */
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


    /**
     * The tag registry things use for NFC/QR tags, as set by manifold:new_tag_server.
     * @returns Map "{ eci, host_url }"
     */
    getTagServer = function() {
      ent:tag_pico
    }

    /**
     * Context stored for language-model assistants working with this mesh (set with
     * manifold:updated_context); {} if none.
     * @returns Map
     */
    getLLMContext = function() {
      ent:llm_context.defaultsTo({})
    }
  } //end global

  /**
   * Store context for language-model assistants working with this mesh, replacing
   * what was there. Read it back with getLLMContext().
   * @attr context Map "the context to store"
   * @example "store" { "context": { "<key>": "<value>" } }
   */
  rule store_llm_context {
    select when manifold updated_context
    pre {
      context = event:attr("context")
    }
    if context then
      send_directive("llm context stored", {})
    fired {
      ent:llm_context := context
    }
  }

  /**
   * Set the tag registry things use for NFC/QR tags. Bootstrap does this with the
   * tag registry's registration channel; it must happen before things register tags.
   * @attr eci String "the tag registry's registration channel"
   * @attr host_url String optional "the tag registry's engine URL (default: this engine)"
   * @example "same engine" { "eci": "<registration eci>" }
   */
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
  /**
   * Ask for the Manifold pico's manifold channel. The response directive says
   * which: "manifold channel" with eci when it exists; "manifold still being
   * created" or "manifold channel not found" while bootstrap is still running.
   * The first rule that applies answers (the others stop with last).
   */
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

  rule createUpdateChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName = "updates"
      eventPolicy = {"allow": [{"domain": "manifold", "name": "updated_context"},
                               {"domain": "profile",  "name": "*"}],
                     "deny":  []}
      queryPolicy = {"allow": [{"rid": meta:rid,              "name": "getLLMContext"},
                               {"rid": "io.picolabs.profile", "name": "getProfile"},
                               {"rid": "io.picolabs.profile", "name": "getEmail"},
                               {"rid": "io.picolabs.profile", "name": "getPhone"},
                               {"rid": "io.picolabs.profile", "name": "getOwnerPhone"},
                               {"rid": "io.picolabs.profile", "name": "getOwnerEmail"}],
                     "deny":  []}
      existing     = wrangler:channels()
      app_channel  = existing.filter(function(chan) { chan{"name"} == channelName })
      channel_exists = app_channel.length() > 0
    }
    if not channel_exists then
      wrangler:createChannel([channelName], eventPolicy, queryPolicy) setting(channel)
    fired {
      ent:updated_channel_eci := channel{"id"}
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
