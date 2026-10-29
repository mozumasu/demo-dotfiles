#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title AWS VPN Disconnect
# @raycast.mode compact
# @raycast.packageName AWS VPN
# @raycast.icon 🔓
# @raycast.description AWS VPN Client の接続を切り、ウィンドウを隠す

# 仕組みは aws-vpn-connect.sh と同じで、画面の「切断」ボタンを押す
osascript <<'EOF'
-- entire contents は Electron の画面だと 0 件を返すので、UI elements を再帰でたどる
on findButton(el, labels)
	tell application "System Events"
		repeat with c in (UI elements of el)
			try
				if role of c is "AXButton" then
					set t to ""
					try
						set t to (title of c) as text
					end try
					if t is "" or t is "missing value" then
						try
							set t to (description of c) as text
						end try
					end if
					if labels contains t then return c
				end if
			end try
			set found to my findButton(c, labels)
			if found is not missing value then return found
		end repeat
	end tell
	return missing value
end findButton

if application "AWS VPN Client" is not running then return "AWS VPN Client は起動していません"

-- ウィンドウを閉じたあとは activate だけでは開かないので、Dock のアイコンを押したときと同じ reopen を送る
tell application "AWS VPN Client"
	reopen
	activate
end tell

tell application "System Events"
	tell process "AWS VPN Client"
		-- 起動したばかりだとウィンドウが出るまで数秒かかり、その前に設定した AXManualAccessibility は効かないので、出るまで毎回設定し直す
		repeat 200 times
			try
				set value of attribute "AXManualAccessibility" to true
			end try
			if exists window 1 then exit repeat
			delay 0.1
		end repeat
		if not (exists window 1) then return "AWS VPN Client のウィンドウが開きません"

		set btn to my findButton(window 1, {"接続解除", "切断", "Disconnect"})
		if btn is missing value then
			set visible to false
			return "接続していません"
		end if
		click btn
		set visible to false
	end tell
end tell
return "切断しました"
EOF
