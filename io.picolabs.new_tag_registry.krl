ruleset io.picolabs.new_tag_registry {
  meta {
    name "Manifold tag registry"
    description <<
      Maps NFC/QR tags to the thing picos they identify, per tag domain, with a
      redirect URL for scans. Installed on the Tag Registry pico by bootstrap; things
      register tags through SafeAndMine.
    >>
    use module io.picolabs.wrangler alias wrangler
    shares get_tag_store, scan_tag
  }
  global {
    
    
    /**
     * What a tag is registered to: { did, pico_host, redirect_url }, or null.
     * @param tagID String
     * @param domain String "tag domain, e.g. qr or nfc"
     * @returns Map
     */
    // TODO: reads tagID.uc() but register_tag stores tagID as given, so tags not
    // registered in upper case are never found (also affects deregister_tag).
    scan_tag = function(tagID, domain) {
      ent:tag_store.defaultsTo({}).get([domain, tagID.uc()])
    }
    
    /**
     * Every registered tag, by domain then tagID.
     * @returns Map
     */
    get_tag_store = function() {
      ent:tag_store.defaultsTo({})
    }
  }
  
  /**
   * Register a tag to a thing, unless the tag is already registered in that
   * domain. The thing is told with safeandmine:tag_register_response on DID.
   * @attr tagID String
   * @attr domain String "tag domain, e.g. qr or nfc"
   * @attr DID String "the thing's channel for the response"
   * @attr redirect_url String optional "where scans go (default: the SafeAndMine app)"
   * @attr pico_host String optional "the thing's engine URL"
   */
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
    
    // Deliver on-engine (no host): HTTP event:send to docker service names like
    // pico-engine:3000 fails channel auth (401) because only localhost bypasses session.
    if tagID && domain && did then
      event:send({"eci": did, "domain" : "safeandmine", "name" : "tag_register_response", "attrs" : { "tagID" : tagID, "domain" : domain, "DID" : did}});
    
    always {
      ent:tag_store := (tagID && domain && notRegistered) => ent:tag_store.defaultsTo({}).put([domain, tagID], map) | ent:tag_store.defaultsTo({})
    }
  }
  
  /**
   * Remove a tag's registration.
   * @attr tagID String
   * @attr domain String
   */
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
  
  /**
   * Look up a scanned tag and answer with a _redirect directive to its
   * redirect URL (or the SafeAndMine app if it isn't registered).
   * @attr tagID String
   * @attr domain String
   */
  // TODO: did is scan_tag(...)'s whole map, not its did, so DID= in the URL is wrong.
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

  rule createChannel {
    select when wrangler ruleset_installed where event:attr("rids") >< ctx:rid
    pre {
      channelName = "registration"
      eventPolicy = {
        "allow": [
          {"domain": "safeandmine", "name": "register_tag"},
          {"domain": "safeandmine", "name": "deregister_tag"},
          {"domain": "safeandmine", "name": "redirect"}
        ],
        "deny": []
      }
      queryPolicy = {
        "allow": [
          {"rid": meta:rid, "name": "get_tag_store"},
          {"rid": meta:rid, "name": "scan_tag"}
        ],
        "deny": []
      }
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
