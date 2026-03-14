local plugin_dir = debug.getinfo(1, "S").source:match("@(.*/)") or "./"
package.path = plugin_dir .. "../lua/?.lua;" .. plugin_dir .. "../lua/?/init.lua;" .. package.path

return require("omni")
