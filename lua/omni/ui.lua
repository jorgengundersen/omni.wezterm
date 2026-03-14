local M = {}

function M.build_choices(entries)
  local choices = {}
  for i, entry in ipairs(entries) do
    choices[i] = { id = entry.id, label = entry.label }
  end
  return choices
end

function M.build_workspace_choices(names)
  local choices = {}
  for i, name in ipairs(names) do
    choices[i] = { id = name, label = name }
  end
  return choices
end

return M
