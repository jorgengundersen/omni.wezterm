local path = require("omni.path")

local M = {}

function M.scan(source)
  local max_depth = source.max_depth or 5

  local success, stdout = wezterm.run_child_process({
    "find",
    source.path,
    "-maxdepth",
    tostring(max_depth),
    "-type",
    "d",
    "-name",
    ".git",
  })

  if not success then
    wezterm.log_warn(
      string.format("omni.wezterm: git_repos scan failed for '%s', skipping", source.path)
    )
    return {}
  end

  if stdout == "" then
    return {}
  end

  local source_basename = path.basename(source.path)
  local entries = {}

  for line in stdout:gmatch("[^\n]+") do
    -- Strip /.git suffix to get project path
    local project_path = line:match("^(.+)/%.git$")
    if project_path then
      -- Label is relative: source_basename/relative_path_from_source
      local relative = project_path:sub(#source.path + 2) -- +2 for trailing /
      local label = source_basename .. "/" .. relative
      entries[#entries + 1] = {
        id = project_path,
        label = label,
        workspace_name = label:gsub("%.", "_"),
      }
    end
  end

  return entries
end

return M
