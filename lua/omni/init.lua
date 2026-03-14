local wezterm = _G.wezterm

local M = {}

function M.apply_to_config(config, opts)
  if config._omni_applied then
    return
  end
  config._omni_applied = true

  opts = opts or {}
  local key = opts.key or "p"
  local mods = opts.mods or "CTRL|SHIFT"

  config.keys = config.keys or {}

  config.keys[#config.keys + 1] = {
    key = key,
    mods = mods,
    action = wezterm.action.InputSelector({
      title = "Omni",
      choices = {
        { id = "hello", label = "Hello, World!" },
      },
      action = wezterm.action_callback(function(_window, selection)
        wezterm.log_info("omni.wezterm: selected " .. selection.id)
      end),
    }),
  }
end

return M
