/** Platform + app rulesets expected on each pico after Manifold bootstrap / creation. */

export const PDS_RID = "io.picolabs.pds" as const;

/** Default-installed by pico-engine on every pico (Phase F). */

export const TAG_REGISTRY_RULESETS = [
  PDS_RID,
  "io.picolabs.new_tag_registry",
] as const;

export const SKILLS_REGISTRY_RULESETS = [
  PDS_RID,
  "io.picolabs.manifold.skills_registry",
] as const;

export const OWNER_RULESETS = [
  PDS_RID,
  "io.picolabs.profile",
  "io.picolabs.manifold_owner",
] as const;

/** manifold_pico installs notification RS via initializationRids; PDS is engine-default. */
export const MANIFOLD_RULESETS = [
  PDS_RID,
  "io.picolabs.manifold_pico",
  "io.picolabs.notifications",
  "io.picolabs.twilio.sms",
  "io.picolabs.prowl",
] as const;

/** Installed when manifold_pico creates a thing child (PDS is engine-default; thing RS init installs safeandmine). */
export const THING_RULESETS = [
  PDS_RID,
  "io.picolabs.thing",
  "io.picolabs.safeandmine",
] as const;

export const COMMUNITY_RULESETS = [PDS_RID, "io.picolabs.community"] as const;
