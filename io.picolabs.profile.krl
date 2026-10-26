ruleset io.picolabs.profile {
  meta {
    name "Owner profile"
    description <<
      The owner's name, email, and phone, on the Owner pico. A thin layer over the
      pico's PDS profile (io.picolabs.pds), kept for Manifold code that reads owner
      contact details; new code can use PDS directly.
    >>
    use module io.picolabs.pds alias pds
    shares getProfile, getEmail, getPhone, getOwnerPhone, getOwnerEmail
  }
  global {
    // Recognized owner profile fields. Update events only touch these.
    profile_fields = ["name", "email", "phone"];

    /**
     * The owner's PDS profile: name, email, phone, and the other PDS profile fields.
     * @returns Map
     */
    getProfile = function() {
      pds:profile(){"profile"}.defaultsTo({})
    }

    /**
     * The owner's email.
     * @returns String
     */
    getEmail = function() {
      pds:profile("email"){"profile"}
    }

    /**
     * The owner's phone number (where SMS notifications go).
     * @returns String
     */
    getPhone = function() {
      pds:profile("phone"){"profile"}
    }

    // Same as getEmail / getPhone; used by the Manifold notification platform.
    // Not discoverable separately.
    getOwnerEmail = function() {
      pds:profile("email"){"profile"}
    }

    getOwnerPhone = function() {
      pds:profile("phone"){"profile"}
    }
  }

  // Set/update owner profile fields. Send `profile update` with any of
  // {name, email, phone}; empty or missing values are left unchanged.
  /**
   * Set the owner's name, email, or phone. Send only the fields to change; empty
   * or missing values are left as they are.
   * @attr name String optional
   * @attr email String optional
   * @attr phone String optional "where SMS notifications go"
   * @example "contact info" { "email": "<email>", "phone": "<phone>" }
   * @example "rename" { "name": "<name>" }
   */
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
  /**
   * Clear one profile field.
   * @attr field String "name, email, or phone"
   * @example "clear phone" { "field": "phone" }
   */
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
