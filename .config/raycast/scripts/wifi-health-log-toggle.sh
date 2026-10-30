#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Wi-Fi Health Log Toggle
# @raycast.mode compact
# @raycast.packageName Wi-Fi
# @raycast.icon 📶
# @raycast.description Wi-Fi の状態を 1 分ごとに記録する launchd のジョブを止めたり動かしたりする

# ジョブの定義は .config/nix/home-manager/default.nix の launchd.agents.wifi-health-log
# bootout だけだと再起動やログインで動き出すので、disable もして止めた状態を保つ
label="org.nix-community.home.wifi-health-log"
domain="gui/$(id -u)"
plist="$HOME/Library/LaunchAgents/$label.plist"

if launchctl print "$domain/$label" >/dev/null 2>&1; then
  launchctl disable "$domain/$label"
  launchctl bootout "$domain/$label"
  echo "Wi-Fi の記録を止めました"
else
  if [ ! -f "$plist" ]; then
    echo "$plist がありません。darwin-rebuild switch を実行してください"
    exit 1
  fi
  launchctl enable "$domain/$label"
  launchctl bootstrap "$domain" "$plist"
  echo "Wi-Fi の記録を始めました"
fi
