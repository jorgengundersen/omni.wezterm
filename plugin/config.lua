local path = require("path")

local M = {}

local VALID_TYPES = {
  git_repos = true,
  children = true,
  grandchildren = true,
  self = true,
}

function M.validate(raw)
  local sources = raw.sources

  if sources == nil then
    return { sources = {} }
  end

  if type(sources) ~= "table" then
    error('omni.wezterm: config error: "sources" must be an array of tables')
  end

  local validated = {}

  for i, source in ipairs(sources) do
    -- path is required and must be a string
    if source.path == nil then
      error(
        string.format("omni.wezterm: config error in source #%d: missing required field 'path'", i)
      )
    end
    if type(source.path) ~= "string" then
      error(string.format("omni.wezterm: config error in source #%d: 'path' must be a string", i))
    end

    -- type is required and must be valid
    if source.type == nil then
      error(
        string.format("omni.wezterm: config error in source #%d: missing required field 'type'", i)
      )
    end
    if not VALID_TYPES[source.type] then
      error(
        string.format(
          "omni.wezterm: config error in source #%d: unknown type '%s'"
            .. " (expected git_repos|children|grandchildren|self)",
          i,
          tostring(source.type)
        )
      )
    end

    -- Expand path
    local home = wezterm.home_dir()
    local expanded, err = path.expand(source.path, home)
    if not expanded then
      wezterm.log_warn(string.format("omni.wezterm: source #%d %s, skipping", i, err))
    else
      validated[#validated + 1] = {
        path = expanded,
        type = source.type,
        max_depth = source.max_depth or 5,
      }
    end
  end

  return { sources = validated }
end

function M.load(config_path)
  local home = wezterm.home_dir()
  local file_path = config_path or (home .. "/.config/omni/config.toml")

  local content = wezterm.read_file(file_path)
  if content == nil then
    wezterm.log_info(
      string.format("omni.wezterm: config file not found at %s, using defaults", file_path)
    )
    return { sources = {} }
  end

  local ok, raw = pcall(wezterm.serde.toml_decode, content)
  if not ok then
    error(string.format("omni.wezterm: failed to parse config at %s: %s", file_path, tostring(raw)))
  end

  return M.validate(raw)
end

return M
