# Zombie Reaction And Facing

## Ownership

- `PNC_Combat_ZombieReaction.lua` owns short NPC-on-zombie shove and hit
  reactions.
- `PNC_PathService.lua` owns facing leases and decides whether combat or
  locomotion currently controls body facing.
- `PNC_FakeLocomotion.lua` owns travel transport and asks pathing to face the
  body along the actual step direction.

## Rules

- Zombie shove reactions are server-owned short windows, not one-frame flag
  flips.
- Default shove behavior is stagger plus pushback; knockdown is reserved for
  explicit heavy reactions.
- Combat may lease facing briefly for attack windup, attack follow-through, or
  close repositioning.
- Outside those leases, locomotion owns facing and points the NPC along travel
  direction.
