# PNC Fake Locomotion

## Purpose

`PNC_FakeLocomotion.lua` is the movement authority for embodied PNC live bodies.
It advances NPCs by small server-authoritative position steps while keeping the
underlying zombie AI disabled with `setUseless(true)`.

## Ownership

- `PNC_Behavior_*`: publish move intent only.
- `PNC_PathService`: owns the shared move lane, resolved movement mode,
  movement logs, and special movement orchestration.
- `PNC_FakeLocomotion`: owns fake walking/running/crawling step execution.
- `PNC_LiveBodyControl`: owns zombie-body suppression and live-body cleanup.
- `PNC_Animation`: owns animation variables, walk types, speed multipliers, and
  bump playback.
- `PNC_Network` and `PNC_ClientPresenceSync`: replicate movement state and
  preserve short special-move bump windows for nearby clients.

## Rules

- Live bodies stay `setUseless(true)` by default.
- Do not reintroduce vanilla `pathToLocation`, `walktoward`, or `path2` as the
  primary locomotion authority.
- If pathfinding is reintroduced later, it may only provide waypoints. It must
  not own the body transform.
- Keep special movement inside the same shared lane so follow, combat, patrol,
  guard, and retreat all use one locomotion path.
- Prefer time-scaled small steps over large snaps for multiplayer stability.

## Resolved Locomotion Mode

- `crawl` stays `crawl`.
- `sneak` stays `sneak`.
- Follow stealth also resolves to `sneak`.
- Normal locomotion switches to `run` when far from goal and falls back to
  `walk` near the goal using hysteresis to avoid animation thrash.
- Current live thresholds are approximately `4.5` tiles to enter `run` and
  `2.9` tiles to settle back to `walk`, with stop distance still respected.

## Animation Notes

- The movement lane now exposes `resolvedMode` and `animSpeed`.
- Animation speed is driven from the resolved live mode so leg motion tracks the
  real fake-locomotion step rate better.
- Walking is intentionally slower than before; far-distance closing now uses run
  instead of over-speed walk.
- The server resolves `animSpeed` and replicates it to clients so nearby
  multiplayer observers do not guess a different walk cadence.
- Live locomotion now reapplies walk state every tick instead of only on
  walk-type transitions, so `setMoving`, sneaking state, and walk type stay in
  sync with the fake step stream.

## Combat Override Notes

- Active attack actions temporarily override locomotion sync.
- Cancelling a move during an active attack no longer hard-resets the body back
  to idle, which prevents swings and shove bumps from freezing mid-action.

## Current Special Movements

- Doors: opened in-place and logged.
- Windows: opened in-place and logged.
- Window climb: fake bump plus controlled reposition to the opposite square,
  with origin and destination logging.

## Multiplayer Notes

- The server is authoritative for live-body movement.
- Clients consume replicated snapshots and live zombie replication only; they do
  not run NPC movement logic.
- Snapshot visual state carries short special-move bump windows so client visual
  sync does not overwrite climb bumps immediately.
- Snapshot visual state also carries the resolved locomotion animation speed so
  server fake-step transport and client leg cadence stay aligned.
