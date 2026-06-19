ruleset io.picolabs.profile {
  meta {
    use module io.picolabs.pds alias pds
    shares getProfile, getEmail, getPhone, getOwnerPhone, getOwnerEmail
  }
  global {
    // Recognized owner profile fields. Update events only touch these.
    profile_fields = ["name", "email", "phone"];

    getProfile = function() {
      pds:profile(){"profile"}.defaultsTo({})
    }

    getEmail = function() {
      pds:profile("email"){"profile"}
    }

    getPhone = function() {
      pds:profile("phone"){"profile"}
    }

    // Aliases used by the Manifold notification platform (SMS / future Email).
    getOwnerEmail = function() {
      pds:profile("email"){"profile"}
    }

    getOwnerPhone = function() {
      pds:profile("phone"){"profile"}
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
      attrs_step1 = name_provided => {"name": name} | {};
      attrs_step2 = email_provided => attrs_step1.put(["email"], email) | attrs_step1;
      update_attrs = phone_provided => attrs_step2.put(["phone"], phone) | attrs_step2;
    }
    if any_provided then
      send_directive("profile updated", {
        "name": name_provided => name | null,
        "email": email_provided => email | null,
        "phone": phone_provided => phone | null
      })
    fired {
      raise pds event "updated_profile" attributes update_attrs
    }
  }

  // Clear a single profile field. Send `profile clear` with attr `field`.
  rule clear_profile_field {
    select when profile clear
    pre {
      field = event:attr("field")
      clear_attrs = (field == "name") => {"name": ""}
                    | (field == "email") => {"email": ""}
                    | (field == "phone") => {"phone": ""}
                    | {}
    }
    if field && (profile_fields >< field) then
      send_directive("profile field cleared", {"field": field})
    fired {
      raise pds event "updated_profile" attributes clear_attrs
    }
  }
}
