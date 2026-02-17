ruleset io.picolabs.manifold.skills_registry {
  meta {
    description <<
      Skills registry for Manifold. Maintains a directory of skills that can
      be added to things, keyed by skill name. Each entry records the skill
      name, KRL ruleset ID, an optional ruleset URL, and a map of MCP tool
      definitions. Install on a dedicated Skills Registry pico.
    >>
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

  rule new_tool_available {
    select when manifold new_tool_available
    pre {
      name      = event:attr("name")
      tool_name = event:attr("tool_name")
      tool      = event:attr("tool")
      skill_exists = not ent:skills.defaultsTo({}){name}.isnull()
    }
    if name && tool_name && tool && skill_exists then
      send_directive("tool updated", {"skill": name, "tool_name": tool_name})
    fired {
      ent:skills := ent:skills.defaultsTo({}).put([name, "tools", tool_name], tool)
    }
  }

  rule remove_tool {
    select when manifold remove_tool
    pre {
      name      = event:attr("name")
      tool_name = event:attr("tool_name")
      tool_exists = not ent:skills.defaultsTo({}){[name, "tools", tool_name]}.isnull()
    }
    if name && tool_name && tool_exists then
      send_directive("tool removed", {"skill": name, "tool_name": tool_name})
    fired {
      ent:skills := ent:skills.defaultsTo({}).delete([name, "tools", tool_name])
    }
  }

  rule createChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName  = "skills_registry"
      eventPolicy  = {"allow": [{"domain": "manifold", "name": "new_skill_available"},
                                {"domain": "manifold", "name": "remove_skill"},
                                {"domain": "manifold", "name": "new_tool_available"},
                                {"domain": "manifold", "name": "remove_tool"}],
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
