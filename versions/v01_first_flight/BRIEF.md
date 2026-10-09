# BRIEF — Windbags v01 "First Flight"

**What it is:** The first playable vertical slice of WINDBAGS, a 1–6 player
co-op "friendslop" game. Inflatable rubber postal couriers crew a patchwork
hot-air balloon over a sea of clouds and deliver parcels to floating islands
before sunset. Godot 4.7.2, GL Compatibility renderer, Jolt physics, ENet.
No imported art: everything is primitives + shaders + synthesized audio
(fonts: Grandstander/Nunito, OFL).

**Core loop:** Day starts landed at the Post Office island with N parcels in
the basket. Pump the burner (heat ↑) / vent (heat ↓) to change altitude; each
altitude has a different wind direction (`scripts/wind.gd`), so you steer by
picking a layer. Throw parcels into the island chute whose colour matches the
parcel tag. Wrong chute spits it back. Quota per day; miss it → back to Day 1.
End-of-day awards (Golden Arm, Frequent Flyer, Menace…).

**Signature mechanics:** basket tilts toward the crew's centre of mass
(pendulum model in `balloon.gd::_simulate`); couriers puff up mid-air to glide
(hold Space); falling into the cloud sea = 4 s "lost in the fluff" then respawn
in basket; pitch-controlled squeak emote (Q); shove (LMB empty-handed).

**Architecture (all code-built, `main.tscn` is a bare Node):**
- `net.gd` (autoload `Net`): ENet host/join/solo (OfflineMultiplayerPeer), roster.
- `sfx.gd` (autoload `Sfx`): procedural AudioStreamWAV synth; `play/play3d/make_loop`.
- `game.gd`: world builder + host-authoritative day logic; 20 Hz snapshot RPC
  carrying clock, balloon state and parcel transforms **in balloon-local space**.
- `balloon.gd`: AnimatableBody3D; host simulates heat/lift/wind/tilt/island
  collision analytically. Use `balloon.xform()` (NOT `global_transform`, which
  lags a physics tick due to sync_to_physics).
- `courier.gd`: CharacterBody3D, owner-simulated; while inside the basket its
  position is stored balloon-local and re-applied each tick (perfect riding).
- `parcel.gd`: RigidBody3D on host, kinematic mirror on clients.
- `island.gd`: procedural floating islands, cottages, trees, mail chute Area3D.
- `hud.gd`: custom-drawn HUD (altimeter with per-layer wind arrows + island
  height ticks, heat gauge with equilibrium marker, compass, toasts, results).
- `main.gd`: menu + CLI flags `--solo --host --join=IP --name= --color= --test=NAME --shot=prefix:t1,t2`.
- `tests/fly.gd`: scripted playtest that screenshots.

**Known gaps in v01:** no hazards yet; no music; parcels can't be kicked by
walking; held parcel sync is snap-to-hand; no reconnect; no lobby (drop-in);
solo can feel lonely; balance untested with humans.

**Directions a fork could take from here:** make it competitive (rival balloon
crews racing to the same chutes); turn the world into a single giant moving
sky-whale instead of islands; make the balloon a multi-deck airship with more
stations; lean into physics comedy by letting couriers carry/throw each other;
replace delivery with rescue (catching falling people); go asymmetric (one
player is the Postmaster on the ground radioing directions).
