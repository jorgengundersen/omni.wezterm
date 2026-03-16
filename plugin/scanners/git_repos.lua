local wezterm = require("wezterm")
local path = require("path")

local M = {}

local function is_windows()
  return wezterm.target_triple:find("windows") ~= nil
end

local function make_entry(project_path, source_path, source_basename)
  local relative = project_path:sub(#source_path + 2) -- +2 for separator
  local label = source_basename .. "/" .. relative
  return {
    id = project_path,
    label = label,
    workspace_name = label:gsub("%.", "_"),
  }
end

local function walk_windows(dir, max_depth, depth, entries, source_path, source_basename)
  if depth > max_depth then
    return
  end

  local children = wezterm.read_dir(dir)
  if not children then
    return
  end

  for _, child in ipairs(children) do
    local name = child:match("([^/\\]+)$")
    if name == ".git" then
      entries[#entries + 1] = make_entry(dir, source_path, source_basename)
    else
      walk_windows(child, max_depth, depth + 1, entries, source_path, source_basename)
    end
  end
end

local function scan_windows(source)
  local max_depth = source.max_depth or 5
  local source_basename = path.basename(source.path)
  local entries = {}

  walk_windows(source.path, max_depth, 1, entries, source.path, source_basename)

  return entries
end

local function scan_unix(source)
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
    local project_path = line:match("^(.+)/%.git$")
    if project_path then
      entries[#entries + 1] = make_entry(project_path, source.path, source_basename)
    end
  end

  return entries
end

function M.scan(source)
  if is_windows() then
    return scan_windows(source)
  end
  return scan_unix(source)
end

return M
