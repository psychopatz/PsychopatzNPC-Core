# Networking

## Purpose
- `PNC_Network` owns client-facing payload construction and replication only.
- the server registry remains authoritative; clients never create canonical NPC records.

## Current Payload Lanes
- `BuildRosterSnapshot`: compact list data for joins and broad roster views
- `BuildSnapshot`: live-presence and nearby view state
- `BuildCharacterPayload`: on-demand detailed payload for `View Character`
- `BroadcastRecord` and `BroadcastFullSync`: server dispatch only

## Current Rules
- snapshot building reuses cached equipment and appearance data where possible
- full inventory payloads are on-demand, not sent every tick
- live-body client reconciliation is handled by `PNC_ClientPresenceSync`, not by networking itself

## Forbidden Responsibilities
- does not tick AI
- does not resolve presence transitions
- does not write persistence records
- does not apply client visuals directly
