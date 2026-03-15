describe("plugin.scanners.grandchildren", function()
  local grandchildren_scanner

  before_each(function()
    package.loaded["plugin.scanners.grandchildren"] = nil
    package.loaded["plugin.scanners"] = nil
    wezterm._reset()
    grandchildren_scanner = require("plugin.scanners.grandchildren")
  end)

  describe("scan", function()
    it("returns entries for second-level subdirectories", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/group-a",
        "/home/user/projects/group-b",
      }
      wezterm._filesystem["/home/user/projects/group-a"] = {
        "/home/user/projects/group-a/app-1",
        "/home/user/projects/group-a/app-2",
      }
      wezterm._filesystem["/home/user/projects/group-a/app-1"] = {}
      wezterm._filesystem["/home/user/projects/group-a/app-2"] = {}
      wezterm._filesystem["/home/user/projects/group-b"] = {
        "/home/user/projects/group-b/app-3",
      }
      wezterm._filesystem["/home/user/projects/group-b/app-3"] = {}

      local entries =
        grandchildren_scanner.scan({ path = "/home/user/projects", type = "grandchildren" })

      assert.are.equal(3, #entries)
      assert.are.equal("/home/user/projects/group-a/app-1", entries[1].id)
      assert.are.equal("projects/group-a/app-1", entries[1].label)
      assert.are.equal("projects/group-a/app-1", entries[1].workspace_name)
      assert.are.equal("/home/user/projects/group-a/app-2", entries[2].id)
      assert.are.equal("projects/group-a/app-2", entries[2].label)
      assert.are.equal("/home/user/projects/group-b/app-3", entries[3].id)
      assert.are.equal("projects/group-b/app-3", entries[3].label)
    end)

    it("labels follow format: source_basename/group_basename/name_basename", function()
      wezterm._filesystem["/tmp/deeply/nested/repos"] = {
        "/tmp/deeply/nested/repos/group",
      }
      wezterm._filesystem["/tmp/deeply/nested/repos/group"] = {
        "/tmp/deeply/nested/repos/group/my-project",
      }
      wezterm._filesystem["/tmp/deeply/nested/repos/group/my-project"] = {}

      local entries =
        grandchildren_scanner.scan({ path = "/tmp/deeply/nested/repos", type = "grandchildren" })

      assert.are.equal("repos/group/my-project", entries[1].label)
    end)

    it("skips intermediate grouping level in output (groups are not entries)", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/group-a",
      }
      wezterm._filesystem["/home/user/projects/group-a"] = {
        "/home/user/projects/group-a/app-1",
      }
      wezterm._filesystem["/home/user/projects/group-a/app-1"] = {}

      local entries =
        grandchildren_scanner.scan({ path = "/home/user/projects", type = "grandchildren" })

      -- Only the grandchild should appear, not group-a itself
      assert.are.equal(1, #entries)
      assert.are.equal("/home/user/projects/group-a/app-1", entries[1].id)
    end)

    it("workspace_name has dots replaced with underscores", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/org.name",
      }
      wezterm._filesystem["/home/user/projects/org.name"] = {
        "/home/user/projects/org.name/my.dotted.project",
      }
      wezterm._filesystem["/home/user/projects/org.name/my.dotted.project"] = {}

      local entries =
        grandchildren_scanner.scan({ path = "/home/user/projects", type = "grandchildren" })

      assert.are.equal("projects/org.name/my.dotted.project", entries[1].label)
      assert.are.equal("projects/org_name/my_dotted_project", entries[1].workspace_name)
    end)

    it("missing source path logs warning and returns {}", function()
      local entries =
        grandchildren_scanner.scan({ path = "/nonexistent/path", type = "grandchildren" })

      assert.are.same({}, entries)
      assert.are.equal(1, #wezterm._logs)
      assert.are.equal("warn", wezterm._logs[1].level)
      assert.truthy(wezterm._logs[1].message:find("does not exist"))
    end)

    it("missing/empty group directories handled gracefully", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/group-a",
        "/home/user/projects/README.md",
      }
      wezterm._filesystem["/home/user/projects/group-a"] = {}
      -- README.md is not in _filesystem (it's a file)

      local entries =
        grandchildren_scanner.scan({ path = "/home/user/projects", type = "grandchildren" })

      assert.are.same({}, entries)
    end)

    it("skips non-directory entries at second level", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/group-a",
      }
      wezterm._filesystem["/home/user/projects/group-a"] = {
        "/home/user/projects/group-a/app-1",
        "/home/user/projects/group-a/.gitignore",
      }
      wezterm._filesystem["/home/user/projects/group-a/app-1"] = {}
      -- .gitignore is not in _filesystem (it's a file)

      local entries =
        grandchildren_scanner.scan({ path = "/home/user/projects", type = "grandchildren" })

      assert.are.equal(1, #entries)
      assert.are.equal("/home/user/projects/group-a/app-1", entries[1].id)
    end)

    it("is registered in scanner registry as 'grandchildren'", function()
      local scanners = require("plugin.scanners")
      wezterm._filesystem["/tmp/test"] = { "/tmp/test/group" }
      wezterm._filesystem["/tmp/test/group"] = { "/tmp/test/group/child" }
      wezterm._filesystem["/tmp/test/group/child"] = {}

      local entries = scanners.dispatch({ path = "/tmp/test", type = "grandchildren" })

      assert.are.equal(1, #entries)
      assert.are.equal("/tmp/test/group/child", entries[1].id)
    end)
  end)
end)
