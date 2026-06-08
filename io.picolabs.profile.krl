ruleset io.picolabs.profile {
  meta {
    shares getProfile, getEmail, getPhone, getOwnerPhone, getOwnerEmail
  }
  global {
    // Recognized owner profile fields. Update events only touch these.
    profile_fields = ["name", "email", "phone"];

    getProfile = function() {
      ent:profile.defaultsTo({})
    }

    getEmail = function() {
      ent:profile{"email"}
    }

    getPhone = function() {
      ent:profile{"phone"}
    }

    // Aliases used by the Manifold notification platform (SMS / future Email).
    getOwnerEmail = function() {
      ent:profile{"email"}
    }

    getOwnerPhone = function() {
      ent:profile{"phone"}
    }
  }

  // Set/update owner profile fields. Send `profile update` with any of
  // {name, email, phone}; empty or missing values are left unchanged.
  rule update_profile {
    select when profile update
    pre {
      name = event:attr("name")
      email = event:attr("email")
      phone = event:attr("phone")
      name_provided = not (name.isnull() || name == "")
      email_provided = not (email.isnull() || email == "")
      phone_provided = not (phone.isnull() || phone == "")
      any_provided = name_provided || email_provided || phone_provided
    }
    if any_provided then
      send_directive("profile updated", {
        "name": name_provided => name | null,
        "email": email_provided => email | null,
        "phone": phone_provided => phone | null
      })
    fired {
      ent:profile := ent:profile.defaultsTo({});
      ent:profile{"name"} := name if name_provided;
      ent:profile{"email"} := email if email_provided;
      ent:profile{"phone"} := phone if phone_provided;
    }
  }

  // Clear a single profile field. Send `profile clear` with attr `field`.
  rule clear_profile_field {
    select when profile clear
    pre {
      field = event:attr("field")
    }
    if field && (profile_fields >< field) then
      send_directive("profile field cleared", {"field": field})
    fired {
      ent:profile := ent:profile.defaultsTo({}).delete([field])
    }
  }
}
