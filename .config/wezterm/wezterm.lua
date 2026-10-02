-- wezterm API を組み込む
local wezterm = require("wezterm")

-- ここに設定内容を記述していく
local config = wezterm.config_builder()

-- 設定ファイルの変更を自動で読み込む
config.automatically_reload_config = true

-- Leaderキーを C-; に設定
config.leader = { key = ";", mods = "CTRL", timeout_milliseconds = 1000 }

-- ペイン分割 (leader r: 右に分割, leader d: 下に分割)
config.keys = {
	{ key = "r", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	-- ペインを閉じる (leader x)
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	-- IME 経由だと C-q の 1 回目が消えるので、herdr の prefix 用に ^Q を直接送る
	{ key = "q", mods = "CTRL", action = wezterm.action.SendString("\x11") },
	-- タブの作成 (leader t)
	{ key = "t", mods = "LEADER", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	-- タブの切り替え (leader Tab: 次, leader Shift+Tab: 前)
	{ key = "Tab", mods = "LEADER", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "Tab", mods = "LEADER|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
}

-- herdr 用のキーを kitty キーボードプロトコルの CSI u 形式で直接送る
-- (kitty キーボードを有効にすると IME と相性が悪く herdr で Esc が効かなくなるため)
-- mods の値は 1 + Shift(1) + Alt(2) + Ctrl(4) + Cmd(8)
local function send_csi_u(key, mods, codepoint, mod_value)
	table.insert(config.keys, {
		key = key,
		mods = mods,
		action = wezterm.action.SendString(string.format("\x1b[%d;%du", codepoint, mod_value)),
	})
end
-- Cmd+t: new_tab
send_csi_u("t", "CMD", string.byte("t"), 9)
-- Cmd+1..9: switch_tab
for i = 1, 9 do
	send_csi_u(tostring(i), "CMD", string.byte(tostring(i)), 9)
end
-- Ctrl+Tab / Ctrl+Shift+Tab: next_tab / previous_tab
send_csi_u("Tab", "CTRL", 9, 5)
send_csi_u("Tab", "CTRL|SHIFT", 9, 6)
-- Cmd+Ctrl+p / Cmd+Ctrl+n: previous_agent / next_agent
-- (Karabiner で Cmd+↑ / Cmd+↓ に変換されて届くので、矢印キーの修飾付き形式で送る)
table.insert(config.keys, { key = "UpArrow", mods = "CMD", action = wezterm.action.SendString("\x1b[1;9A") })
table.insert(config.keys, { key = "DownArrow", mods = "CMD", action = wezterm.action.SendString("\x1b[1;9B") })
-- Shift+Backspace: focus_pane_left
send_csi_u("Backspace", "SHIFT", 127, 2)
-- Ctrl+Shift+j/k/l: focus_pane_down/up/right, Ctrl+Shift+z: zoom
for _, c in ipairs({ "j", "k", "l", "z" }) do
	send_csi_u(c, "CTRL|SHIFT", string.byte(c), 6)
	send_csi_u(c:upper(), "CTRL|SHIFT", string.byte(c), 6)
end

-- kitty キーボードプロトコルは IME と組み合わせると herdr で Esc が効かなくなるので無効にする
-- (herdr に必要なキーは上で CSI u を直接送っている)
config.enable_kitty_keyboard = false

-- OSのIME経由でキー入力を処理する
config.use_ime = true

-- Ctrl付きのキーをIME側に先に渡す。これがないとWezTermがC-jを
-- 直接LF(改行)としてptyに送ってしまい、macSKKのかな入力切替と
-- 二重に動作してしまう (SHIFTも漢字変換確定で必要なため含める)
config.macos_forward_to_ime_modifier_mask = "SHIFT|CTRL"

config.font = wezterm.font("JetBrains Mono")
config.font_size = 18.0

-- 背景を透過
config.window_background_opacity = 0.75
-- ぼかしを追加
config.macos_window_background_blur = 20

require("tab").apply_to_config(config)
require("workspace").apply_to_config(config)

-- 最後に、weztermに設定を戻す
return config
