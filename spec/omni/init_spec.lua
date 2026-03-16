local omni = require("plugin")

describe("omni", function()
  before_each(function()
    wezterm._reset()
    omni._reset_for_tests()
  end)

  describe("apply_to_config", function()
    it("registers two keybindings (project selector and active workspace selector)", function()
      local config = {}
      omni.apply_to_config(config)

      assert.is_table(config.keys)
      assert.equals(2, #config.keys)
      assert.equals("p", config.keys[1].key)
      assert.equals("CTRL|SHIFT", config.keys[1].mods)
      assert.equals("s", config.keys[2].key)
      assert.equals("CTRL|SHIFT", config.keys[2].mods)
    end)

    it("is idempotent — does not double-apply", function()
      local config = {}
      omni.apply_to_config(config)
      omni.apply_to_config(config)

      assert.equals(2, #config.keys)
    end)

    it("creates config.keys table if missing", function()
      local config = {}
      assert.is_nil(config.keys)
      omni.apply_to_config(config)
      assert.is_table(config.keys)
      assert.equals(2, #config.keys)
    end)

    it("appends to existing config.keys without overwriting", function()
      local config = {
        keys = {
          { key = "x", mods = "CTRL", action = "noop" },
        },
      }
      omni.apply_to_config(config)

      assert.equals(3, #config.keys)
      assert.equals("x", config.keys[1].key)
      assert.equals("p", config.keys[2].key)
      assert.equals("s", config.keys[3].key)
    end)

    it("uses custom key and mods from opts", function()
      local config = {}
      omni.apply_to_config(
        config,
        { key = "o", mods = "SUPER", active_key = "w", active_mods = "ALT" }
      )

      assert.equals("o", config.keys[1].key)
      assert.equals("SUPER", config.keys[1].mods)
      assert.equals("w", config.keys[2].key)
      assert.equals("ALT", config.keys[2].mods)
    end)
  end)

  describe("project selector", function()
    local function setup_project_selector()
      -- Stub filesystem with children scanner-compatible layout
      wezterm._filesystem["/home/testuser/projects"] = {
        "/home/testuser/projects/alpha",
        "/home/testuser/projects/beta",
      }
      -- Mark them as directories
      wezterm._filesystem["/home/testuser/projects/alpha"] = {}
      wezterm._filesystem["/home/testuser/projects/beta"] = {}

      -- Stub config file with children source
      wezterm._files["/home/testuser/.config/omni/config.toml"] = "content"
      wezterm.serde.toml_decode = function()
        return {
          sources = {
            { path = "/home/testuser/projects", type = "children" },
          },
        }
      end

      local config = {}
      omni.apply_to_config(config)
      return config
    end

    it("loads config, discovers projects, and shows InputSelector", function()
      local config = setup_project_selector()
      local window = wezterm._mock_window()
      local pane = {}

      -- Trigger the project selector callback
      local project_action = config.keys[1].action
      project_action.fn(window, pane)

      -- Should have performed an InputSelector action
      assert.equals(1, #wezterm._performed_actions)
      local performed = wezterm._performed_actions[1]
      assert.equals("InputSelector", performed.action.type)
      assert.equals("Switch Project", performed.action.args.title)
      assert.is_true(performed.action.args.fuzzy)

      -- Choices should match discovered projects
      local choices = performed.action.args.choices
      assert.equals(2, #choices)
      assert.equals("projects/alpha", choices[1].label)
      assert.equals("projects/beta", choices[2].label)
    end)

    it("switches workspace on selection", function()
      local config = setup_project_selector()
      local window = wezterm._mock_window()
      local pane = {}

      -- Trigger the project selector
      config.keys[1].action.fn(window, pane)

      -- Get the inner callback from the InputSelector
      local selector_action = wezterm._performed_actions[1].action
      local inner_callback = selector_action.args.action

      -- Simulate user selecting a project
      wezterm._performed_actions = {}
      inner_callback.fn(window, pane, "/home/testuser/projects/alpha", "projects/alpha")

      -- Should switch to workspace
      assert.equals(1, #wezterm._performed_actions)
      local switch_action = wezterm._performed_actions[1].action
      assert.equals("SwitchToWorkspace", switch_action.type)
      assert.equals("projects/alpha", switch_action.args.name)
      assert.equals("/home/testuser/projects/alpha", switch_action.args.spawn.cwd)
    end)

    it("does nothing on cancellation", function()
      local config = setup_project_selector()
      local window = wezterm._mock_window()
      local pane = {}

      -- Trigger the project selector
      config.keys[1].action.fn(window, pane)

      -- Get the inner callback
      local selector_action = wezterm._performed_actions[1].action
      local inner_callback = selector_action.args.action

      -- Simulate cancellation (nil id)
      wezterm._performed_actions = {}
      inner_callback.fn(window, pane, nil, nil)

      -- No action should be performed
      assert.equals(0, #wezterm._performed_actions)
    end)

    it("surfaces config errors via log_error and toast notification", function()
      -- Stub a config file that will cause a parse error
      wezterm._files["/home/testuser/.config/omni/config.toml"] = "bad content"
      wezterm.serde.toml_decode = function()
        error("invalid TOML")
      end

      local config = {}
      omni.apply_to_config(config)
      local window = wezterm._mock_window()
      local pane = {}

      -- Trigger the project selector — should not raise
      config.keys[1].action.fn(window, pane)

      -- Should log error
      local error_logs = {}
      for _, log in ipairs(wezterm._logs) do
        if log.level == "error" then
          error_logs[#error_logs + 1] = log
        end
      end
      assert.is_true(#error_logs > 0)

      -- Should show toast notification
      assert.equals(1, #wezterm._toasts)
      assert.equals("omni.wezterm", wezterm._toasts[1].title)
    end)
  end)

  describe("active workspace selector", function()
    it("lists active workspaces and shows InputSelector", function()
      wezterm._workspace_names = { "project-beta", "project-alpha" }

      local config = {}
      omni.apply_to_config(config)
      local window = wezterm._mock_window()
      local pane = {}

      -- Trigger the active workspace selector
      config.keys[2].action.fn(window, pane)

      assert.equals(1, #wezterm._performed_actions)
      local performed = wezterm._performed_actions[1]
      assert.equals("InputSelector", performed.action.type)
      assert.equals("Switch Workspace", performed.action.args.title)
      assert.is_true(performed.action.args.fuzzy)

      -- Choices should be sorted workspace names
      local choices = performed.action.args.choices
      assert.equals(2, #choices)
      assert.equals("project-alpha", choices[1].label)
      assert.equals("project-beta", choices[2].label)
    end)

    it("switches to selected workspace", function()
      wezterm._workspace_names = { "my-project" }

      local config = {}
      omni.apply_to_config(config)
      local window = wezterm._mock_window()
      local pane = {}

      -- Trigger selector
      config.keys[2].action.fn(window, pane)

      -- Get inner callback and simulate selection
      local inner_callback = wezterm._performed_actions[1].action.args.action
      wezterm._performed_actions = {}
      inner_callback.fn(window, pane, "my-project", "my-project")

      assert.equals(1, #wezterm._performed_actions)
      local switch_action = wezterm._performed_actions[1].action
      assert.equals("SwitchToWorkspace", switch_action.type)
      assert.equals("my-project", switch_action.args.name)
    end)

    it("does nothing on cancellation", function()
      wezterm._workspace_names = { "my-project" }

      local config = {}
      omni.apply_to_config(config)
      local window = wezterm._mock_window()
      local pane = {}

      config.keys[2].action.fn(window, pane)

      local inner_callback = wezterm._performed_actions[1].action.args.action
      wezterm._performed_actions = {}
      inner_callback.fn(window, pane, nil, nil)

      assert.equals(0, #wezterm._performed_actions)
    end)

    it("logs info and returns early when no active workspaces", function()
      wezterm._workspace_names = {}

      local config = {}
      omni.apply_to_config(config)
      local window = wezterm._mock_window()
      local pane = {}

      config.keys[2].action.fn(window, pane)

      -- No InputSelector should be shown
      assert.equals(0, #wezterm._performed_actions)

      -- Should log info
      local info_logs = {}
      for _, log in ipairs(wezterm._logs) do
        if log.level == "info" then
          info_logs[#info_logs + 1] = log
        end
      end
      assert.is_true(#info_logs > 0)
      assert.truthy(info_logs[1].message:find("no active workspaces"))
    end)
  end)

  describe("custom opts", function()
    it("passes custom title and fuzzy settings", function()
      wezterm._workspace_names = { "ws1" }

      local config = {}
      omni.apply_to_config(config, {
        title = "My Projects",
        fuzzy = false,
        active_title = "My Workspaces",
        active_fuzzy = false,
      })

      local window = wezterm._mock_window()
      local pane = {}

      -- Test project selector title/fuzzy
      config.keys[1].action.fn(window, pane)
      local project_selector = wezterm._performed_actions[1].action
      assert.equals("My Projects", project_selector.args.title)
      assert.is_false(project_selector.args.fuzzy)

      -- Test active workspace selector title/fuzzy
      wezterm._performed_actions = {}
      config.keys[2].action.fn(window, pane)
      local workspace_selector = wezterm._performed_actions[1].action
      assert.equals("My Workspaces", workspace_selector.args.title)
      assert.is_false(workspace_selector.args.fuzzy)
    end)
  end)
end)
