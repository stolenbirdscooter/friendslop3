# BRIEF — Windbags v03 "Dockside"

**Lineage:** v01 (balloon airmail core) → v02 (gulls, bramble clouds, popping,
crewmate throwing, parcel flavors, procedural music) → **v03**. The v01/v02
briefs describe the architecture; all of it still holds.

**What v03 adds — making real sessions work:**
- **Dock phase.** Each day now begins moored at the Post Office (`phase ==
  "dock"`): the clock is frozen, gulls don't spawn, the balloon is tethered
  (`balloon.gd::_simulate` early-out). Anyone can ring the brass **departure
  bell** on the porch (a `Station` of kind BELL parented to the home island) to
  start the day. Lets late joiners climb aboard and gives a social "ready?" beat.
- **Hats** (`hats.gd`): 8 primitive-built hats (Postal Cap, Bobble Beanie, Top
  Hat, Propeller Cap that spins faster when you run/puff, Flower Crown, Traffic
  Cone, Viking Helm, Teapot). Unlocked by **lifetime stamps** saved locally in
  `user://prefs.cfg`; chosen in the menu; sent in the roster so everyone sees them.
- **Network hardening:** host tracks `ready_peers` (peers whose world finished
  building) and couriers/snapshots only send to those — fixes join-time
  "node not found" RPC spam. Verified with a real two-process ENet test
  (`tests/mp_host.gd` + `tests/mp_client.gd`): ring bell, carry host's courier,
  throw — all synchronized, zero errors.
- CLI: `--hat=N` (bypasses unlocks, for testing).

**Known gaps:** no in-game hat preview in menu (name only); no voice/text chat;
no host migration; stamp unlocks are local (honor system); balloon-island
collision is analytic (cylinders), so a basket can clip cottage roofs.

**Fork directions:** turn the dock into a proper hub (shop for balloon
upgrades — bigger burner, sturdier envelope, a crow's nest); persistent crew
save files; a "postcard" photo mode that snapshots funny moments for the end
screen; a seasonal calendar where each week has a different weather gimmick.
