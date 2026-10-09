# BRIEF — Windbags v04 "Postcards & Polish"

**Lineage:** v01 core balloon airmail → v02 hazards (gulls, bramble clouds,
popping, crewmate throwing, parcel flavors, music) → v03 dock phase/bell,
hats, ready-peer networking → **v04**. Earlier briefs cover the architecture.

**What v04 adds:**
- **Postcards** (`postcards.gd`): each player's own camera silently snaps a
  "postcard" (HUD hidden for one frame) at comedic moments — getting popped,
  falling overboard ("going down"), being thrown by a crewmate ("Yeeted by X",
  top priority), a gull stealing post, a fragile smash, AIRMAIL deliveries.
  Up to 8 kept by priority; the best 3 appear as tilted polaroids with
  handwritten captions on the end-of-day screen. Local-only: every friend gets
  their own album of the same disaster → screenshot/share fodder.
- **Delivery confetti** (CPUParticles3D burst in the rubber palette).
- **Wicker weave shader** (`shaders/wicker.gdshader`) for the basket walls —
  over/under strands projected per face, same toon light model.
- **Smooth cloud sea**: per-pixel normals sampled from the same height field
  in the fragment shader, replacing faceted vertex normals → billowy shading.
- Stats credited to nobody (id 0, e.g. wind-delivered parcels) are ignored.
- `tests/postcards.gd` drives a pop, a chute delivery and the results screen.

**Known gaps:** postcards aren't saved to disk or shared between peers; no
photo-mode; delivery postcard depends on what your camera happened to see.

**Fork directions:** save the album as a scrapbook across runs (a persistent
"crew yearbook"); let players vote on the day's best postcard; make
photography a job (a "press courier" with a camera who earns stamps for
capturing disasters); export the polaroid strip as a PNG to share.
