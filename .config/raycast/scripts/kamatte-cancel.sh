#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title kamatte cancel
# @raycast.mode compact
# @raycast.packageName kamatte
# @raycast.icon ↩️
# @raycast.description 呼び出しを取り消す

export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
command -v kamatte >/dev/null || { echo "kamatte が見つかりません"; exit 1; }
kamatte cancel 2>&1 | sed 's/^kamatte: //'
