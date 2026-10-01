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
}

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

-- 最後に、weztermに設定を戻す
return config
