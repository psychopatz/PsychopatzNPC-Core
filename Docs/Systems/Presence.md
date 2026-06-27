# Presence

## States
- `live`: embodied zombie actor exists
- `abstract`: record only, no embodied actor exists
- `corpse`: dead state

## Guarantees
- abstracting a living NPC removes the live zombie body immediately
- no hidden or parked zombie is kept around for abstract travel
- materialization always spawns a fresh body from authoritative record state

## Current Implementation
- server checks player distance with hysteresis
- `Materialize` uses `addZombiesInOutfit(...)`
- `Abstract` snapshots current position and calls:
  - `removeFromWorld()`
  - `removeFromSquare()`
