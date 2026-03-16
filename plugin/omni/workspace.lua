local wezterm = require("wezterm")

local M = {}

function M.derive_name(label)
  return label:gsub("%.", "_")
end

function M.switch_or_create(window, pane, path, name)
  window:perform_action(
    wezterm.action.SwitchToWorkspace({ name = name, spawn = { cwd = path } }),
    pane
  )
end

function M.switch_to(window, pane, name)
  window:perform_action(wezterm.action.SwitchToWorkspace({ name = name }), pane)
end

function M.list_active()
  local names = wezterm.mux.get_workspace_names()
  table.sort(names)
  return names
end

return M
