# BRIEF — Windbags v06 "Showroom"

**Lineage:** v01 core → v02 hazards/music → v03 dock+hats+net hardening →
v04 postcards/polish → v05 beacons/wind vane/export presets → **v06**.
See earlier briefs for architecture; nothing structural changed here.

**What v06 adds — visual charm & identity:**
- **Live courier preview** in the menu: a SubViewport with its own World3D
  showing your courier (colour + hat) slowly turning and bouncing. A Courier
  instance with `process_mode = DISABLED` doubles as a mannequin.
- **Waterfalls**: ~55 % of villages get a stream across the meadow that spills
  off the rim as an animated, mist-fading ribbon (`shaders/waterfall.gdshader`).
- **Waving chute flags**, a **breathing envelope** (pulses with burner bursts,
  sags with leaks), gulls scaled up 1.6× for readability.
- **Softer cloud sea**: wider light bands + gentler per-pixel normals — reads as
  fluffy instead of speckled when you're gliding low.
- HUD: dock subtitle shortened to stop overlapping the delivery counter.
- `tests/vista.gd`: frames a waterfall island for a screenshot.

**Fork directions:** lean further into the diorama look (tilt-shift DOF,
paper-cut cloud layers); give each island a distinct biome/identity (a
lighthouse rock, a clockwork town, an orchard); day/night ambient life
(fireflies at dusk, kites flying from cottages).
