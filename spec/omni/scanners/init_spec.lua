describe("omni.scanners", function()
  local scanners

  before_each(function()
    package.loaded["omni.scanners"] = nil
    scanners = require("omni.scanners")
  end)

  describe("dispatch", function()
    it("returns valid entries unchanged", function()
      local valid_entries = {
        { id = "/home/user/project-a", label = "project-a", workspace_name = "project-a" },
        { id = "/home/user/project-b", label = "project-b", workspace_name = "project-b" },
      }

      -- Register a fake scanner that returns valid entries
      scanners.register("fake", {
        scan = function()
          return valid_entries
        end,
      })

      local results = scanners.dispatch({ type = "fake", path = "/home/user" })
      assert.equal(2, #results)
      assert.equal("/home/user/project-a", results[1].id)
      assert.equal("project-a", results[1].label)
      assert.equal("project-a", results[1].workspace_name)
    end)

    it("raises error for unknown scanner type", function()
      assert.has_error(function()
        scanners.dispatch({ type = "nonexistent", path = "/tmp" })
      end, "omni.wezterm: unknown scanner type 'nonexistent'")
    end)

    it("raises error when entry is missing a field", function()
      scanners.register("bad_missing", {
        scan = function()
          return {
            { id = "/home/user/project", label = "project" },
          }
        end,
      })

      assert.has_error(
        function()
          scanners.dispatch({ type = "bad_missing", path = "/tmp" })
        end,
        "omni.wezterm: scanner 'bad_missing' returned invalid entry #1: missing field 'workspace_name'"
      )
    end)

    it("raises error when field has wrong type", function()
      scanners.register("bad_type", {
        scan = function()
          return {
            { id = 42, label = "project", workspace_name = "project" },
          }
        end,
      })

      assert.has_error(
        function()
          scanners.dispatch({ type = "bad_type", path = "/tmp" })
        end,
        "omni.wezterm: scanner 'bad_type' returned invalid entry #1: field 'id' must be a string, got number"
      )
    end)

    it("validates all entries, not just the first", function()
      scanners.register("bad_second", {
        scan = function()
          return {
            { id = "/ok", label = "ok", workspace_name = "ok" },
            { id = "/bad", label = "bad", workspace_name = nil },
          }
        end,
      })

      assert.has_error(
        function()
          scanners.dispatch({ type = "bad_second", path = "/tmp" })
        end,
        "omni.wezterm: scanner 'bad_second' returned invalid entry #2: missing field 'workspace_name'"
      )
    end)
  end)

  describe("auto-registration", function()
    before_each(function()
      -- Clear all scanner modules so they re-register on require
      package.loaded["omni.scanners"] = nil
      package.loaded["omni.scanners.self"] = nil
      package.loaded["omni.scanners.children"] = nil
      package.loaded["omni.scanners.grandchildren"] = nil
      package.loaded["omni.scanners.git_repos"] = nil
      wezterm._reset()
      scanners = require("omni.scanners")
    end)

    it("registers self, children, grandchildren, and git_repos on load", function()
      -- self scanner: just needs read_dir to return non-nil
      wezterm._filesystem["/tmp/project"] = {}
      local self_result = scanners.dispatch({ type = "self", path = "/tmp/project" })
      assert.are.equal(1, #self_result)
      assert.are.equal("/tmp/project", self_result[1].id)

      -- children scanner: needs read_dir to return child paths, each also readable
      wezterm._filesystem["/tmp/parent"] = { "/tmp/parent/child-a" }
      wezterm._filesystem["/tmp/parent/child-a"] = {}
      local children_result = scanners.dispatch({ type = "children", path = "/tmp/parent" })
      assert.are.equal(1, #children_result)
      assert.are.equal("/tmp/parent/child-a", children_result[1].id)

      -- grandchildren scanner
      wezterm._filesystem["/tmp/root"] = { "/tmp/root/group" }
      wezterm._filesystem["/tmp/root/group"] = { "/tmp/root/group/proj" }
      wezterm._filesystem["/tmp/root/group/proj"] = {}
      local gc_result = scanners.dispatch({ type = "grandchildren", path = "/tmp/root" })
      assert.are.equal(1, #gc_result)
      assert.are.equal("/tmp/root/group/proj", gc_result[1].id)

      -- git_repos scanner: needs run_child_process
      wezterm._child_process_responses["find"] = { true, "/tmp/repos/myproject/.git\n", "" }
      local git_result = scanners.dispatch({ type = "git_repos", path = "/tmp/repos" })
      assert.are.equal(1, #git_result)
      assert.are.equal("/tmp/repos/myproject", git_result[1].id)
    end)
  end)
end)
