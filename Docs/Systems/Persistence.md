# Persistence

## Purpose
- `PNC_Persistence` owns save-schema versioning, serialization, hydration, and runtime rehydrate rules.
- `PNC_Registry` delegates all long-lived record writes to this subsystem.

## Owned Data
- versioned persisted schema
- canonical persisted fields only
- runtime rebuild defaults after load

## Public Functions
- `PNC.Persistence.SerializeRecord(record)`
- `PNC.Persistence.DeserializeRecord(raw, fallbackID)`
- `PNC.Persistence.LoadAll(serializedRecords)`
- `PNC.Persistence.SaveAll(records)`
- `PNC.Persistence.RebuildRuntime(record)`

## Forbidden Responsibilities
- does not materialize live bodies
- does not own targets, path caches, or combat scratch state
- does not build client snapshots

