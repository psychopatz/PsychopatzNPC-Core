# Pathing

## V1
- live NPCs use server-owned path requests and embodied path behaviors
- abstract NPCs use coarse world travel
- live NPCs can open doors and use windows when the path stalls near an obstacle
- fence hopping is intentionally disabled in the baseline until a non-sticky traversal flow replaces it
- all path ownership lives in `PNC_PathService`
- behavior writes `move intent`; only `PNC_PathService.Pump` may start, refresh, cancel, or complete live movement
- the live move lane uses explicit phases: `idle`, `requested`, `active`, `arrived`, `blocked`, `cancel_pending`
- `walktoward` is a normal locomotion state, not a path-conflict state; recovery is reserved for real combat/thump conflicts so valid movement is not reset every tick
- live path refresh now routes through a single move lane, which matches the Bandits-style "one active move action" flow more closely and avoids stacked `path2` state churn
- close-range combat approach now softens from `run` to `walk` so embodied chase looks less robotic near contact range
- combat target stickiness now reduces target thrash so embodied NPCs do not keep stop-stepping between nearby zombies every tick
- path debug logs now report recovery, repath, timeout, and blocked states with the active goal so stuck movement is diagnosable without flooding normal runtime

## Next Expansion
- fence traversal
- smarter repath and stuck recovery lanes
- path cache reuse for larger live crowds
