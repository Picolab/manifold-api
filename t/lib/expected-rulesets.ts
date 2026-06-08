/** App rulesets expected on each pico after Manifold bootstrap completes. */

export const TAG_REGISTRY_RULESETS = ["io.picolabs.new_tag_registry"] as const;

export const SKILLS_REGISTRY_RULESETS = ["io.picolabs.manifold.skills_registry"] as const;

export const OWNER_RULESETS = [
  "io.picolabs.profile",
  "io.picolabs.manifold_owner",
] as const;

/** manifold_pico installs these via initializationRids when it is first installed. */
export const MANIFOLD_RULESETS = [
  "io.picolabs.manifold_pico",
  "io.picolabs.notifications",
  "io.picolabs.twilio.sms",
  "io.picolabs.prowl",
] as const;

/** Installed when manifold_pico creates a thing child (thing RS init installs safeandmine). */
export const THING_RULESETS = ["io.picolabs.thing", "io.picolabs.safeandmine"] as const;

export const COMMUNITY_RULESETS = ["io.picolabs.community"] as const;
