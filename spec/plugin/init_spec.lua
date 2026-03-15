describe("plugin entry point", function()
  it("returns the omni module with apply_to_config", function()
    local stub = require("spec.support.wezterm_stub")
    package.preload["wezterm"] = function()
      return stub
    end

    -- Simulate WezTerm's plugin.list() returning our plugin directory
    local cwd = io.popen("pwd"):read("*l")
    stub._plugin_list = {
      {
        url = "https://github.com/jorgengundersen/omni.wezterm",
        plugin_dir = cwd,
        component = "plugin",
      },
    }
    local plugin = dofile("plugin/init.lua")
    assert.is_table(plugin)
    assert.is_function(plugin.apply_to_config)
  end)
end)
