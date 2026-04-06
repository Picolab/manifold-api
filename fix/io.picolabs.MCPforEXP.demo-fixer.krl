ruleset io.picolabs.MCPforEXP.demo-fixer.krl {
  meta {
    use module io.picolabs.manifold_pico alias manifold
  }
  rule trackThingSubscription {
    select when wrangler subscription_added
          where event:attr("Tx_role") == "manifold_thing"
    fired {
      ent:latestThingPico := event:attr("picoID")
    }
  }
  rule trackThingDeletion {
    select when wrangler subscription_removed
          where event:attr("event_type") == "thing_deletion"
    fired {
      clear ent:latestThingPico
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
  rule initialize {
    select when wrangler ruleset_installed
          where event:attr("rids") >< meta:rid
    pre {
      tags = "demo-fixer"
    }
    if wrangler:channels(tags).length() == 0 then
      wrangler:createChannel(
        tags,
        {"allow":[{"domain":"demo_fixer","name":"*"}],"deny":[]},
        {"allow":[{"rid":meta:rid,"name":"*"}],"deny":[]}
      ) setting(channel)
  }
}
