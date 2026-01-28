ruleset io.picolabs.new_tag_registry {
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares get_tag_store, scan_tag
  }
  global {
    
    
    scan_tag = function(tagID, domain) {
      ent:tag_store.defaultsTo({}).get([domain, tagID.uc()])
    }
    
    get_tag_store = function() {
      ent:tag_store.defaultsTo({})
    }
  }
  
  rule register_tag {
    select when safeandmine register_tag
    
    pre {
      tagID = event:attr("tagID");
      domain = event:attr("domain");
      redirect_url = event:attr("redirect_url") => event:attr("redirect_url") | "https://manifold.picolabs.io/#/picolabs/safeandmine";
      pico_host = event:attr("pico_host") => event:attr("pico_host") | "https://manifold.picolabs.io:9090";
      did = event:attr("DID");
      notRegistered = scan_tag(tagID, domain) => false | true;
      map = { "did" : did, "pico_host" : pico_host, "redirect_url" : redirect_url }
    }
    
    if tagID && domain && notRegistered then 
      event:send({"eci": did, "domain" : "safeandmine", "type" : "tag_register_response", "attrs" : { "tagID" : tagID, "domain" : domain, "DID" : did}}, pico_host);
    
    fired {
      ent:tag_store := ent:tag_store.defaultsTo({}).put([domain, tagID], map);
    }
  }
  
  rule deregister_tag {
    select when safeandmine deregister_tag
    
    pre {
      tagID = event:attr("tagID");
      domain = event:attr("domain");
      isRegistered = scan_tag(tagID, domain);
    }
    
    if tagID && domain && isRegistered then noop();
    
    fired {
      ent:tag_store := ent:tag_store.defaultsTo({}).delete([domain, tagID])
    }
  }
  
  rule redirect {
    select when safeandmine redirect
    
    pre {
      tagID = event:attr("tagID");
      domain = event:attr("domain");
      did = scan_tag(tagID, domain);
      redirect_url = ent:tag_store.get([domain, tagID.uc(), "redirect_url"]);
      didParam = (did) => "&DID=" + did | "";
      url = (redirect_url) => <<#{redirect_url}/?tagID=#{tagID}#{didParam}>> | <<https://manifold.picolabs.io/#/picolabs/safeandmine/?tagID=#{tagID}&domain=#{domain}>>
    }
    
    send_directive("_redirect", {"url" : url})
  }

  rule createChannel { // fix policies
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName = "registration"
      eventPolicy = {"allow": [{"domain": "*", "name": "*"}], "deny": []}
      queryPolicy = {"allow":[{"rid": "*", "name": "*"}], "deny": []}
      existing_channels = wrangler:channels().klog("Current channels");
      app_channel = existing_channels.filter(function(chan){
        chan{"name"} == channelName 
      });
      channel_exists = app_channel.length() > 0;
    }
    if not channel_exists then
      wrangler:createChannel([channelName], eventPolicy, queryPolicy) setting(channel)
    fired {
      ent:registration_channel_eci := channel{"id"}
    }
  }
}
