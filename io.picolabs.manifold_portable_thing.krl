ruleset io.picolabs.manifold_portable_thing {
  meta {
    name "Manifold portable thing"
    description <<
      Example app-layer wrapper on io.picolabs.portable_subtree for moving a thing pico
      (export blob + import under Manifold with thing RS and ent:things registration).

      Layering (follow this pattern for other mesh apps):
        portable_subtree — generic export/import (dido/wrangler); parent installs from engine /krl/
        this ruleset — Manifold-specific registration only (subscription, thing RS)
        (manifold_pico installs portable_subtree before this RS — required for use module)

      Export (query on a pico that has portable_subtree, typically the thing or an ancestor):
        manifold_portable_thing:exportPortableThing(subtreeRootPicoId, secret)

      Export (event on Manifold app channel):
        raise manifold event "export_portable_thing"
          attributes { "subtreeRootPicoId", "secret" }
        → export_portable_thing_done { "blob" }

      Import (event on Manifold app channel):
        raise manifold event "import_portable_thing"
          attributes { "blob", "secret", "name", "donorQueryEci", "renewIngress" }
        → import_portable_thing_done (+ thingQueryEci when donorQueryEci is set)
    >>
    author "PICOLABS"

    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    use module io.picolabs.portable_subtree alias portable_subtree

    shares exportPortableThing, lastExport, lastImport
  }

  global {
    THING_RID = "io.picolabs.thing"
    thing_role = "manifold_thing"

    thingRulesetUrl = function() {
      parts = meta:rid_url.split("/")
      parts.splice(parts.length() - 1, 1, THING_RID + ".krl").join("/")
    }

    /** Pass-through to portable_subtree (read-only). */
    exportPortableThing = function(subtreeRootPicoId, secret) {
      portable_subtree:exportSubtree(subtreeRootPicoId, secret)
    }

    lastExport = function() {
      ent:lastExport
    }

    lastImport = function() {
      ent:lastImport
    }

    __testing = {
      "queries": [
        {"name": "exportPortableThing", "attrs": ["subtreeRootPicoId", "secret"]},
        {"name": "lastExport"},
        {"name": "lastImport"}
      ],
      "events": [
        {
          "domain": "manifold",
          "name": "export_portable_thing",
          "attrs": ["subtreeRootPicoId", "secret"]
        },
        {
          "domain": "manifold",
          "name": "import_portable_thing",
          "attrs": ["blob", "secret", "name", "donorQueryEci", "renewIngress"]
        }
      ]
    }
  }

  rule export_portable_thing {
    select when manifold export_portable_thing
      subtreeRootPicoId re#.+#
      secret re#.+#
    pre {
      subtreeRootPicoId = event:attr("subtreeRootPicoId")
      secret = event:attr("secret")
      blob = exportPortableThing(subtreeRootPicoId, secret)
      exportRecord = {
        "subtreeRootPicoId": subtreeRootPicoId,
        "blob": blob
      }
    }
    fired {
      ent:lastExport := exportRecord
      raise manifold event "export_portable_thing_done" attributes exportRecord
    }
  }

  rule import_portable_thing {
    select when manifold import_portable_thing
      blob re#.+#
      secret re#.+#
    fired {
      ent:pendingImport := {
        "name": event:attr("name"),
        "donorQueryEci": event:attr("donorQueryEci")
      }
      raise portable_subtree event "import"
        attributes {
          "blob": event:attr("blob"),
          "secret": event:attr("secret"),
          "renewIngress": event:attr("renewIngress").defaultsTo(true)
        }
    }
  }

  rule register_imported_portable_thing {
    select when portable_subtree imported
    pre {
      pending = ent:pendingImport
      import_result = event:attrs
      familyEci = import_result{"newRootEci"}
      thing_name = pending{"name"}.defaultsTo(
        wrangler:picoQuery(familyEci, "io.picolabs.wrangler", "name", {})
      )
      wellKnown = subscription:wellKnown_Rx(){"id"}
      donor_q = pending{"donorQueryEci"}
      thing_query_eci = donor_q.isnull() => null
        | import_result{"eciMap"}{donor_q}
      enrichedResult = import_result.put("thingQueryEci", thing_query_eci)
    }
    if not pending.isnull() then every {
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
    } fired {
      ent:pendingImport := null
      ent:lastImport := enrichedResult
      raise manifold event "import_portable_thing_done" attributes enrichedResult
    }
  }
}
