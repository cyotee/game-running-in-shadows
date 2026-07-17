# Deployable Camera (Picture-in-Picture)

**Type:** Augment (equipment-class throwable, like Null Charge — no body slot presumed; owner to confirm)
**Status:** Idea — recorded 2026-07-16

## Concept (owner spec)

- Player throws a camera device; it **sticks to any surface**.
- The camera's view appears **picture-in-picture in a corner of the player's screen**.

## Feasibility assessment (2026-07-16): LOW difficulty

This is one of the cheapest ideas in the tracker — Godot supports the pattern natively:

- **Rendering:** a `SubViewport` sharing the main scene's `World3D` with its own `Camera3D` at the device's position, displayed through a `TextureRect` in the HUD corner. This is a standard, well-documented Godot pattern (security-camera tutorials exist). Render the feed at low resolution (~320×180) and optionally throttle to every 2nd–3rd frame; cost is a fraction of a second full-res render. Works on the GL Compatibility renderer.
- **Throw + stick:** same mechanics family as Null Charge (sticky throwable, already designed) — projectile arc, freeze + attach on contact. Shared implementation.
- **Netcode (the elegant part):** only the device's *transform* replicates — the video feed is rendered locally by each client from their own copy of the world. **Zero bandwidth for the feed.** And each client renders only *their own* camera's viewport (enemy cameras don't render on your machine at all), so worst case is one extra low-res viewport per client regardless of player count. Ideal fit for P2P host budgets.
- **Effort estimate:** working prototype ~a day (sticky projectile + SubViewport + HUD corner); production quality a few days (feed frame/scanline shader, destroyed-feed static, deploy/recall rules, cleanup). Far cheaper than Clone or host migration; comparable to a single weapon.

## Interactions with decided systems

- **Intel family balance:** overlaps Pulse Sight (Eye chrome intel) — differentiate: camera = persistent fixed-angle worldspace intel that enemies can find and destroy; Pulse Sight = on-demand through-wall pulses. Both feed the "information is extremely valuable" §8 philosophy.
- **Counterplay:** the device should be visible and shootable (small HP like Null Charge); feed cuts to static when destroyed. Does a Null field disable it (it's chrome, not a Manifestation — presumably no)? Does Wraith show up on camera (phased = hard to spot in person; on camera too?)?
- **Corner HUD real estate:** Steam Deck screen is small; PiP size/toggle needs care. Consider hold-to-view instead of always-on.
- **Slot question:** equipment-class (no body slot) like Null Charge, or does an "always-on second viewpoint" deserve Eye-slot competition with Pulse Sight/Smart Rig? Owner call — Eye-slot placement would make the intel choices a real trilemma.

## Open questions

- One camera at a time or multiple with feed-switching?
- Always-on PiP vs hold-a-button-to-view (attention cost as balance)?
- Buy cost + reservation (if any); retrievable/redeployable?
- Can allies view your camera feed (chrome-networked, like the Pulse Sight share rule)?

## Research notes

(none yet)
