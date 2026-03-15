-- WezTerm adds {plugin_dir}/plugin/ to package.path before loading this file.
-- Derive the lua/ directory by finding our plugin/ entry and swapping the suffix.
local lua_path_added = false
for pattern in package.path:gmatch("[^;]+") do
  local base = pattern:match("^(.*[/\\])plugin[/\\]")
  if base then
    package.path = base .. "lua/?.lua;" .. base .. "lua/?/init.lua;" .. package.path
    lua_path_added = true
    break
  end
end

if not lua_path_added then
  -- Last resort: relative path (works if cwd is the plugin root)
  package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
end

return require("omni")
