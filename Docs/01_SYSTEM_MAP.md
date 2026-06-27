# System Map

## Shared Core
- `PNC_Core`: environment helpers, time, players, logging
- `PNC_Registry`: authoritative NPC records and live body lookup
- `PNC_SpatialIndex`: indexed nearby player and NPC queries
- `PNC_Perception`: target selection rules
- `PNC_Animation`: single animation state writer
- `PNC_Health`: custom HP, downed, death ownership
- `PNC_Combat`: shared melee and ranged combat services
- `PNC_PathService`: live stepping and abstract travel
- `PNC_OrderSystem`: order normalization and ownership
- `PNC_JobSystem`: selects active job from order and state
- `PNC_BehaviorSystem`: executes the active job
- `PNC_Presence`: live and abstract transitions, body cleanup
- `PNC_Scheduler`: cadence rules
- `PNC_Network`: snapshot and removal broadcast helpers
- `PNC_API`: external entry points

## Server
- `PNC_Server`: authority tick, full sync, debug commands

## Client
- `PNC_Client`: snapshot cache, sync requests, context menu debug tools
