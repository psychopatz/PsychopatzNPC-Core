# Orders

## Companion Orders
- `follow`
- `guard`
- `patrol`

## Hostile Orders
- `hostile_roam`
- `hostile_hunt`

## Ownership
- orders are normalized in `PNC_OrderSystem`
- `PNC_JobSystem` derives active job from order
- `PNC_BehaviorSystem` executes the job
