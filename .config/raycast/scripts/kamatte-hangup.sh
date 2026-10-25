#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title kamatte hangup
# @raycast.mode compact
# @raycast.packageName kamatte
# @raycast.icon 🔴
# @raycast.description 通話を切る

export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
command -v kamatte >/dev/null || { echo "kamatte が見つかりません"; exit 1; }
kamatte hangup 2>&1 | sed 's/^kamatte: //'
