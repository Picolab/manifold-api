# Fix for Manny Demo

## The problem
When a new pico is created in the v1 pico engine, its UI element is fixed in size, position, and color.

In a demo situation, after the conversational interface has created the pico for a new thing, the speaker will
refresh the pico engine developer UI, only to display the new pico in an awkward place.

## Planned solution
We will create a ruleset which can be installed in the Manifold pico. It will listen in on the events surrounding the 
creation and deletion of a thing pico.

It will provide a rule to move the latest created thing pico into a hard-coded space.

## Usage
Before demo, 
- install [the ruleset](https://raw.githubusercontent.com/Picolab/MCPforEXP/refs/heads/main/Manifold-api/fix/io.picolabs.MCPforEXP.demo-fixer.krl) in the Manifold pico.

- that will automatically add a new channel that allows `demo_fixer:*` events.

- locate the new channel (in the Channels tab) and copy its ID.

During the demo,
- after the new thing pico is created,
use the new channel to send the `demo_fixer fix_requested` event to the Manifold pico.

- refresh the pico engine overview page to see the pico in the hard-coded place.

## Screenshots
### Installing the ruleset:
<img width="1996" height="1620" alt="Screenshot 2026-04-06 at 13 46 34" src="https://github.com/user-attachments/assets/86750703-c1d1-427c-a97b-5b40d15a91fd" />

### Sending the event to fix the position
<img width="1698" height="1496" alt="Screenshot 2026-04-06 at 13 47 27" src="https://github.com/user-attachments/assets/2f9ed4a5-5ba9-4811-a801-ff07a63cd81c" />

## Better and completely automated solution
A much [simpler ruleset](https://github.com/Picolab/MCPforEXP/blob/main/Manifold-api/fix/io.picolabs.MCPforEXP.simple-fix.krl) solves the problem automatically.
The `io.picolabs.MCPforEXP.simple-fix` ruleset has a single rule which reacts to the new child initialized event and moves the pico to a better place.
