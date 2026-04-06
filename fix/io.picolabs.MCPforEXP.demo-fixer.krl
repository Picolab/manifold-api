ruleset io.picolabs.MCPforEXP.demo-fixer.krl {
  meta {
    use io.picolabs.manifold_pico as module alias manifold
  }
  rule trackThingSubscription {
    select when wrangler subscription_added
      where event:attr("Tx_role") == "manifold_thing"
    fired {
      ent:latestThingPico := event:attr("picoID")
    }
  }
  rule fixThingPosition {
    select when demo_fixer fix_requested
      where not ent:latestThingPico.isnull()
    event:send({
          "eci": ent:latestThingPico, 
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
