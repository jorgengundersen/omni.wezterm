describe("workspace", function()
  local workspace

  before_each(function()
    package.loaded["omni.workspace"] = nil
    wezterm._reset()
    workspace = require("omni.workspace")
  end)

  describe("derive_name", function()
    it("replaces dots with underscores", function()
      assert.are.equal("my_project_lua", workspace.derive_name("my.project.lua"))
    end)

    it("preserves slashes and other characters", function()
      assert.are.equal("github/my_project", workspace.derive_name("github/my.project"))
    end)

    it("returns string unchanged when no dots", function()
      assert.are.equal("myproject", workspace.derive_name("myproject"))
    end)
  end)

  describe("switch_or_create", function()
    it("calls perform_action with SwitchToWorkspace and spawn cwd", function()
      local actions = {}
      local window = {
        perform_action = function(_self, action, pane)
          actions[#actions + 1] = { action = action, pane = pane }
        end,
      }
      local pane = { id = "test-pane" }

      workspace.switch_or_create(window, pane, "/home/user/project", "my_project")

      assert.are.equal(1, #actions)
      assert.are.equal("SwitchToWorkspace", actions[1].action.type)
      assert.are.equal("my_project", actions[1].action.args.name)
      assert.are.equal("/home/user/project", actions[1].action.args.spawn.cwd)
      assert.are.equal(pane, actions[1].pane)
    end)
  end)

  describe("switch_to", function()
    it("calls perform_action with SwitchToWorkspace without spawn", function()
      local actions = {}
      local window = {
        perform_action = function(_self, action, pane)
          actions[#actions + 1] = { action = action, pane = pane }
        end,
      }
      local pane = { id = "test-pane" }

      workspace.switch_to(window, pane, "my_project")

      assert.are.equal(1, #actions)
      assert.are.equal("SwitchToWorkspace", actions[1].action.type)
      assert.are.equal("my_project", actions[1].action.args.name)
      assert.is_nil(actions[1].action.args.spawn)
      assert.are.equal(pane, actions[1].pane)
    end)
  end)

  describe("list_active", function()
    it("returns sorted workspace names", function()
      wezterm.mux = {
        get_workspace_names = function()
          return { "zeta", "alpha", "beta" }
        end,
      }
      assert.are.same({ "alpha", "beta", "zeta" }, workspace.list_active())
    end)

    it("returns empty table when no workspaces", function()
      wezterm.mux = {
        get_workspace_names = function()
          return {}
        end,
      }
      assert.are.same({}, workspace.list_active())
    end)
  end)
end)
