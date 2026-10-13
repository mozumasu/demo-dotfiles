-- wezterm API を組み込む
local wezterm = require("wezterm")

-- ここに設定内容を記述していく
local config = wezterm.config_builder()

-- 設定ファイルの変更を自動で読み込む
config.automatically_reload_config = true

-- kitty キーボードプロトコルは IME と組み合わせると herdr で Esc が効かなくなるので無効にする
-- (herdr に必要なキーは keybinds.lua で CSI u を直接送っている)
config.enable_kitty_keyboard = false

-- OSのIME経由でキー入力を処理する
config.use_ime = true

-- Ctrl付きのキーをIME側に先に渡す。これがないとWezTermがC-jを
-- 直接LF(改行)としてptyに送ってしまい、macSKKのかな入力切替と
-- 二重に動作してしまう (SHIFTも漢字変換確定で必要なため含める)
config.macos_forward_to_ime_modifier_mask = "SHIFT|CTRL"

config.font = wezterm.font_with_fallback({ "JetBrains Mono", "HackGen Console NF" })
config.font_size = 18.0

-- 背景を透過
config.window_background_opacity = 0.75
-- ぼかしを追加
config.macos_window_background_blur = 20

require("tab").apply_to_config(config)
require("workspace").apply_to_config(config)
require("keybinds").apply_to_config(config)

-- 最後に、weztermに設定を戻す
return config
