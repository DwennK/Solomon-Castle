#!/bin/sh
set -eu
if [ -n "${GODOT_BIN:-}" ]; then
  exec "$GODOT_BIN" "$@"
elif command -v godot >/dev/null 2>&1; then
  exec godot "$@"
elif [ -x "$HOME/.local/share/solomon-castle-tools/Godot.app/Contents/MacOS/Godot" ]; then
  exec "$HOME/.local/share/solomon-castle-tools/Godot.app/Contents/MacOS/Godot" "$@"
else
  echo 'Set GODOT_BIN to the Godot 4.7.2 executable.' >&2
  exit 1
fi
