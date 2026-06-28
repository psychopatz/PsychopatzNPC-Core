# System Map

## Shared Core
- `PNC_Core`: environment helpers, time, players, logging
- `PNC_Archetypes`: self-registering archetype registry
- `PNC_ArchetypeLoader`: imports registered archetype modules by convention or explicit module path
- `PNC_Identity_Factory`: `SurvivorFactory`-first identity resolution
- `PNC_Identity_Profile`: persisted identity and appearance resolution
- `PNC_Inventory`: compact player-like inventory tree with template-plus-delta persistence
- `PNC_Persistence`: versioned canonical save schema, migration, and runtime rehydrate
- `PNC_Registry`: authoritative NPC records and live body lookup
- `PNC_SpatialIndex`: indexed nearby player and NPC queries
- `PNC_Perception`: target selection rules
- `PNC_Animation`: single animation state writer
- `PNC_Health`: custom HP, incapacitation, death ownership
- `PNC_Combat`: shared melee and ranged combat services
- `PNC_PathService`: live stepping and abstract travel
- `PNC_OrderSystem`: order normalization and ownership
- `PNC_JobSystem`: selects active job from order and state
- `PNC_BehaviorSystem`: executes the active job
- `PNC_Presence`: live and abstract transitions, body cleanup
- `PNC_Scheduler`: cadence rules
- `PNC_Network`: roster snapshots, live presence snapshots, and on-demand character payloads
- `PNC_API`: external entry points

## Layout Rule
- reusable archetype definitions, translation files, clothing XML, and other version-agnostic content belong in `common/media/...`
- `42.16/media/...` should hold only build-specific runtime Lua and assets that genuinely differ by Project Zomboid version

## Server
- `PNC_Server`: authority tick, full sync, debug commands

## Client
- `PNC_Client`: roster cache, character-payload cache, sync requests, context menu debug tools
- `PNC_Nameplates`: overhead name, HP, stamina, and AI debug overlay
- `PNC_CharacterWindow`: vanilla-like NPC character shell and tabs
