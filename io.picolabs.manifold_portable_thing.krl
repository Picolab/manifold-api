ruleset io.picolabs.manifold_portable_thing {
  meta {
    name "Manifold portable thing"
    description <<
      Example app-layer wrapper on io.picolabs.portable_subtree for moving a thing pico
      (export blob + import under Manifold with thing RS and ent:things registration).

      Layering (follow this pattern for other mesh apps):
        portable_subtree — generic export/import (dido/wrangler); opt-in from engine /krl/
        this ruleset — Manifold-specific registration only (subscription, thing RS)

      Opt-in on Manifold (not installed at bootstrap):
        raise manifold event "enable_portable_thing"
        → installs io.picolabs.portable_subtree then this ruleset (use module order)

      Export (query on Manifold app channel):
        manifold_portable_thing:exportPortableThing(subtreeRootPicoId, secret)
        → { blob, name, donorQueryEci, subtreeRootPicoId, thingFamilyPicoID }
        (secret is input only — not echoed.) Use name / donorQueryEci on import when helpful.

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

    thingRegistryRowByFamily = function(subtreeRootPicoId) {
      manifold_pico:getThings()
        .filter(function(row) { row{"picoId"} == subtreeRootPicoId })
        .head()
    }

    childToExportContext = function(child) {
      family = child{"eci"}
      reg = manifold_pico:getThings()
        .filter(function(row) { row{"picoId"} == family })
        .head()
      donor_q = reg{"Tx"}.defaultsTo(
        subscription:established("Id", reg{"subID"}).head(){"Tx"}
      )
      return {
        "thingFamilyPicoID": family,
        "name": reg{"name"}.defaultsTo(child{"name"}),
        "donorQueryEci": donor_q
      }
    }

    thingExportContextByInternalId = function(subtreeRootPicoId) {
      wrangler:children()
        .filter(function(c) {
          wrangler:picoQuery(c{"eci"}, "io.picolabs.wrangler", "id", {})
            == subtreeRootPicoId
        })
        .map(function(child) { childToExportContext(child) })
        .head()
        .defaultsTo({})
    }

    /** Resolve Manifold registry + donor query channel for a thing export. */
    thingExportContext = function(subtreeRootPicoId) {
      byFamily = thingRegistryRowByFamily(subtreeRootPicoId)
      byFamily.isnull() == false => {}.put("thingFamilyPicoID", byFamily{"picoId"})
        .put("name", byFamily{"name"})
        .put("donorQueryEci", byFamily{"Tx"})
        | thingExportContextByInternalId(subtreeRootPicoId)
    }

    exportPortableThing = function(subtreeRootPicoId, secret) {
      blob = portable_subtree:exportSubtree(subtreeRootPicoId, secret)
      ctx = thingExportContext(subtreeRootPicoId)
      family = ctx{"thingFamilyPicoID"}
      name = ctx{"name"}.defaultsTo(
        family.isnull() => null |
        wrangler:picoQuery(family, "io.picolabs.wrangler", "name", {})
      )
      return {
        "blob": blob,
        "subtreeRootPicoId": subtreeRootPicoId,
        "thingFamilyPicoID": family,
        "name": name,
        "donorQueryEci": ctx{"donorQueryEci"}
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
