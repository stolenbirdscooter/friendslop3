# BRIEF — Windbags v07 "Crew Comfort"

**Lineage:** v01 core → v02 hazards/music → v03 dock+hats+net → v04 postcards
→ v05 beacons/vane/export presets → v06 menu preview/waterfalls → **v07**.
Architecture unchanged; see v01–v03 briefs.

**What v07 adds — playable by everyone on the couch or the call:**
- **Full gamepad support**: left stick moves (and steers at the helm), right
  stick looks (`look_*` actions, 0.15 deadzone), right trigger/RB throws or
  shoves, A jump/puff, X interact, Y squeak, Start pauses.
- **Settings** (`settings.gd`, static): look sensitivity, field of view,
  master volume, music volume, invert-Y — in the pause menu ("Tea Break"),
  persisted to `user://prefs.cfg` when the menu closes, applied on launch.
- `tests/pause.gd` builds and screenshots the pause menu.

**Fork directions:** local split-screen co-op (the courier/camera code is
already per-node; would need per-device input routing); rebindable controls;
colour-blind-safe island markers (shapes per island in addition to colour).
