ruleset io.picolabs.manifold_import {
  meta {
    name "Manifold portable import"
    description <<
      Imports a portable subtree under the Manifold pico (io.picolabs.portable_subtree /
      dido:importPortableSubtree), then registers the thing in ent:things like create_thing.

      raise manifold event "import_portable_thing"
        attributes { "blob", "secret", "name", "donorQueryEci", "renewIngress" }
      → import_portable_thing_done (+ thingQueryEci when donorQueryEci is set)
    >>
    author "PICOLABS"

    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription

    shares lastImport
  }

  global {
    PORTABLE_SUBTREE_RID = "io.picolabs.portable_subtree"
    THING_RID = "io.picolabs.thing"
    thing_role = "manifold_thing"

    __testing = {
      "queries": [{"name": "lastImport"}],
      "events": [
        {
          "domain": "manifold",
          "name": "import_portable_thing",
          "attrs": ["blob", "secret", "name", "donorQueryEci", "renewIngress"]
        }
      ]
    }

    portableSubtreeUrl = function() {
      meta:host + "/krl/io.picolabs.portable_subtree.krl"
    }

    thingRulesetUrl = function() {
      parts = meta:rid_url.split("/")
      parts.splice(parts.length() - 1, 1, THING_RID + ".krl").join("/")
    }

    lastImport = function() {
      ent:lastImport
    }
  }

  rule install_portable_subtree {
    select when wrangler ruleset_installed
      where event:attr("rids") >< meta:rid
    pre {
      installed = wrangler:installedRIDs()
      url = portableSubtreeUrl()
    }
    if not (installed >< PORTABLE_SUBTREE_RID) then every {
      ctx:flush(url=url)
      ctx:install(url=url, config={}) setting(rid)
    }
  }

  rule import_portable_thing {
    select when manifold import_portable_thing
      blob re#.+#
      secret re#.+#
    pre {
      blob = event:attr("blob")
      secret = event:attr("secret")
      options = {
        "name": event:attr("name"),
        "donorQueryEci": event:attr("donorQueryEci"),
        "renewIngress": event:attr("renewIngress").defaultsTo(true),
        "parentChannelEci": event:eci
      }
      import_result = dido:importPortableSubtree(
        blob,
        secret,
        {
          "renewIngress": options{"renewIngress"},
          "parentChannelEci": options{"parentChannelEci"}
        }
      )
      familyEci = import_result{"newRootEci"}
      installed = wrangler:picoQuery(
        familyEci,
        "io.picolabs.wrangler",
        "installedRIDs",
        {}
      )
      thing_name = options{"name"}.defaultsTo(
        wrangler:picoQuery(familyEci, "io.picolabs.wrangler", "name", {})
      )
      wellKnown = subscription:wellKnown_Rx(){"id"}
      donor_q = options{"donorQueryEci"}
      thing_query_eci = donor_q.isnull() => null
        | import_result{"eciMap"}{donor_q}
      enrichedResult = import_result.put("thingQueryEci", thing_query_eci)
    }
    every {
      event:send({
        "eci": familyEci,
        "domain": "wrangler",
        "type": "install_ruleset_request",
        "attrs": {
          "rid": THING_RID,
          "absoluteURL": thingRulesetUrl()
        }
      })
      event:send({
        "eci": familyEci,
        "eid": "subscription",
        "domain": "wrangler",
        "type": "subscription",
        "attrs": {
          "name": thing_name,
          "picoID": familyEci,
          "Rx_role": thing_role,
          "Tx_role": "manifold_pico",
          "Tx_Rx_Type": "Manifold",
          "channel_type": "Manifold",
          "wellKnown_Tx": wellKnown,
          "Tx_host": meta:host
        }
      })
    }
    fired {
      ent:lastImport := enrichedResult
      raise manifold event "import_portable_thing_done" attributes enrichedResult
    }
  }
}
