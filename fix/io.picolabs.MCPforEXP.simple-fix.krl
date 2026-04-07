ruleset io.picolabs.MCPforEXP.simple-fix {
  meta {
    use module io.picolabs.manifold_pico
  }
  rule move_new_thing_pico {
    select when wrangler child_initialized
          where event:attr("event_name") == "manifold_create_thing"
      event:send({
          "eci": event:attr("eci"), 
          "eid": "fix",
          "domain": "engine_ui", 
          "type": "box",
          "attrs": {
            "x": 192,
            "y": 486,
            "width": 120,
            "height": 100,
          }
        })
  }
}
