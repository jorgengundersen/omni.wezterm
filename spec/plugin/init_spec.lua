describe("plugin entry point", function()
  before_each(function()
    -- Clear all modules that live under plugin/
    local plugin_modules = {
      "plugin",
      "config",
      "discovery",
      "ui",
      "workspace",
      "path",
      "scanners",
      "scanners.self",
      "scanners.children",
      "scanners.grandchildren",
      "scanners.git_repos",
    }
    for _, mod in ipairs(plugin_modules) do
      package.loaded[mod] = nil
    end
    wezterm._reset()
  end)

  it("returns the omni module with apply_to_config", function()
    local plugin = require("plugin")
    assert.is_table(plugin)
    assert.is_function(plugin.apply_to_config)
  end)
end)
