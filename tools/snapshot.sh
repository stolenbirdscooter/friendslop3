#!/usr/bin/env bash
# Usage: tools/snapshot.sh v01_first_flight
# Copies the live project (game/) into versions/<name>/ as a standalone, buildable Godot project.
set -euo pipefail
cd "$(dirname "$0")/.."
name="$1"
dest="versions/$name"
[ -e "$dest" ] && { echo "$dest exists"; exit 1; }
mkdir -p "$dest"
tar -C game --exclude=.godot -cf - . | tar -C "$dest" -xf -
echo "snapshot -> $dest"
