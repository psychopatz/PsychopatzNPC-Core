# Identity

## Purpose
- `PNC_Archetypes` owns self-registering archetype definitions, looks, base skills, and loadout templates.
- `PNC_ArchetypeLoader` owns default archetype-module import, not individual archetype data.
- `PNC_Identity_Factory` resolves a new NPC from `SurvivorFactory`, then PNC persists the resolved result.
- `PNC_Identity_Profile` normalizes `identitySeed`, `archetypeID`, `displayName`, gender, and appearance from persisted identity fields.
- archetype definition modules themselves live in `common/media/lua/shared/PNC/ArchetypeDefinitions/...` so they are not duplicated per-version.

## Owned Data
- `identitySeed`
- `archetypeID`
- `archetypeLabel`
- `displayName`
- `identity.survivor.*`
- archetype skill-bias metadata
- archetype look and loadout metadata

## Public Functions
- `PNC.RegisterArchetypeModule(id, spec)`
- `PNC.LoadArchetypes()`
- `PNC.RegisterArchetype(id, data)`
- `PNC.RegisterArchetypeLooks(id, data)`
- `PNC.RegisterArchetypeSkills(id, data)`
- `PNC.RegisterArchetypeLoadout(id, data)`
- `PNC.Identity.ResolveArchetypeID(source)`
- `PNC.Identity.GenerateResolvedIdentity(source)`
- `PNC.Identity.ApplyRecordIdentity(record, source)`
- `PNC.Identity.RollAppearance(record)`
- `PNC.Identity.GetCharacterSummary(record)`

## Forbidden Responsibilities
- does not save records
- does not build network payloads
- does not draw nameplates or character UI
- does not own progression deltas
