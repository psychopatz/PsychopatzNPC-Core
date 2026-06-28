# PsychopatzNPC-Core Master Plan

## Current V1 Slice
- server-authoritative NPC registry and persistence
- live and abstract presence states
- body removal on abstraction to prevent zombie husks
- companion `Follow`, `Guard`, `Patrol`
- hostile `Hunt` and `Roam`
- shared melee and ranged combat with atomic combat files
- zombie aggro bridge so zombies can acquire embodied NPCs
- custom HP, incapacitation, revive window, and stamina
- seeded identity, archetype registry, and compact inventory persistence
- right-click debug spawning, NPC selection hub, and character window

## Immediate Next Steps
- smoother live motion and tighter SP/MP parity for chase and follow
- richer animation bindings and better weapon-specific timing
- better ranged aim, muzzle/projectile treatment, and combat diagnostics
- more complete obstacle handling for windows, doors, and future fence traversal
- migration adapter layer for DynamicTrading
- deeper medical/body-part gameplay plugged into the NPC character window shell
