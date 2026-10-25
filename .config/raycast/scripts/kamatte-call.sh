#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title kamatte call
# @raycast.mode compact
# @raycast.packageName kamatte
# @raycast.icon 📞
# @raycast.description 相手を呼び出す

export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
command -v kamatte >/dev/null || { echo "kamatte が見つかりません"; exit 1; }
kamatte call 2>&1 | sed 's/^kamatte: //'
