#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title AWS VPN Connect
# @raycast.mode compact
# @raycast.packageName AWS VPN
# @raycast.icon 🔐
# @raycast.description AWS VPN Client で前回のプロファイルに接続し、ウィンドウを隠す

# AWS VPN Client は macOS の VPN 設定に登録されず、URL スキームや CLI もないため、画面の「接続」ボタンを押して接続する
# Electron 製なので AXManualAccessibility を true にしないとボタンが見えない。Raycast にアクセシビリティの許可が必要
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

		if my findButton(window 1, {"接続解除", "切断", "Disconnect"}) is not missing value then
			set visible to false
			return "すでに接続しています"
		end if

		set btn to missing value
		repeat 30 times
			set btn to my findButton(window 1, {"接続", "Connect"})
			if btn is not missing value then exit repeat
			delay 0.1
		end repeat
		if btn is missing value then return "「接続」ボタンが見つかりません"
		click btn
		set visible to false
	end tell
end tell
return "接続を始めました。ブラウザでログインしてください"
EOF
