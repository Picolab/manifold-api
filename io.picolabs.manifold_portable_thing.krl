ruleset io.picolabs.manifold_portable_thing {
  meta {
    name "Manifold portable thing"
    description <<
      Example app-layer wrapper on io.picolabs.portable_subtree for moving a thing pico
      (export blob + import under Manifold with thing RS and ent:things registration).

      Layering (follow this pattern for other mesh apps):
        portable_subtree — generic export/import (dido/wrangler); opt-in from engine /krl/
        this ruleset — Manifold-specific portable move (export hints, import registration)
        manifold_pico — unchanged; read registry via use module getThings() only

      Opt-in on Manifold (not installed at bootstrap):
        raise manifold event "enable_portable_thing"
        → installs io.picolabs.portable_subtree then this ruleset (use module order)

      Export (query on Manifold app channel):
        manifold_portable_thing:exportPortableThing(subtreeRootPicoId, secret)
        → { blob, name, donorQueryEci, subtreeRootPicoId, thingFamilyPicoID }
        name is the Manifold thing label (ent:things). subtreeRootPicoId may be any channel
        ECI on the thing (including the About tab UI ECI), family ECI, or internal pico id.
        Secret is input only — not echoed.

      Import (event on Manifold app channel):
        raise manifold event "import_portable_thing"
          attributes { "blob", "secret", "name", "donorQueryEci", "renewIngress" }
        → import_portable_thing_done (+ thingQueryEci when donorQueryEci is set)
    >>
    author "PICOLABS"

    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.manifold_pico alias manifold_pico
    use module io.picolabs.subscription alias subscription
    use module io.picolabs.portable_subtree alias portable_subtree

    shares exportPortableThing, lastImport
  }

  global {
    THING_RID = "io.picolabs.thing"
    thing_role = "manifold_thing"

    thingRulesetUrl = function() {
      parts = meta:rid_url.split("/")
      parts.splice(parts.length() - 1, 1, THING_RID + ".krl").join("/")
    }

    registeredThings = function() {
      things = manifold_pico:getThings()
      things.typeof() == "Array" => things | things.values()
    }

    thingInternalPicoId = function(familyPicoID) {
      id = wrangler:picoQuery(familyPicoID, "io.picolabs.wrangler", "id", {})
      id.typeof() == "String" => id | null
    }

    thingExportHintsFromRegistry = function(row) {
      return {
        "thingFamilyPicoID": row{"picoId"},
        "name": row{"name"},
        "donorQueryEci": row{"Tx"}
      }
    }

    thingExportHintsFromChild = function(ref, lookupRef) {
      wrangler:children()
        .filter(function(c) {
          c{"eci"} == ref
            || c{"eci"} == lookupRef
            || thingInternalPicoId(c{"eci"}) == lookupRef
        })
        .map(function(c) {
          return {
            "thingFamilyPicoID": c{"eci"},
            "name": c{"name"},
            "donorQueryEci": null
          }
        })
        .head()
        .defaultsTo({})
    }

    /**
     * Manifold import hints for a thing export ref (any channel ECI, family ECI, or internal id).
     * name — human label from getThings() / ent:things, not wrangler id.
     */
    thingExportHints = function(ref) {
      internal = wrangler:picoQuery(ref, "io.picolabs.wrangler", "id", {})
      lookupRef = internal.typeof() == "String" => internal | ref
      row = registeredThings()
        .filter(function(r) {
          r{"picoId"} == ref
            || r{"picoId"} == lookupRef
            || thingInternalPicoId(r{"picoId"}) == lookupRef
        })
        .head()
      row.isnull() == false => thingExportHintsFromRegistry(row)
        | thingExportHintsFromChild(ref, lookupRef)
    }

    exportPortableThing = function(subtreeRootPicoId, secret) {
      blob = portable_subtree:exportSubtree(subtreeRootPicoId, secret)
      hints = thingExportHints(subtreeRootPicoId)
      return {
        "blob": blob,
        "subtreeRootPicoId": subtreeRootPicoId,
        "thingFamilyPicoID": hints{"thingFamilyPicoID"},
        "name": hints{"name"},
        "donorQueryEci": hints{"donorQueryEci"}
      }
    }

    lastImport = function() {
      ent:lastImport
    }

    __testing = {
      "queries": [
        {"name": "exportPortableThing", "args": ["subtreeRootPicoId", "secret"]},
        {"name": "lastImport"}
      ],
      "events": [
        {
          "domain": "manifold",
          "name": "import_portable_thing",
          "attrs": ["blob", "secret", "name", "donorQueryEci", "renewIngress"]
        }
      ]
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
