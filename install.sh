#!/usr/bin/env bash
# dsh-doctor installer — fetch the latest doctor.sh into ~/.local/bin (or $1).
set -euo pipefail
DEST="${1:-$HOME/.local/bin/dsh-doctor}"
URL="https://raw.githubusercontent.com/gxinxing/dsh-doctor/main/doctor.sh"
mkdir -p "$(dirname "$DEST")"
curl -fsSL "$URL" -o "$DEST"
chmod +x "$DEST"
echo "installed: $DEST"
echo "run: dsh-doctor        # or: dsh-doctor -p headless fix"
