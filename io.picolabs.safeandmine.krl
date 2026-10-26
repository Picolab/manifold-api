ruleset io.picolabs.safeandmine {
  meta {
    name "SafeAndMine"
    description <<
      Electronic name tag for a Manifold thing. Register QR or NFC tags on the
      thing, set owner contact information, and let finders scan a tag to see
      how to return the item. You receive a notification when a tag is scanned.
    >>
    author "Pico Labs"

    shares getInformation, getTags
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias sub
    use module io.picolabs.pds alias pds
  }
  global {

    safeandmine_ns = "safeandmine"

    /**
     * The owner contact information shown to someone who scans this thing's tag:
     * name, email, phone, message, and shareName / sharePhone / shareEmail flags.
     * With info, just that field.
     * @param info String "one field; omit for all"
     * @returns Any
     * @example "all" {}
     * @example "message" { "info": "message" }
     */
    getInformation = function(info = null) {
      data = pds:items(safeandmine_ns, "contact"){"general"}.defaultsTo({});
      info => data{info} | data
    }
    
    /**
     * Tags registered on this thing: tag IDs by domain.
     * @returns Map "{ <domain>: [tagID, …] }"
     */
    getTags = function() {
      ent:tagStore.defaultsTo({}).klog("tag store").map(function(v,k) {
        v.keys()
      });
    }
    
    // Discovery: `app` and `bindings()` are returned by the discovery rule in response
    // to `discovery capabilities`. Integrators (HA, Manifold UI, etc.) use them to learn what
    // this ruleset exposes. Bindings come from this ruleset's /** */ annotations
    // (pico-engine 1.8+); see pico-engine docs: krl/discovery.md
    app = {
      "name": "safeandmine",
      "title": "SafeAndMine",
      "version": "0.0",
      "description": "QR/NFC name tags: register tags on this thing and share owner contact info when scanned."
    };
    bindings = function(){
      wrangler:schemaBindings(meta:rid)
    }
    
    getPolicyID = function(){
      engine:listPolicies().filter(function(x){x{"name"} == "registry pico events only"})[0]{"id"}
    }
    
    policy = {
      "name" : "registry pico events only",
      "query" : {
          "allow" : [
            { "rid" : "io.picolabs.safeandmine", "name" : "getInformation"}
            ], 
          "deny": []
      },
      "event" : {
        "allow" : [
          { "domain" : "safeandmine", "name" : "notify" },
          { "domain" : "safeandmine", "name" : "tag_register_response" }
          ], 
        "deny": []
      }
    }
    
    META_FIELD_LENGTH = 100
    MESSAGE_CHAR_LENGTH = 250
  }
  
  rule fake_store {
    select when generate fake_store
    pre {
      fakeStore = {"tagID1" : "did1", "tagID2" : "did2"}
    }
    
    always {
      ent:tagStore := {}
    }
  }
  
  rule update_registry_eci {
    select when safeandmine update_registry_eci
    
    pre {
      parent = wrangler:parent_eci().klog("parent") // ask mom
      tag_pico = wrangler:picoQuery(parent, "io.picolabs.manifold_pico", "getTagServer").klog("tag Pico")
      eci = tag_pico{"eci"}
      host = tag_pico{"host_url"}
    }
    
    if eci then noop();
    
    fired {
      raise pds event "new_data_available"
        attributes {
          "namespace": safeandmine_ns,
          "key": "registry_eci",
          "value": eci
        };
      raise pds event "new_data_available"
        attributes {
          "namespace": safeandmine_ns,
          "key": "registry_host",
          "value": host
        }
    }
  }
  
  rule discovery { 
    select when discovery capabilities 
    send_directive("discovery capability", 
                   {
                    "app": app, 
                    "rid": meta:rid, 
                    "bindings": wrangler:filterBindingsForCaller(bindings(), event:attr("eci"), meta:rid), 
                    "iconURL": "https://raw.githubusercontent.com/Picolab/SafeAndMine/master/logo.svg"
                   } 
                  ); 
  }

  rule update_tag_store {
    select when discovery capabilities
    
    pre {
      domains = ent:tagStore.defaultsTo({}).values().klog("Values");
      needsUpdate = (not((domains.head().typeof() == "Map").klog("hasDomain")) && domains.length() > 0);
    }
    
    if needsUpdate.klog("Does not need update") then noop();
    
    fired {
      ent:tagStore := {}.put("sqtg", ent:tagStore);
      raise safeandmine event "update_policy"
    } else {
      raise safeandmine event "update_policy"
    }
    
  }
  
  /**
   * Set the owner contact information shown when this thing's tag is scanned. Send
   * only the fields to change. name, email, and phone are cut to 100 characters,
   * message to 250. The share flags say which fields a finder sees.
   * @attr name String optional
   * @attr email String optional
   * @attr phone String optional
   * @attr message String optional "shown to the finder"
   * @attr shareName Boolean optional
   * @attr sharePhone Boolean optional
   * @attr shareEmail Boolean optional
   * @example "contact" { "name": "<name>", "phone": "<phone>", "message": "Please call if found", "shareName": true, "sharePhone": true }
   */
  rule information_update {
    select when safeandmine update
    pre {
      existing = pds:items(safeandmine_ns, "contact"){"general"}.defaultsTo({});
      name = event:attr("name").defaultsTo(existing{"name"}).defaultsTo("").substr(0, META_FIELD_LENGTH)
      email = event:attr("email").defaultsTo(existing{"email"}).defaultsTo("").substr(0, META_FIELD_LENGTH)
      phone = event:attr("phone").defaultsTo(existing{"phone"}).defaultsTo("").substr(0, META_FIELD_LENGTH)
      message = event:attr("message").defaultsTo(existing{"message"}).defaultsTo("").substr(0, MESSAGE_CHAR_LENGTH)
      attrs = {
        "name" : name,
        "email" : email,
        "phone" : phone,
        "message" : message,
        "shareName" : event:attr("shareName").as("Boolean").defaultsTo(false),
        "sharePhone" : event:attr("sharePhone").as("Boolean").defaultsTo(false),
        "shareEmail" : event:attr("shareEmail").as("Boolean").defaultsTo(false)
      }
    }
    always {
      raise pds event "new_data_available"
        attributes {
          "namespace": safeandmine_ns,
          "key": "contact",
          "value": attrs
        }
    }
    
  }
  
  /**
   * Remove one contact field, or all contact information if toDelete is omitted.
   * @attr toDelete String optional "field to remove"
   * @example "one field" { "toDelete": "phone" }
   * @example "everything" {}
   */
  rule information_delete {
    select when safeandmine delete
    
    pre {
      toDelete = event:attr("toDelete")
    }
    
    if toDelete then noop();
    
    notfired {
      raise pds event "remove_old_data"
        attributes {
          "namespace": safeandmine_ns,
          "key": "contact"
        }
    } else {
      raise pds event "new_data_available"
        attributes {
          "namespace": safeandmine_ns,
          "key": "contact",
          "value": pds:items(safeandmine_ns, "contact"){"general"}.defaultsTo({}).delete([toDelete])
        }
    }
    
  }
  
  /**
   * Register a QR or NFC tag on this thing. Creates a channel for the tag and
   * registers it with the mesh's tag registry; the tag appears in getTags() once
   * the registry confirms. Tag IDs are stored in upper case.
   * @attr tagID String
   * @attr domain String "tag domain, e.g. qr or nfc"
   * @attr pico_host String optional "this engine's public URL, if the registry is elsewhere"
   * @example "QR tag" { "tagID": "<tag id>", "domain": "qr" }
   */
  rule new_tag {
    select when safeandmine new_tag
    
    pre {
      tagID = event:attr("tagID").as("String");
      domain = event:attr("domain").as("String");
    }
    
      if (tagID.length() > 0) then 
        noop();
    
      fired {
        raise safeandmine event "new_tag_channel"
          attributes {
            "tagID" : tagID.uc(),
            "domain" : domain,
            "pico_host" : event:attr("pico_host")
          }
      }
  }

  rule check_tag_registry {
    select when safeandmine new_tag
    pre {
      eci = pds:items(safeandmine_ns, "registry_eci"){"general"}
    }
    if eci.isnull() then noop() 
    fired {
      raise safeandmine event "update_registry_eci" 
    }
  }
  
  rule create_tag_channel {
    select when safeandmine new_tag_channel
    pre {
      channel_tag = event:attr("domain") + "/" + event:attr("tagID");
    }
    // wrangler:createChannel([channel_tag], policy{"event"}, policy{"query"}) setting(channel)
    fired {
       raise wrangler event "new_channel_request" attributes event:attrs.put({
        "tags":[channel_tag],
        "eventPolicy":policy{"event"},
        "queryPolicy":policy{"query"},
      })
    }
  }
  
  rule send_registry_request {
    select when wrangler channel_created
    
    pre {
      tagID = event:attr("tagID");
      domain = event:attr("domain");
      channel = event:attr("channel"){"id"};
      registry_eci = pds:items(safeandmine_ns, "registry_eci"){"general"};
      pico_host = event:attr("pico_host").defaultsTo(meta:host);
    }
    
    if tagID && domain && channel && registry_eci then
      event:send({"eci": registry_eci, 
                  "domain": "safeandmine", 
                  "name": "register_tag", 
                  "attrs" : { "tagID" : tagID, 
                              "DID" : channel, 
                              "domain" : domain,
                              "pico_host": pico_host 
                            } 
                  });
     
    always {
      ent:channels := ent:channels.defaultsTo([]).append(channel);
      ent:tag_channel_eci := channel;
    }
  }
  
  rule post_response {
    select when safeandmine tag_register_response
    
    pre{
      tagID = event:attr("tagID");
      DID = event:attr("DID");
      domain = event:attr("domain");
    }
    if (tagID && DID) then noop();
    
    fired {
      ent:tagStore := ent:tagStore.defaultsTo({}).put([domain, tagID], DID);
    }
    else {
      raise safeandmine event "cleanup" attributes event:attrs
    }
  }
  
  rule channel_cleanup {
    select when safeandmine cleanup where ent:channels >< event:attr("label")
    
    always {
      ent:channels := ent:channels.splice(ent:channels.index(event:attr("label")), 1);
      
      raise wrangler event "channel_deletion_request"
          attributes {
            "eci" : event:attr("label")
          }
    }
  }
  
  /**
   * Remove a tag from this thing and from the tag registry.
   * @attr tagID String
   * @attr domain String
   */
  rule deregister_tag {
    select when safeandmine deregister
    
    pre {
      tagToDelete = event:attr("tagID");
      domain = event:attr("domain");
      registry_eci = pds:items(safeandmine_ns, "registry_eci"){"general"};
    }
    
    if tagToDelete && domain && registry_eci then
      event:send({"eci": registry_eci, "domain": "safeandmine", "name": "deregister_tag", "attrs" : { "tagID" : tagToDelete, "domain" : domain } });
  }

  rule deregister_tag_cleanup {
    select when safeandmine deregister
    
    pre {
      tagToDelete = event:attr("tagID");
      domain = event:attr("domain");
      channelToDelete = ent:tagStore.get([domain, tagToDelete]);
    }
    
    if tagToDelete && channelToDelete then noop()
    
    fired {
      ent:tagStore := ent:tagStore.defaultsTo({}).delete([domain,tagToDelete]).filter(function(v,k) {
        v.length() > 0
      });
      raise safeandmine event "cleanup"
      attributes {
        "label" : channelToDelete
      }
    }
  }
  
  rule deregister_all {
    select when apps cleanup
    
    foreach ent:tagStore setting (tags, domain)
      foreach tags.klog("tags") setting (did, tagID)
    
    always {
      raise safeandmine event "deregister"
      attributes {
        "domain" : domain.klog("domain"),
        "tagID" : tagID.klog("tagID")
      }
    }
    
  }
  
  /**
   * A tag on this thing was scanned: notify the owner through Manifold
   * (manifold:add_notification), with the thing's name and "Your tag … has been
   * scanned". Sent by the scan flow on the tag's channel.
   * @attr tagID String "the scanned tag"
   */
  rule notify {
    select when safeandmine notify
    
    pre {
      parent = wrangler:parent_eci();
      channels = wrangler:picoQuery(parent, "io.picolabs.wrangler", "channels", {});
      toSend = channels.filter(function(c) {
        c{"tags"} >< "Manifold" || c{"tags"} >< "manifold"
      }).head(){"id"}.klog("ECI to send notification");
      tagID = event:attr("tagID");
      picoId = wrangler:myself(){"id"};
      app = "SafeAndMine";
      rid = meta:rid;
      name = pds:profile("name"){"profile"} || wrangler:name();
      message = "Your tag " + tagID + " has been scanned";
      attrs = { 
        "picoId" : picoId,
        "thing" : name,
        "app" : app,
        "message" : message,
        "ruleset" : rid
      }
    }
    
    if tagID && picoId && app && rid && name && message && toSend then 
      event:send({ "eci" : toSend, "domain" : "manifold", "type" : "add_notification", "attrs" : attrs})
    
    
  }
  
}
