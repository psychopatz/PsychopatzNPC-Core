# Identity

## Purpose
- `PNC_ArchetypeCatalog` owns PNC-vendored archetype labels, DT-derived look pools, and seeded skill biases.
- `PNC_Identity_Names` owns deterministic name generation.
- `PNC_Identity_Profile` resolves `identitySeed`, `archetypeID`, `displayName`, gender, and appearance from one seed.

## Owned Data
- `identitySeed`
- `archetypeID`
- `archetypeLabel`
- `displayName`
- seeded appearance inputs
- archetype skill-bias metadata

## Public Functions
- `PNC.Identity.ResolveArchetypeID(source)`
- `PNC.Identity.ApplyRecordIdentity(record, source)`
- `PNC.Identity.RollAppearance(record)`
- `PNC.Identity.GetCharacterSummary(record)`

## Forbidden Responsibilities
- does not save records
- does not build network payloads
- does not draw nameplates or character UI
- does not own progression deltas

