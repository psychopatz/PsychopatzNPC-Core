# Combat

## Shared Services
- `PNC_Combat` is the entry layer only
- `PNC_Combat_Melee`, `PNC_Combat_Ranged`, `PNC_Combat_AttackActions`, `PNC_Combat_Tactics`, and `PNC_Combat_Unarmed` own focused combat responsibilities
- custom damage routes through `PNC_Health`
- players, NPCs, and zombies use the same target format

## Current Rules
- melee and ranged attacks are server-authoritative delayed-hit actions, not immediate damage writes
- companions and hostiles can both acquire zombie targets
- unarmed combat uses shove and ground-finisher behavior instead of weapon swings
- combat can trigger conservative kiting and repositioning through `PNC_Combat_Tactics`
- combat debug state exposes target kind, resolved mode, weapon status, and block reason
