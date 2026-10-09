# WINDBAGS

*A co-op airmail disaster for 1–6 inflatable couriers.*

You and your friends are rubber balloon-people running a patchwork hot-air
airmail service above an endless sea of cloud. The balloon can barely steer:
every altitude blows a different way, so the crew pumps the burner, vents hot
air and argues about which wind layer to ride. Crowd one side of the basket and
it tips. Fall overboard and you puff yourself up to glide back. Throw parcels
into each floating island's brass mail chute before sunset.

Built with **Godot 4.7.2** (Compatibility renderer). Everything you see and hear
is generated from code — primitive meshes, hand-written shaders, synthesized
sound. The only imported assets are two SIL OFL fonts (Grandstander, Nunito).

## Layout

| Path | What |
| --- | --- |
| `game/` | The live, current project. Open `game/project.godot` in Godot 4.7.2. |
| `versions/vNN_name/` | Frozen, independently buildable snapshots in chronological order. Each has a `BRIEF.md` describing that version for anyone who wants to fork the design from that point. |
| `tools/snapshot.sh` | Freezes `game/` into a new version folder. |
| `DEVLOG.md` | Running design log. |

## Running

```
godot --headless --path game --import  # first time only: import fonts
godot --path game                      # menu
godot --path game -- --solo            # straight into a solo flight
godot --path game -- --host            # host on UDP 24680
godot --path game -- --join=1.2.3.4    # join a host
```

## Building

`game/export_presets.cfg` has Linux, Windows and macOS presets (the same file
ships in every `versions/` snapshot). Install the Godot 4.7.2 export
templates, then for example:

```
godot --headless --path game --export-release Linux
```

## Versions

| Version | Adds |
| --- | --- |
| v01 First Flight | balloon airmail core: wind layers, basket tilt, puff glide, chutes, day quota, ENet |
| v02 Mayhem | gulls, bramble clouds, leaks + patching, popping/pancakes, throwing crewmates, parcel flavors, generative music |
| v03 Dockside | dock phase + departure bell, unlockable hats, ready-peer networking |
| v04 Postcards & Polish | auto-captured polaroid moments, confetti, wicker weave, smooth cloud sea |
| v05 Tailwind | destination beacons, wind vane, propeller rebalance, export presets |
| v06 Showroom | menu courier preview, waterfalls, waving flags, breathing envelope, softer cloud sea |

## Controls

WASD walk · Space jump · hold Space while falling to puff up and glide ·
mouse look · E pick up / put down / use · hold LMB to throw (LMB empty-handed
shoves) · Q squeak · Esc menu.
