local wezterm = require("wezterm")
local act = wezterm.action
local module = {}
local previous = {} -- 切替前にいた workspace 名
local function toggle_workspace(name, spawn)
	return wezterm.action_callback(function(window, pane)
		local current = wezterm.mux.get_active_workspace()
		if current == name then
			window:perform_action(
				act.SwitchToWorkspace({
					name = previous[name] or "default",
				}),
				pane
			)
		else
			previous[name] = current
			window:perform_action(
				act.SwitchToWorkspace({
					name = name,
					spawn = spawn,
				}),
				pane
			)
		end
	end)
end

-- toggle_workspace はローカル関数なのでキーもここに書く
function module.apply_to_config(config)
	config.keys = config.keys or {}
	-- Leader+s でメモ用の scratch と行き来する
	table.insert(config.keys, { key = "s", mods = "SUPER|CTRL", action = toggle_workspace("scratch") })
end
return module
