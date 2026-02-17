ruleset io.picolabs.manifold.skill_directory {
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares getSkills
  }
  global {

    // Returns a single skill by name, or the full skills map if no name given.
    // Each skill entry has: name, rid, tools (map of MCP tool defs), and optional url.
    getSkills = function(name) {
      (name) => ent:skills.defaultsTo({}){name}
              | ent:skills.defaultsTo({})
    }

  }

  rule new_skill_available {
    select when manifold new_skill_available
    pre {
      name  = event:attr("name")
      rid   = event:attr("rid")
      url   = event:attr("url")
      tools = event:attr("tools").defaultsTo({})
      skill_base = {
        "name"  : name,
        "rid"   : rid,
        "tools" : tools
      }
      skill = url => skill_base.put("url", url) | skill_base
    }
    if name && rid then
      send_directive("skill registered", {"skill": skill})
    fired {
      ent:skills := ent:skills.defaultsTo({}).put([name], skill)
    }
  }

  rule remove_skill {
    select when manifold remove_skill
    pre {
      name   = event:attr("name")
      exists = not ent:skills.defaultsTo({}){name}.isnull()
    }
    if name && exists then
      send_directive("skill removed", {"name": name})
    fired {
      ent:skills := ent:skills.defaultsTo({}).delete([name])
    }
  }

  rule createChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName  = "skill_directory"
      eventPolicy  = {"allow": [{"domain": "manifold", "name": "new_skill_available"},
                                {"domain": "manifold", "name": "remove_skill"}],
                      "deny":  []}
      queryPolicy  = {"allow": [{"rid": meta:rid, "name": "getSkills"}],
                      "deny":  []}
      existing     = wrangler:channels()
      app_channel  = existing.filter(function(chan) { chan{"name"} == channelName })
      channel_exists = app_channel.length() > 0
    }
    if not channel_exists then
      wrangler:createChannel([channelName], eventPolicy, queryPolicy) setting(channel)
    fired {
      ent:directory_channel_eci := channel{"id"}
    }
  }

}
