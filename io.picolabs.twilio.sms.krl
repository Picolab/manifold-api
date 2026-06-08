ruleset io.picolabs.twilio.sms {
  meta {
    name "Twilio Module for SMS only"
    description <<
Utility methods for sending SMS with Twilio, plus the Manifold "SMS" notification
channel. Configured ONCE per Manifold pico (the owner's Twilio account); the
recipient is supplied per-send by the notifications orchestrator.
>>
    author "Phil Windley"
    version "0.2.0"

    provides send_sms
    shares show_configuration

    configure using from_number = "801-555-1212"
                    account_sid = ""
                    auth_token = ""
  }

  global {

    show_configuration = function() {
      return {"account_sid": ent:account_sid,
              "auth_token": ent:auth_token,
              "from_number": ent:from_number}
    }

    //outgoing actions
    send_sms = defaction(message, to, from=ent:from_number){
        base_url = <<https://api.twilio.com/2010-04-01/Accounts/#{ent:account_sid}/>>
        http:post((base_url + "Messages.json"),
            form = {
                "From":from,
                "To":to,
                "Body":message
            },
            auth = {
                "username": ent:account_sid,
                "password": ent:auth_token
            }) setting (resp);
        return resp
    };
  }

  // Configure the single, Manifold-wide Twilio account (owner setup).
  rule save_config {
    select when twilio configuration
    pre {
      auth_token = event:attr("twilio_auth_token")
      account_sid = event:attr("twilio_account_sid")
      from_number = event:attr("twilio_from_number") // number twilio gives you in E.164 format
    }
    if not (auth_token.isnull()
          || account_sid.isnull()
          || from_number.isnull()
           ) then noop()
    fired {
      log info "Configuring twilio";
      ent:account_sid := account_sid;
      ent:auth_token := auth_token;
      ent:from_number := from_number;
    }
  }

  // Manifold "SMS" notification channel. The notifications orchestrator raises this
  // with the message Body and the resolved owner phone number in `to`.
  rule notify_through_twilio {
    select when twilio notify_through_twilio
    pre {
      body = event:attr("Body");
      to = event:attr("to");
    }
    if (body && to) then
      send_sms(body, to) setting(resp)
    fired {
      log info <<SMS sent to #{to}: #{resp.klog("Twilio response")}>>
    }
  }

  // to use create a channel that allows the twilio domain; delete channel when done testing for security
  rule test_config {
    select when twilio test
    pre {
      msg = event:attr("msg")
    }
    send_sms(<<Test message:  #{msg}>>, "+18013625611") setting(resp)
    always {
      log info <<Test message sent: #{msg}; #{resp.klog("Response")} >>
    }
  }

}
