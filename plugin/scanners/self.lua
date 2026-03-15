local path = require("path")

local M = {}

function M.scan(source)
  local dir = wezterm.read_dir(source.path)
  if dir == nil then
    wezterm.log_warn(
      string.format("omni.wezterm: source path '%s' does not exist, skipping", source.path)
    )
    return {}
  end

  local label = path.basename(source.path)
  return {
    {
      id = source.path,
      label = label,
      workspace_name = label:gsub("%.", "_"),
    },
  }
end

return M
