ruleset io.picolabs.thing {
  meta {
    use module io.picolabs.wrangler alias wrangler
    //shares 
    //provides
  }
  global {

    app = {"name":"thing","version":"0.0"/* img: , pre: , ..*/};
    bindings = function(){
      {
        //currently no bindings
      };
    }

  }

  //rule discovery { select when manifold apps send_directive("app discovered...", {"app": app, "rid": meta:rid, "bindings": bindings(), "iconURL": "https://cdn0.iconfinder.com/data/icons/app-pack-1-musket-monoline/32/app-22-cog-512.png"} ); }


  rule initialization {
    select when wrangler ruleset_installed where event:attr("rids").klog("rids") >< ctx:rid.klog("meta rid")
    pre {
        absoluteURL = meta:rulesetURI;
    }
    if absoluteURL then noop();
    fired{
      raise wrangler event "install_ruleset_request"
      attributes {
        "rid" : "io.picolabs.safeandmine",
        "absoluteURL": absoluteURL // getting this from the same repo as this ruleset
      }
    }
  }

  rule installApp {
    select when manifold installapp
    pre {}
    noop()
    fired{
      raise wrangler event "install_rulesets_request"
        attributes event:attrs;
    }
  }
  
  rule uninstallApp {
    select when manifold uninstallapp
    pre {}
    noop();
    fired {
      raise wrangler event "uninstall_rulesets_request"
        attributes event:attrs;
    }
  }


}//end ruleset
