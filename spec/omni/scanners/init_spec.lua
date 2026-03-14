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

      assert.has_error(function()
        scanners.dispatch({ type = "bad_missing", path = "/tmp" })
      end, "omni.wezterm: scanner 'bad_missing' returned invalid entry #1: missing field 'workspace_name'")
    end)

    it("raises error when field has wrong type", function()
      scanners.register("bad_type", {
        scan = function()
          return {
            { id = 42, label = "project", workspace_name = "project" },
          }
        end,
      })

      assert.has_error(function()
        scanners.dispatch({ type = "bad_type", path = "/tmp" })
      end, "omni.wezterm: scanner 'bad_type' returned invalid entry #1: field 'id' must be a string, got number")
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

      assert.has_error(function()
        scanners.dispatch({ type = "bad_second", path = "/tmp" })
      end, "omni.wezterm: scanner 'bad_second' returned invalid entry #2: missing field 'workspace_name'")
    end)
  end)
end)
