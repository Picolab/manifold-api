# Fix for Manny Demo

## The problem
When a new pico is created in the v1 pico engine, its UI element is fixed in size, position, and color.

In a demo situation, after the conversational interface has created the pico for a new thing, the speaker will
refresh the pico engine developer UI, only to display the new pico in an awkward place.

## Planned solution
We will create a ruleset which can be installed in the Manifold pico. It will listen in on the events surrounding the 
creation and deletion of a thing pico.

It will provide a rule to move the latest created thing pico into a hard-coded space.
