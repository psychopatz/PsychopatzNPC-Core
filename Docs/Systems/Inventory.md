# Inventory

## Purpose
- `PNC_Inventory` owns the player-like NPC inventory tree: hands, worn items, attachments, carried containers, and nested bag contents.
- abstract NPC simulation reads compact carry summaries instead of walking the full container tree every tick.

## Owned Data
- `inventory.revision`
- `inventory.equipped`
- `inventory.worn`
- `inventory.attached`
- `inventory.items`
- `inventory.containers`
- template-plus-delta persistence state
- derived carry caches such as used and remaining weight

## Public Functions
- `PNC.Inventory.CreateFromTemplate(record)`
- `PNC.Inventory.EnsureRecordInventory(record)`
- `PNC.Inventory.ApplyDelta(record, ops, reason)`
- `PNC.Inventory.GetWeightState(record)`
- `PNC.Inventory.BuildSummaryPayload(record)`
- `PNC.Inventory.BuildFullPayload(record)`
- `PNC.Inventory.BuildDeltaPayload(record, sinceRevision)`
- `PNC.Inventory.Serialize(record)`
- `PNC.Inventory.Deserialize(record, rawInventory)`

## Forbidden Responsibilities
- does not own persistence schema migration
- does not broadcast packets directly
- does not decide AI jobs
- does not materialize world items on its own
