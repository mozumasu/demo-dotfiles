local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- herdr 用のキーを kitty キーボードプロトコルの CSI u 形式で直接送る
-- (kitty キーボードを有効にすると IME と相性が悪く herdr で Esc が効かなくなるため)
-- mods の値は 1 + Shift(1) + Alt(2) + Ctrl(4) + Cmd(8)
local function csi_u(key, mods, codepoint, mod_value)
	return { key = key, mods = mods, action = act.SendString(string.format("\x1b[%d;%du", codepoint, mod_value)) }
end

local herdr_keys = {
	-- IME 経由だと C-q の 1 回目が消えるので、herdr の prefix 用に ^Q を直接送る
	{ key = "q", mods = "CTRL", action = act.SendString("\x11") },
	-- Cmd+t: new_tab
	csi_u("t", "CMD", string.byte("t"), 9),
	-- Ctrl+Tab / Ctrl+Shift+Tab: next_tab / previous_tab
	csi_u("Tab", "CTRL", 9, 5),
	csi_u("Tab", "CTRL|SHIFT", 9, 6),
	-- Cmd+Ctrl+p / Cmd+Ctrl+n: previous_agent / next_agent
	-- (Karabiner で Cmd+↑ / Cmd+↓ に変換されて届くので、矢印キーの修飾付き形式で送る)
	{ key = "UpArrow", mods = "CMD", action = act.SendString("\x1b[1;9A") },
	{ key = "DownArrow", mods = "CMD", action = act.SendString("\x1b[1;9B") },
	-- Shift+Backspace: focus_pane_left
	csi_u("Backspace", "SHIFT", 127, 2),
}
-- Cmd+1..9: switch_tab
for i = 1, 9 do
	table.insert(herdr_keys, csi_u(tostring(i), "CMD", string.byte(tostring(i)), 9))
end
-- Ctrl+Shift+j/k/l: focus_pane_down/up/right, Ctrl+Shift+z: zoom
for _, c in ipairs({ "j", "k", "l", "z" }) do
	table.insert(herdr_keys, csi_u(c, "CTRL|SHIFT", string.byte(c), 6))
	table.insert(herdr_keys, csi_u(c:upper(), "CTRL|SHIFT", string.byte(c), 6))
end

M.leader = { key = ";", mods = "CTRL", timeout_milliseconds = 1000 }

M.keys = {
	-- Leader (C-;) 系
	-- ペイン分割 (leader r: 右に分割, leader d: 下に分割)
	{ key = "r", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	-- ペインを閉じる (leader x)
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
	-- タブの作成 (leader t)
	{ key = "t", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
	-- タブの切り替え (leader Tab: 次, leader Shift+Tab: 前)
	{ key = "Tab", mods = "LEADER", action = act.ActivateTabRelative(1) },
	{ key = "Tab", mods = "LEADER|SHIFT", action = act.ActivateTabRelative(-1) },

	-- 終了
	{ key = "q", mods = "SUPER", action = act.QuitApplication },
	-- ウィンドウ操作
	{ key = "Enter", mods = "ALT", action = act.ToggleFullScreen },
	{ key = "n", mods = "SUPER", action = act.SpawnWindow },
	-- タブ操作
	{ key = "T", mods = "CTRL", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "w", mods = "SUPER", action = act.CloseCurrentTab({ confirm = true }) },
	-- Pane操作
	{ key = '"', mods = "ALT|CTRL", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "%", mods = "ALT|CTRL", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "LeftArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Left") },
	{ key = "LeftArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Left", 1 }) },
	{ key = "RightArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Right") },
	{ key = "RightArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Right", 1 }) },
	{ key = "UpArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Up") },
	{ key = "UpArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Up", 1 }) },
	{ key = "DownArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Down") },
	{ key = "DownArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Down", 1 }) },

	-- フォントサイズ変更
	{ key = "+", mods = "SUPER", action = act.IncreaseFontSize },
	{ key = "=", mods = "SUPER", action = act.IncreaseFontSize },
	{ key = "-", mods = "SUPER", action = act.DecreaseFontSize },
	{ key = "0", mods = "SUPER", action = act.ResetFontSize },

	{ key = "c", mods = "SUPER", action = act.CopyTo("Clipboard") },
	{ key = "v", mods = "SUPER", action = act.PasteFrom("Clipboard") },
	{ key = "C", mods = "CTRL", action = act.CopyTo("Clipboard") },

	-- Debug
	{ key = "R", mods = "CTRL", action = act.ReloadConfiguration },
	{ key = "r", mods = "SUPER", action = act.ReloadConfiguration },

	-- コマンドパレット
	{ key = "P", mods = "CTRL", action = act.ActivateCommandPalette },
	-- 文字選択パレット
	{
		key = "U",
		mods = "CTRL",
		action = act.CharSelect({ copy_on_select = true, copy_to = "ClipboardAndPrimarySelection" }),
	},

	-- モード切替
	-- コピーモード
	{ key = "X", mods = "CTRL", action = act.ActivateCopyMode },
	-- サーチモード
	{ key = "f", mods = "SUPER", action = act.Search("CurrentSelectionOrEmptyString") },
	{ key = "F", mods = "CTRL", action = act.Search("CurrentSelectionOrEmptyString") },

	-- 誤爆するので非有効にしがち
	{ key = "k", mods = "SUPER", action = act.ClearScrollback("ScrollbackOnly") },
	{ key = "m", mods = "SUPER", action = act.Hide },
	{ key = "H", mods = "CTRL", action = act.HideApplication },

	-- スクロール
	{ key = "PageUp", mods = "SHIFT", action = act.ScrollByPage(-1) },
	{ key = "PageDown", mods = "SHIFT", action = act.ScrollByPage(1) },

	-- コピー・ペースト
	{ key = "Copy", mods = "NONE", action = act.CopyTo("Clipboard") },
	{ key = "Paste", mods = "NONE", action = act.PasteFrom("Clipboard") },
}

