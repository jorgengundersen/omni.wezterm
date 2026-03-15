local ROOT = (...):match("^(.-)%.") or ...
local path = require(ROOT .. ".path")

local M = {}

function M.scan(source)
  local dir = wezterm.read_dir(source.path)
  if dir == nil then
    wezterm.log_warn(
      string.format("omni.wezterm: source path '%s' does not exist, skipping", source.path)
    )
    return {}
  end

  local source_basename = path.basename(source.path)
  local entries = {}

  for _, group_path in ipairs(dir) do
    local group_dir = wezterm.read_dir(group_path)
    if group_dir ~= nil then
      local group_basename = path.basename(group_path)
      for _, child_path in ipairs(group_dir) do
        local child_dir = wezterm.read_dir(child_path)
        if child_dir ~= nil then
          local label = source_basename .. "/" .. group_basename .. "/" .. path.basename(child_path)
          entries[#entries + 1] = {
            id = child_path,
            label = label,
            workspace_name = label:gsub("%.", "_"),
          }
        end
      end
    end
  end

  return entries
end

return M
