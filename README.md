# PsychopatzNPC-Core

Standalone NPC framework for Project Zomboid Build 42.

This repository starts with a server-authoritative V1 slice:

- companion NPCs with `Follow`, `Guard`, and `Patrol`
- hostile NPCs with shared `Melee` and `Ranged` combat
- live/abstract presence switching with hard removal of live zombie bodies on abstraction
- multiplayer-safe authority flow with the same codepath used by singleplayer host

The framework is split into small subsystem files under `PNC/Core` so future work can extend jobs, behaviors, pathing, combat, and migration adapters without rebuilding the base.
