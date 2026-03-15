describe("plugin entry point", function()
  before_each(function()
    -- Clear all plugin modules for a fresh require
    for key, _ in pairs(package.loaded) do
      if key:match("^plugin") then
        package.loaded[key] = nil
      end
    end
    wezterm._reset()
  end)

  it("returns the omni module with apply_to_config", function()
    local plugin = require("plugin")
    assert.is_table(plugin)
    assert.is_function(plugin.apply_to_config)
  end)
end)