M.key_tables = {
	copy_mode = {
		-- モードの終了
		{ key = "c", mods = "CTRL", action = act.Multiple({ "ScrollToBottom", { CopyMode = "Close" } }) },
		{ key = "q", mods = "NONE", action = act.Multiple({ "ScrollToBottom", { CopyMode = "Close" } }) },
		{ key = "Escape", mods = "NONE", action = act.Multiple({ "ScrollToBottom", { CopyMode = "Close" } }) },

		-- Vim風のキーバインド
		{ key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
		{ key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
		{ key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
		{ key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
		{ key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
		{ key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
		{ key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
		{ key = ",", mods = "NONE", action = act.CopyMode("JumpReverse") },
		{ key = ";", mods = "NONE", action = act.CopyMode("JumpAgain") },
		{ key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
		{ key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
		{ key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
		{ key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
		{ key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
		{ key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
		{ key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
		{ key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
		{ key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
		{ key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
		{ key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
		{ key = "O", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
		{ key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
		{ key = "o", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEnd") },
		{ key = "m", mods = "ALT", action = act.CopyMode("MoveToStartOfLineContent") },
		{ key = "b", mods = "CTRL", action = act.CopyMode("PageUp") },
		{ key = "f", mods = "CTRL", action = act.CopyMode("PageDown") },
		{ key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
		{ key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
		{ key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
		{ key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
		{ key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
		{
			key = "y",
			mods = "NONE",
			action = act.Multiple({
				{ CopyTo = "ClipboardAndPrimarySelection" },
				{ Multiple = { "ScrollToBottom", { CopyMode = "Close" } } },
			}),
		},
		{ key = "PageUp", mods = "NONE", action = act.CopyMode("PageUp") },
		{ key = "PageDown", mods = "NONE", action = act.CopyMode("PageDown") },
		{ key = "End", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
		{ key = "Home", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
		{ key = "LeftArrow", mods = "NONE", action = act.CopyMode("MoveLeft") },
		{ key = "LeftArrow", mods = "ALT", action = act.CopyMode("MoveBackwardWord") },
		{ key = "RightArrow", mods = "NONE", action = act.CopyMode("MoveRight") },
		{ key = "RightArrow", mods = "ALT", action = act.CopyMode("MoveForwardWord") },
		{ key = "UpArrow", mods = "NONE", action = act.CopyMode("MoveUp") },
		{ key = "DownArrow", mods = "NONE", action = act.CopyMode("MoveDown") },
	},

	search_mode = {
		{ key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
		{ key = "n", mods = "CTRL", action = act.CopyMode("NextMatch") },
		{ key = "p", mods = "CTRL", action = act.CopyMode("PriorMatch") },
		{ key = "r", mods = "CTRL", action = act.CopyMode("CycleMatchType") },
		{ key = "u", mods = "CTRL", action = act.CopyMode("ClearPattern") },
	},
}

function M.apply_to_config(config)
	-- デフォルトのキーバインドは使わず、ここで定義したものだけを有効にする
	config.disable_default_key_bindings = true
	config.leader = M.leader
	config.keys = config.keys or {}
	for _, k in ipairs(M.keys) do
		table.insert(config.keys, k)
	end
	-- herdr 用は最後に入れて優先させる
	for _, k in ipairs(herdr_keys) do
		table.insert(config.keys, k)
	end
	config.key_tables = M.key_tables
end

return M
