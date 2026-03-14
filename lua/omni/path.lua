local M = {}

function M.basename(p)
  -- Strip trailing slashes (but not the root slash)
  local stripped = p:match("^(.-)/+$") or p
  if stripped == "" then
    return "/"
  end
  return stripped:match("([^/]+)$") or stripped
end

function M.expand(p, home)
  -- Expand ~ at start
  local result = p
  if result:sub(1, 1) == "~" then
    result = home .. result:sub(2)
  end

  -- Expand ${VAR} and $VAR
  local err_var = nil
  result = result:gsub("%$%{([%w_]+)%}", function(var)
    local val = os.getenv(var)
    if not val then
      err_var = var
    end
    return val or ""
  end)
  if err_var then
    return nil, "unresolvable environment variable: $" .. err_var
  end

  result = result:gsub("%$([%w_]+)", function(var)
    local val = os.getenv(var)
    if not val then
      err_var = var
    end
    return val or ""
  end)
  if err_var then
    return nil, "unresolvable environment variable: $" .. err_var
  end

  return result
end

function M.join(...)
  local segments = { ... }
  local result = segments[1] or ""
  for i = 2, #segments do
    -- Strip trailing slash from left, leading slash from right
    local left = result:gsub("/+$", "")
    local right = segments[i]:gsub("^/+", "")
    result = left .. "/" .. right
  end
  return result
end

return M
