local wezterm = _G.wezterm
local ROOT = (...):match("^(.-)%.") or ...

local config_mod = require(ROOT .. ".config")
local discovery = require(ROOT .. ".discovery")
local ui = require(ROOT .. ".ui")
local workspace = require(ROOT .. ".workspace")

local M = {}

function M.apply_to_config(config, opts)
  if config._omni_applied then
    return
  end
  config._omni_applied = true

  opts = opts or {}
  local key = opts.key or "p"
  local mods = opts.mods or "CTRL|SHIFT"
  local active_key = opts.active_key or "s"
  local active_mods = opts.active_mods or "CTRL|SHIFT"
  local config_file = opts.config_file
  local title = opts.title or "Switch Project"
  local fuzzy = opts.fuzzy
  if fuzzy == nil then
    fuzzy = true
  end
  local active_title = opts.active_title or "Switch Workspace"
  local active_fuzzy = opts.active_fuzzy
  if active_fuzzy == nil then
    active_fuzzy = true
  end

  config.keys = config.keys or {}

  -- Project selector keybinding
  config.keys[#config.keys + 1] = {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(window, pane)
      local ok, cfg = pcall(config_mod.load, config_file)
      if not ok then
        wezterm.log_error(tostring(cfg))
        window:toast_notification("omni.wezterm", tostring(cfg))
        return
      end

      local entries = discovery.discover(cfg)
      local choices = ui.build_choices(entries)

      window:perform_action(
        wezterm.action.InputSelector({
          title = title,
          fuzzy = fuzzy,
          choices = choices,
          action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
            if id == nil then
              return
            end
            local name = workspace.derive_name(label)
            workspace.switch_or_create(inner_window, inner_pane, id, name)
          end),
        }),
        pane
      )
    end),
  }

  -- Active workspace selector keybinding
  config.keys[#config.keys + 1] = {
    key = active_key,
    mods = active_mods,
    action = wezterm.action_callback(function(window, pane)
      local names = workspace.list_active()
      if #names == 0 then
        wezterm.log_info("omni.wezterm: no active workspaces")
        return
      end

      local choices = ui.build_workspace_choices(names)

      window:perform_action(
        wezterm.action.InputSelector({
          title = active_title,
          fuzzy = active_fuzzy,
          choices = choices,
          action = wezterm.action_callback(function(inner_window, inner_pane, id)
            if id == nil then
              return
            end
            workspace.switch_to(inner_window, inner_pane, id)
          end),
        }),
        pane
      )
    end),
  }
end

return M
