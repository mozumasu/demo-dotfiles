#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title kamatte status
# @raycast.mode inline
# @raycast.refreshTime 10s
# @raycast.packageName kamatte
# @raycast.icon 📞
# @raycast.description 誰から誰への着信か、呼び出し中か、通話中かを表示する

export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
command -v kamatte >/dev/null || { echo "kamatte が見つかりません"; exit 1; }
kamatte status --short 2>&1 | head -1
