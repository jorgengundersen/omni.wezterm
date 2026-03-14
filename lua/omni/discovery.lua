local scanners = require("omni.scanners")

local M = {}

function M.discover(config)
  local all_entries = {}
  local seen = {}

  for _, source in ipairs(config.sources) do
    local entries = scanners.dispatch(source)
    for _, entry in ipairs(entries) do
      if not seen[entry.id] then
        seen[entry.id] = true
        all_entries[#all_entries + 1] = entry
      end
    end
  end

  table.sort(all_entries, function(a, b)
    return a.label < b.label
  end)

  return all_entries
end

return M
