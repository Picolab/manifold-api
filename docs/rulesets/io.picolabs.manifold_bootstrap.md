# io.picolabs.manifold_bootstrap

Manifold bootstrap automation. Install this ruleset on the root pico to  
automatically perform the full Manifold bootstrap sequence:  
1) Create a tag registry child pico and install io.picolabs.new_tag_registry.  
2) Create an owner child pico and install io.picolabs.profile and io.picolabs.manifold_owner  
(which in turn creates the Manifold child and installs io.picolabs.manifold_pico).  
3) Register the tag registry's registration ECI with the owner by raising  
manifold:new_tag_server on the owner, so things can use the tag registry.  
PDS (io.picolabs.pds) is default-installed by the pico-engine on every pico.  
(Legacy skills registry pico removed — use pico-engine 1.8+ MCP / channelSchema instead.)  
All steps follow the bootstrap architecture described in the Manifold-api README.

*Version draft. Generated from the ruleset's annotations by `krl-schema --format markdown`; edit the `/** */` comments in the source, not this page. Only annotated rules and shared functions appear.*

**Queries:** [getBootstrapStatus](#getbootstrapstatus--map)

## Queries

### `getBootstrapStatus()` → Map

Progress of the bootstrap: the ECIs of the tag registry, its registration channel, and the owner. Each is null until that step completes; poll to know when the mesh is ready.

**Call:** `GET /sky/query/<eci>/io.picolabs.manifold_bootstrap/getBootstrapStatus`, or `<alias>:getBootstrapStatus()` from KRL with `use module io.picolabs.manifold_bootstrap alias <alias>`
