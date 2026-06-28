# Stamina

## Purpose
- `PNC_Stamina` owns authoritative stamina values, recovery, combat spend rules, and overhead-visibility timers.

## Current Rules
- melee, ranged, and downed shove actions spend stamina through one authority path
- skill-aware attack spend can reduce effective stamina cost
- recovery differs for idle, moving, combat, and downed states
- tactical retreat can temporarily opt into idle-rate stamina recovery while moving away from danger
- nameplates decide draw visibility from stamina summary data, not direct runtime internals

## Integration Points
- `PNC_Combat_*` checks and spends attack stamina
- `PNC_Network` exports stamina summary and visibility data
- `PNC_Nameplates` uses stamina snapshot lanes for overhead bars

## Forbidden Responsibilities
- does not select jobs
- does not decide target acquisition
- does not build full UI windows
