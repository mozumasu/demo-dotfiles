#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title kamatte toggle
# @raycast.mode compact
# @raycast.packageName kamatte
# @raycast.icon 🔁
# @raycast.description 着信中なら出る、呼び出し中なら取り消す、通話中なら切る

export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
command -v kamatte >/dev/null || { echo "kamatte が見つかりません"; exit 1; }
kamatte toggle 2>&1 | sed 's/^kamatte: //'
