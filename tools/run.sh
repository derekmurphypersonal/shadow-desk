#!/usr/bin/env bash
# Import (builds the .godot cache) and run the game from source.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
exec "$GODOT" --path . "$@"
