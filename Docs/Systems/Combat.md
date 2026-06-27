# Combat

## Shared Services
- melee and ranged both route through `PNC_Combat`
- custom damage routes through `PNC_Health`
- players and NPCs use the same target format

## Current Rules
- melee range is short and favors companions
- ranged attacks are cooldown-based and server-authoritative
- hostile NPCs target nearby players
- companion NPCs prioritize nearby hostile NPCs
