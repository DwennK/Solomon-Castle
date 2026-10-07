#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p outputs/windows
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --headless --path . --export-release 'macOS' outputs/La-Tour-des-Cendres-macOS.zip
./tools/godot.sh --headless --path . --export-release 'Windows' outputs/windows/La-Tour-des-Cendres.exe
