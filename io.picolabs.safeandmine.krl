ruleset io.picolabs.safeandmine {
  meta {
    shares getInformation, getTags
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias sub
  }
  global {

    /*
    __testing = { "queries":
      [ { "name": "__testing" }
        , { "name": "getInformation", "args" : [ "info" ] }
        , { "name": "getTags" }
      ] , "events":
      [ { "domain": "safeandmine", "type": "update", "attrs" : [ "name" ] }
      , { "domain": "safeandmine", "type": "delete", "attrs": [ "toDelete" ] }
      , { "domain": "safeandmine", "type": "new_tag", "attrs": [ "tagID", "domain" ] }
      , { "domain": "safeandmine", "type": "deregister", "attrs": [ "tagID", "domain" ] }
      , { "domain": "safeandmine", "type": "notify", "attrs": [ "tagID" ] }
      , { "domain": "apps", "type": "cleanup" }
      , { "domain": "generate", "type": "fake_store" }
      , { "domain": "safeandmine", "type": "update_registry_eci", "attrs": [ "eci" ] }
      ]
    }
    */
    
    getInformation = function(info) {
      data = ent:contactInfo.defaultsTo({});
      info => data{info} | data
    }
    
    getTags = function() {
      ent:tagStore.defaultsTo({}).klog("tag store").map(function(v,k) {
        v.keys()
      });
    }
    
    app = {"name":"safeandmine","version":"0.0"/* img: , pre: , ..*/};
    bindings = function(){
      {
        //currently no bindings
      };
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
      ent:registry_eci := eci;
      ent:registry_host := host;
    }
  }
  
  rule discovery { 
    select when manifold apps 
    send_directive("app discovered...", 
                   {
                    "app": app, 
                    "rid": meta:rid, 
                    "bindings": bindings(), 
                    "iconURL": "https://raw.githubusercontent.com/Picolab/SafeAndMine/master/logo.svg"
                   } 
                  ); 
  }

  rule update_tag_store {
    select when manifold apps
    
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
  
  /* ----- deprecated ----
  rule update_policy {
    select when safeandmine update_policy
    
    pre {
      exists = getPolicyID()
    }
    if exists.isnull() then 
      engine:newPolicy(policy);
  }
  
  rule create_policy {
    select when wrangler ruleset_added where event:attr("rids") >< ctx:rid
    
    pre {
      exists = getPolicyID()
    }
    if exists.isnull() then 
      engine:newPolicy(policy);
  }
  ---- deprecated ---- */
  
  rule information_update {
    select when safeandmine update
    pre {
      name = event:attr("name").defaultsTo(ent:contactInfo{["name"]}).defaultsTo("").substr(0, META_FIELD_LENGTH)
      email = event:attr("email").defaultsTo(ent:contactInfo{["email"]}).defaultsTo("").substr(0, META_FIELD_LENGTH)
      phone = event:attr("phone").defaultsTo(ent:contactInfo{["phone"]}).defaultsTo("").substr(0, META_FIELD_LENGTH)
      message = event:attr("message").defaultsTo(ent:contactInfo{["message"]}).defaultsTo("").substr(0, MESSAGE_CHAR_LENGTH)
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
      ent:contactInfo := ent:contactInfo.defaultsTo({}).put(attrs);
    }
    
  }
  
  rule information_delete {
    select when safeandmine delete
    
    pre {
      toDelete = event:attr("toDelete")
    }
    
    if toDelete then noop();
    
    notfired {
      ent:contactInfo := {}
    } else {
      ent:contactInfo := ent:contactInfo.delete([toDelete])
    }
    
  }
  
  rule new_tag {
    select when safeandmine new_tag
    
    pre {
      tagID = event:attr("tagID").as("String");
      domain = event:attr("domain").as("String");
    }
    
      if (tagID.length() > 1) then 
        noop();
    
      fired {
        raise safeandmine event "new_tag_channel"
          attributes {
            "tagID" : tagID.uc(),
            "domain" : domain
          }
      }
  }

  rule check_tag_registry {
    select when safeandmine new_tag
    pre {
      eci = ent:registry_eci
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
      tagID = event:attrs{"tagID"}.klog("TAGID");
      domain = event:attrs{"domain"}.klog("DOMAIN");
      channel = event:attrs{"channel"}{"id"}.klog("CHANNEL");
    }
    
    event:send({"eci": ent:registry_eci, 
                "domain": "safeandmine", 
                "name": "register_tag", 
                "attrs" : { "tagID" : tagID, 
                            "DID" : channel, 
                            "domain" : domain,
                            "pico_host": meta:host 
                          } 
                });
     
    always {
      ent:channels := ent:channels.defaultsTo([]).append(channel)
      ent:tag_channel_eci := channel{"id"} // FIX: assuming only one tag? 
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
      
      raise wrangler event "channel_deletion_requested"
          attributes {
            "eci" : event:attr("label")
          }
    }
  }
  
  rule deregister_tag {
    select when safeandmine deregister
    
    pre {
      tagToDelete = event:attr("tagID");
      domain = event:attr("domain");
      channelToDelete = ent:tagStore.get([domain, tagToDelete]);
    }
    
    if tagToDelete && channelToDelete then 
    event:send({"eci": ent:registry_eci.defaultsTo("CEmo7mURALxUzEVLkN2Fwc"), "domain": "safeandmine", "type": "deregister_tag", "attrs" : { "tagID" : tagToDelete, "domain" : domain } });
    //http:post("https://apps.picolabs.io/safeandmine/api/delete", json = { "tagID" : tagToDelete });
    //http:post("http://localhost:3001/safeandmine/api/delete", json = { "tagID" : tagToDelete, "domain" : domain });
    
    fired{
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
  
  rule notify {
    select when safeandmine notify
    
    pre {
      toSend = sub:established().filter(function(x) {
        x{"Tx_role"} == "manifold_pico"
      }).head(){"Tx"}.klog("ECI to send notification");
      tagID = event:attr("tagID");
      picoId = meta:picoId;
      app = "SafeAndMine";
      rid = meta:rid;
      name = wrangler:name();
      name = wrangler:name();
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
