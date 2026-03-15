local wezterm = require("wezterm")

-- '...' gives us the plugin's module name (URL-encoded repo path).
-- Use it with wezterm.plugin.list() to find our plugin's directory on disk.
local plugin_name = ...
local plugin_dir

for _, plugin in ipairs(wezterm.plugin.list()) do
  if plugin.component == plugin_name or plugin.url:find("omni%.wezterm") then
    plugin_dir = plugin.plugin_dir
    break
  end
end

if plugin_dir then
  local sep = package.config:sub(1, 1)
  package.path = plugin_dir .. sep .. "lua" .. sep .. "?.lua;"
    .. plugin_dir .. sep .. "lua" .. sep .. "?" .. sep .. "init.lua;"
    .. package.path
end

return require("omni")
