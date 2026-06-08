ruleset io.picolabs.prowl {
  meta {
    name "Prowl Module"
    description <<
      Provide a means of sending prowl notifications to an iPhone, plus the Manifold
      "Prowl" notification channel. Configured ONCE per Manifold pico (the owner's
      Prowl account).
    >>
    author "Phil Windley"

    configure using apikey = "nokey"
                    providerkey = ""
                    application = "Pico Labs"
    provides notify

    shares show_configuration
  }

  global {

    show_configuration = function() {
      return {"apikey": ent:apikey,
              "providerkey": ent:providerkey,
              "application": ent:application
             }
    }

   notify = defaction(title, description, priority = 0, url="") {

     http:post("https://api.prowlapp.com/publicapi/add",
      form = {
       "apikey": ent:apikey,
       "providerkey": ent:providerkey,
       "application": ent:application,
       "priority": priority < -2 || priority > 2 => 0 | priority,
       "event": title.klog("Title: "),
       "description" : description,
       "url": url
      }) setting (resp)

      return resp
    }
  }

  // to use create a channel that allows the prowl domain; delete channel when done testing and configuring for security

  // Configure the single, Manifold-wide Prowl account (owner setup).
  rule save_config {
    select when prowl configuration
    pre {
      apikey = event:attr("apikey")
      providerkey = event:attr("providerkey")
      application = event:attr("application").defaultsTo("Pico Labs")
    }
    if not (apikey.isnull()
          || providerkey.isnull()
          || application.isnull()
           ) then noop()
    fired {
      log info "Configuring Prowl ";
      ent:providerkey := providerkey;
      ent:apikey := apikey;
      ent:application := application;
    }
  }

  // Manifold "Prowl" notification channel. The notifications orchestrator raises
  // this with the message Body; the thing/app name becomes the Prowl event title.
  rule notify_through_prowl {
    select when prowl notify_through_prowl
    pre {
      title = event:attr("thing") || event:attr("application");
      description = event:attr("Body");
    }
    if (title && description) then
      notify(title, description) setting(resp)
    fired {
      log info <<Prowl notification sent: #{resp.klog("Prowl response")}>>
    }
  }

  rule test_config {
    select when prowl test
    pre {
      msg = event:attr("msg")
    }
    notify("Test notification", <<Test message:  #{msg}>>) setting(resp)
    always {
      log info <<Test message sent: #{msg}; #{resp.klog("Response")} >>
    }
  }

}
