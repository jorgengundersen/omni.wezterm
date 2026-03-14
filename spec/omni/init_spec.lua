local omni = require("omni")

describe("omni", function()
  before_each(function()
    wezterm._reset()
  end)

  describe("apply_to_config", function()
    it("returns a table with apply_to_config function", function()
      assert.is_function(omni.apply_to_config)
    end)

    it("creates config.keys if missing and appends keybinding", function()
      local config = {}
      omni.apply_to_config(config)

      assert.is_table(config.keys)
      assert.equals(1, #config.keys)
      assert.equals("p", config.keys[1].key)
      assert.equals("CTRL|SHIFT", config.keys[1].mods)
    end)

    it("appends to existing config.keys without overwriting", function()
      local config = {
        keys = {
          { key = "x", mods = "CTRL", action = "noop" },
        },
      }
      omni.apply_to_config(config)

      assert.equals(2, #config.keys)
      assert.equals("x", config.keys[1].key)
      assert.equals("p", config.keys[2].key)
    end)

    it("uses custom key and mods from opts", function()
      local config = {}
      omni.apply_to_config(config, { key = "o", mods = "SUPER" })

      assert.equals("o", config.keys[1].key)
      assert.equals("SUPER", config.keys[1].mods)
    end)

    it("is idempotent — does not double-apply", function()
      local config = {}
      omni.apply_to_config(config)
      omni.apply_to_config(config)

      assert.equals(1, #config.keys)
    end)

    it("binds an InputSelector action with Hello World choice", function()
      local config = {}
      omni.apply_to_config(config)

      local action = config.keys[1].action
      assert.equals("InputSelector", action.type)
      assert.equals("Omni", action.args.title)

      local choices = action.args.choices
      assert.equals(1, #choices)
      assert.equals("hello", choices[1].id)
      assert.equals("Hello, World!", choices[1].label)
    end)

    it("callback logs the selected id", function()
      local config = {}
      omni.apply_to_config(config)

      local action = config.keys[1].action
      local callback = action.args.action
      assert.equals("action_callback", callback.type)

      -- Simulate WezTerm calling the callback with a selection
      callback.fn({}, { id = "hello", label = "Hello, World!" })

      assert.equals(1, #wezterm._logs)
      assert.equals("info", wezterm._logs[1].level)
      assert.truthy(wezterm._logs[1].message:find("hello"))
    end)
  end)
end)
