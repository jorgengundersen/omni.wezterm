local ROOT = (...):match("^(.-)%.") or ...

local M = {}

local registry = {}

local REQUIRED_FIELDS = { "id", "label", "workspace_name" }

function M.register(scanner_type, scanner)
  registry[scanner_type] = scanner
end

function M.dispatch(source)
  local scanner = registry[source.type]
  if not scanner then
    error("omni.wezterm: unknown scanner type '" .. source.type .. "'")
  end

  local entries = scanner.scan(source)

  for i, entry in ipairs(entries) do
    for _, field in ipairs(REQUIRED_FIELDS) do
      if entry[field] == nil then
        error(
          "omni.wezterm: scanner '"
            .. source.type
            .. "' returned invalid entry #"
            .. i
            .. ": missing field '"
            .. field
            .. "'"
        )
      end
      if type(entry[field]) ~= "string" then
        error(
          "omni.wezterm: scanner '"
            .. source.type
            .. "' returned invalid entry #"
            .. i
            .. ": field '"
            .. field
            .. "' must be a string, got "
            .. type(entry[field])
        )
      end
    end
  end

  return entries
end

M.register("self", require(ROOT .. ".scanners.self"))
M.register("children", require(ROOT .. ".scanners.children"))
M.register("grandchildren", require(ROOT .. ".scanners.grandchildren"))
M.register("git_repos", require(ROOT .. ".scanners.git_repos"))

return M
