# Spider Rope

**Type:** TBD — spell or cybernetic (grapple gear reads as an Augment; owner to classify)
**Status:** Idea — recorded 2026-07-16

## Concept (owner spec)

- Fires a rope that sticks to surfaces.
- **View-directed behavior:**
  - If the player is **looking within a view angle that contains the rope's attachment point → they are pulled toward the attachment point** (reel in).
  - If the player **looks away** (outside that angle) → the rope length holds static and they **swing around the attachment point** (pendulum).
- Look-to-reel, look-away-to-swing: one input, two movement modes, controlled by the camera.

## Interactions with decided systems

- **Movement tech pillar:** joins Repulse/Glide/Slip/Hopper as skill-expression movement; rope+Glide (release at swing apex, deploy glide) is an obvious dream combo. Rope+Repulse mid-swing = slingshot.
- **Netcode:** rope state (attachment point, length, reel/swing mode) is rollback state on the player; the pull/swing force is computed in the player's own tick from their recorded aim — same victim-side-tick pattern as glide. The view-angle mode switch uses recorded `aim_yaw/pitch`, so it's deterministic. Clean fit.
- **Slot question:** if cybernetic — Arm slot (new)? If Manifestation — cost per fire or reservation while attached?
- **Contextual inputs:** needs a bind; LB/ability-radial reservation from the controller layout is the likely home.
- **Layer-1 validation:** movement caps must model legit swing velocities (pendulum speeds can exceed sprint).

## Open questions

- Spell vs cybernetic (and slot/cost accordingly).
- Max rope length, reel speed, detach conditions (jump? re-fire? damage cuts rope? blade cuts rope — counterplay!).
- Can the rope attach to players / corpses / world objects, or geometry only?
- View angle threshold for reel-vs-swing (baseline ~30°?).

## Research notes

(none yet)
