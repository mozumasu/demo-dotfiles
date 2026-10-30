#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Wi-Fi Health Log Status
# @raycast.mode inline
# @raycast.refreshTime 1m
# @raycast.packageName Wi-Fi
# @raycast.icon 📶
# @raycast.description Wi-Fi の状態を記録する launchd のジョブが動いているかを表示する

# inline は refreshTime ごとに自動で実行されるので、切り替えはせず状態を表示するだけにする
# 切り替えは wifi-health-log-toggle.sh で行う
label="org.nix-community.home.wifi-health-log"
log="$HOME/Library/Logs/wifi-health.log"

if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
  echo "オン（最終記録 $(tail -1 "$log" 2>/dev/null | cut -c12-16)）"
else
  echo "オフ"
fi
