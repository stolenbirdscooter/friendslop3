# BRIEF — Windbags v02 "Mayhem"

**Lineage:** builds directly on v01 "First Flight" (balloon airmail co-op;
altitude-layer wind steering; crew-weight basket tilt; puff-glide couriers;
parcel throwing into island chutes; day quota). Read v01's BRIEF for the base
architecture — it still applies (`balloon.xform()`, balloon-local snapshots,
owner-simulated couriers, host-authoritative parcels).

**What v02 adds (the escalation layer):**
- **Gulls** (`gull.gd`): host-simulated AI that circles the balloon, then dives
  to steal a loose parcel (parcel `holder` < 0 means "held by gull −id") or peck
  a courier (POP). Scared by squeaks within 8 m, shoves within 2.8 m, or being
  beaned by a thrown parcel. A gull that escapes 70 m away with post = parcel lost.
  Spawn cadence scales with day; synced in the snapshot.
- **Bramble clouds** (`bramble.gd`): thorny storm clouds whose position is a pure
  function of the shared clock (no sync). Touching one pops couriers; the
  envelope touching one adds a **leak** (more heat loss, visible air jets, hiss).
- **Patch kit** station (sewing basket, front wall): hold E for 2 s per leak.
- **Popping**: popped couriers zip around like a released balloon for 1.5 s, then
  become a flat pancake (slow, can't jump/puff/hold). Crewmates carry the pancake
  to the burner pump and press E to reinflate; otherwise self-reinflate after 22 s.
- **Carry & throw crewmates**: E on a courier picks them up (the carried player's
  peer accepts — they own their body); hold LMB to throw them. Carried players
  mash Space to wriggle free. Couriers can be thrown while holding parcels →
  "courier cannon" deliveries.
- **Parcel flavors**: fragile (shatters on hard impact), heavy (weight 1.5, tips
  the basket, throws at half power), hen (a live hen in a hatbox that hops
  around and clucks), express (+25 stamps if delivered within 150 s).
- **Procedural music** (`music.gd`, autoload `Music`): generative 3/4
  waltz-musette, moods menu/morning/dusk/night/results, intensity rises with
  gull/leak danger, stingers for deliveries, day start, failure.
- New synthesized SFX: gull squawk, hen cluck, glass shatter.
- Day-1 contextual hints; new end-of-day awards (Lifeguard, Crew Cannon,
  Gull Bonker, Pincushion, Seamstress).
- `tests/mayhem.gd` exercises the hazards headlessly with screenshots.

**Known gaps:** carried-crewmate sync relies on each peer placing the carried
body at the carrier's hand (works, not lag-compensated); no cosmetics or
progression between runs; no lobby/ready-up; tuning untested with real groups.

**Fork directions from here:** make the gulls a full faction with a nest island
you can raid; turn popping into the core mechanic (a pop-tag party mode); make
weather the main antagonist (storm fronts sweep across layers); cut the
hazards entirely and go fully cozy (v01 + music) as a relaxing co-op; or make
the hen parcels breed and multiply in the basket.
