ruleset io.picolabs.manifold_bootstrap {
  meta {
    description <<
      Manifold bootstrap automation. Install this ruleset on the root pico to
      automatically perform the full Manifold bootstrap sequence:
      1) Create a tag registry child pico and install io.picolabs.new_tag_registry.
      2) Create an owner child pico and install io.picolabs.profile and io.picolabs.manifold_owner
         (which in turn creates the Manifold child and installs io.picolabs.manifold_pico).
      3) Register the tag registry's registration ECI with the owner by raising
         manifold:new_tag_server on the owner, so things can use the tag registry.
      4) Create a skills registry child pico and install io.picolabs.manifold.skills_registry,
         providing a queryable directory of skills (with MCP tool definitions) that can
         be added to things.
      All steps follow the bootstrap architecture described in the Manifold-api README.
    >>
    use module io.picolabs.wrangler alias wrangler
    shares getBootstrapStatus
  }

  global {
    tag_registry_name = "Tag Registry"
    owner_name = "Owner"
    skills_registry_name = "Skills Registry"
    init_event_type_tag_registry = "manifold_init_tag_registry"
    init_event_type_owner = "manifold_init_owner"
    init_event_type_skills_registry = "manifold_init_skills_registry"

    getBootstrapStatus = function() {
      {
        "tag_registry_eci": ent:tag_registry_eci,
        "tag_registry_registration_eci": ent:tag_registry_registration_eci,
        "owner_eci": ent:owner_eci,
        "skills_registry_eci": ent:skills_registry_eci
      }
    }
  }

  rule createChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName = "bootstrap"
      eventPolicy = {"allow": [], "deny": []}
      queryPolicy = {"allow": [{"rid": meta:rid, "name": "getBootstrapStatus"}], "deny": []}
      existing_channels = wrangler:channels();
      app_channel = existing_channels.filter(function(chan) {
        chan{"name"} == channelName
      });
      channel_exists = app_channel.length() > 0;
    }
    if not channel_exists then
      wrangler:createChannel([channelName], eventPolicy, queryPolicy) setting(channel)
    fired {
      ent:bootstrap_channel_eci := channel{"id"}
    }
  }

  // ---- Step 0: When this ruleset is installed on the root pico, create the tag registry child ----
  rule start_bootstrap {
    select when wrangler ruleset_installed
      where event:attr("rids") >< ctx:rid 
    pre {
      children = wrangler:children();
      tag_registry_exists = children.any(function(c) { c{"name"} == tag_registry_name });
    }
    if not tag_registry_exists then
      send_directive("manifold_init_started", {"step": "creating_tag_registry"})
    fired {
      raise wrangler event "new_child_request"
        attributes {
          "name": tag_registry_name,
          "color": "#FFE4B5",
          "event_type": init_event_type_tag_registry
        }
    }
  }

  // ---- Step 1a: When tag registry child is created, install new_tag_registry on it ----
  rule install_tag_registry_ruleset {
    select when wrangler child_initialized
      where event:attr("event_type") == init_event_type_tag_registry
    pre {
      eci = event:attr("eci");
      absoluteURL = meta:rulesetURI;
    }
    if eci && absoluteURL then
      event:send({
        "eci": eci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": {
          "rid": "io.picolabs.new_tag_registry",
          "absoluteURL": absoluteURL
        }
      })
    fired {
      ent:tag_registry_eci := eci;
      schedule manifold_init event "get_registration_eci" at time:add(time:now(), {"seconds": 2})
        attributes { "eci": eci }
    }
  }

  // ---- Step 1b: After tag registry has ruleset (and channel), get registration ECI and create owner ----
  rule get_registration_eci_and_create_owner {
    select when manifold_init get_registration_eci
    pre {
      tag_eci = event:attr("eci").defaultsTo(ent:tag_registry_eci);
      channels = tag_eci => wrangler:picoQuery(tag_eci, "io.picolabs.wrangler", "channels", {"tags": "registration"}) | [];
      reg_channel = channels.head();
      registration_eci = reg_channel => reg_channel{"id"} | null;
      children = wrangler:children();
      owner_exists = children.any(function(c) { c{"name"} == owner_name });
    }
    if registration_eci && not owner_exists then
      send_directive("manifold_init_step", {"step": "creating_owner"})
    fired {
      ent:tag_registry_registration_eci := registration_eci;
      raise wrangler event "new_child_request"
        attributes {
          "name": owner_name,
          "color": "#7FFFD4",
          "event_type": init_event_type_owner
        }
    }
  }

  // ---- Skills Registry: create pico and install skills_registry ruleset (independent of owner steps) ----
  rule create_skills_registry {
    select when wrangler ruleset_installed
      where event:attr("rids") >< ctx:rid
    pre {
      children = wrangler:children();
      skills_registry_exists = children.any(function(c) { c{"name"} == skills_registry_name });
    }
    if not skills_registry_exists then
      send_directive("manifold_init_started", {"step": "creating_skills_registry"})
    fired {
      raise wrangler event "new_child_request"
        attributes {
          "name": skills_registry_name,
          "color": "#B0E0E6",
          "event_type": init_event_type_skills_registry
        }
    }
  }

  rule install_skills_registry_ruleset {
    select when wrangler child_initialized
      where event:attr("event_type") == init_event_type_skills_registry
    pre {
      eci = event:attr("eci");
      absoluteURL = meta:rulesetURI;
    }
    if eci && absoluteURL then
      event:send({
        "eci": eci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": {
          "rid": "io.picolabs.manifold.skills_registry",
          "absoluteURL": absoluteURL
        }
      })
    fired {
      ent:skills_registry_eci := eci
    }
  }

  // ---- Step 2: When owner child is created, install profile and manifold_owner, then register tag server ----
  rule setup_owner_pico {
    select when wrangler child_initialized
      where event:attr("event_type") == init_event_type_owner
    pre {
      owner_eci = event:attr("eci");
      registration_eci = ent:tag_registry_registration_eci;
    }
    if owner_eci && meta:rulesetURI then every {
      send_directive("manifold_init_step", {"step": "installing_owner_rulesets"});
      event:send({
        "eci": owner_eci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": {
          "rid": "io.picolabs.profile",
          "absoluteURL": meta:rulesetURI
        }
      });
      event:send({
        "eci": owner_eci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": {
          "rid": "io.picolabs.manifold_owner",
          "absoluteURL": meta:rulesetURI
        }
      });
      event:send({
        "eci": owner_eci,
        "domain": "manifold",
        "type": "new_tag_server",
        "attrs": {
          "eci": registration_eci,
          "host_url": meta:host
        }
      })
    }
    fired {
      ent:owner_eci := owner_eci
    }
  }
}
