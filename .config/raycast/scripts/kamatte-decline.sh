#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title kamatte decline
# @raycast.mode compact
# @raycast.packageName kamatte
# @raycast.icon 🙅
# @raycast.description 着信を拒否する

export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
command -v kamatte >/dev/null || { echo "kamatte が見つかりません"; exit 1; }
kamatte decline 2>&1 | sed 's/^kamatte: //'
