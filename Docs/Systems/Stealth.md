# Stealth

## Purpose
- `PNC_Stealth` owns follow-stealth state for companions and the suppression rules that affect combat and zombie aggro.

## Current Rules
- stealth follow is only active for `follow` orders
- the owner must actually be sneaking
- stealth follow is cleared if the owner is running, sprinting, in a vehicle, dead, or too far away
- if the owner is discovered by nearby zombies, follow-stealth breaks and normal combat resumes
- stealth diagnostics now log only on state transitions so crouch-follow failures can be traced without per-tick spam

## Integration Points
- `PNC_BehaviorSystem` asks stealth for follow move mode
- `PNC_Perception` suppresses companion target acquisition while valid follow-stealth is active
- `PNC_ZombieAggro` suppresses zombie targeting on concealed companions

## Forbidden Responsibilities
- does not path bodies
- does not directly damage or aggro targets
- does not own player stealth mechanics outside companion-follow rules
