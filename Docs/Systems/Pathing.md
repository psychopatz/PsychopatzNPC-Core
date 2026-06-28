# Pathing

## V1
- live NPCs use server-owned path requests and embodied path behaviors
- abstract NPCs use coarse world travel
- live NPCs can open doors and use windows when the path stalls near an obstacle
- fence hopping is intentionally disabled in the baseline until a non-sticky traversal flow replaces it
- all path ownership lives in `PNC_PathService`
- close-range combat approach now softens from `run` to `walk` so embodied chase looks less robotic near contact range

## Next Expansion
- fence traversal
- smarter repath and stuck recovery lanes
- path cache reuse for larger live crowds
