#!/usr/bin/env bash
# Export release builds for macOS, Windows and Linux.
# Needs Godot 4.7 on PATH as `godot` (or set GODOT=...) and matching export templates
# (Godot editor > Editor > Manage Export Templates > Download).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/macos build/windows build/linux
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "macOS" build/macos/ShadowDesk.zip
"$GODOT" --headless --path . --export-release "Windows" build/windows/ShadowDesk.exe
"$GODOT" --headless --path . --export-release "Linux" build/linux/ShadowDesk.x86_64
echo "Builds are in ./build"
