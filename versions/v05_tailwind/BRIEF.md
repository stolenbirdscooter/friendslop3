# BRIEF — Windbags v05 "Tailwind"

**Lineage:** v01 core (altitude-wind balloon airmail, crew-weight tilt, puff
glide) → v02 hazards (gulls, bramble clouds, popping, crewmate throwing, parcel
flavors, generative waltz music) → v03 dock phase + departure bell, hats,
ready-peer networking → v04 auto postcards/polaroids, confetti, wicker shader,
smooth cloud sea → **v05**. Earlier briefs hold the architecture details.

**What v05 adds — readability & shippability:**
- **Destination beacons**: a soft additive light pillar (`shaders/beacon.gdshader`)
  rises from every island that still has post waiting (and from the Post Office
  once the basket is empty), tinted with the island colour, pulsing upward.
  Solves "where are we going?" at 400 m through fog.
- **Wind vane** on the basket's front-left post: a brass arrow that swings to
  the wind of the balloon's *current* layer — the physical twin of the HUD's
  altimeter arrows.
- **Balance**: helm propeller thrust 1.25 → 0.75 so wind layers stay the main
  way to steer (the propeller trims, it doesn't fight the sky).
- `export_presets.cfg` (Linux / Windows / macOS, tests excluded). With export
  templates for 4.7.2 installed:
  `godot --headless --path game --export-release Linux` → `build/linux/`.
- Island window lighting only re-applies materials when dusk state changes.

**State of the game at v05:** a complete co-op session loop — dock → ring bell
→ fly by choosing wind layers → throw/carry parcels (and friends) into chutes
while fending off gulls, bramble clouds and leaks → sunset results with awards
and your own polaroids → next day with more parcels/hazards, or back to Day 1.

**Untested:** real-human balance (day length 330 s, quota ~55–75 %), ENet over
the internet (LAN/localhost verified), performance on low-end GPUs (built for
Compatibility renderer; cloud sea is a 200×200 grid).

**Fork directions:** a second balloon for 4v4 rival post offices; procedural
"route contracts" chosen at the dock (risky high-pay islands); nighttime
lantern deliveries where the beacons are the only light; a story campaign
following the Postmaster's letters; or a calm, hazard-free "Sunday post" mode.
