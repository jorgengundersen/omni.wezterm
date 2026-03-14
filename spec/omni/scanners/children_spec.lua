describe("omni.scanners.children", function()
  local children_scanner

  before_each(function()
    package.loaded["omni.scanners.children"] = nil
    package.loaded["omni.scanners"] = nil
    wezterm._reset()
    children_scanner = require("omni.scanners.children")
  end)

  describe("scan", function()
    it("returns entries for each immediate subdirectory", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/app-a",
        "/home/user/projects/app-b",
      }
      wezterm._filesystem["/home/user/projects/app-a"] = {}
      wezterm._filesystem["/home/user/projects/app-b"] = {}

      local entries = children_scanner.scan({ path = "/home/user/projects", type = "children" })

      assert.are.equal(2, #entries)
      assert.are.equal("/home/user/projects/app-a", entries[1].id)
      assert.are.equal("projects/app-a", entries[1].label)
      assert.are.equal("projects/app-a", entries[1].workspace_name)
      assert.are.equal("/home/user/projects/app-b", entries[2].id)
      assert.are.equal("projects/app-b", entries[2].label)
      assert.are.equal("projects/app-b", entries[2].workspace_name)
    end)

    it("skips files (non-directory entries)", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/app-a",
        "/home/user/projects/README.md",
      }
      wezterm._filesystem["/home/user/projects/app-a"] = {}
      -- README.md is not in _filesystem, so read_dir returns nil (it's a file)

      local entries = children_scanner.scan({ path = "/home/user/projects", type = "children" })

      assert.are.equal(1, #entries)
      assert.are.equal("/home/user/projects/app-a", entries[1].id)
    end)

    it("labels follow format: source_basename/child_basename", function()
      wezterm._filesystem["/tmp/deeply/nested/repos"] = {
        "/tmp/deeply/nested/repos/my-project",
      }
      wezterm._filesystem["/tmp/deeply/nested/repos/my-project"] = {}

      local entries =
        children_scanner.scan({ path = "/tmp/deeply/nested/repos", type = "children" })

      assert.are.equal("repos/my-project", entries[1].label)
    end)

    it("workspace_name has dots replaced with underscores", function()
      wezterm._filesystem["/home/user/projects"] = {
        "/home/user/projects/my.dotted.project",
      }
      wezterm._filesystem["/home/user/projects/my.dotted.project"] = {}

      local entries = children_scanner.scan({ path = "/home/user/projects", type = "children" })

      assert.are.equal("projects/my.dotted.project", entries[1].label)
      assert.are.equal("projects/my_dotted_project", entries[1].workspace_name)
    end)

    it("missing path logs warning and returns {}", function()
      local entries = children_scanner.scan({ path = "/nonexistent/path", type = "children" })

      assert.are.same({}, entries)
      assert.are.equal(1, #wezterm._logs)
      assert.are.equal("warn", wezterm._logs[1].level)
      assert.truthy(wezterm._logs[1].message:find("does not exist"))
    end)

    it("empty directory returns {}", function()
      wezterm._filesystem["/home/user/empty"] = {}

      local entries = children_scanner.scan({ path = "/home/user/empty", type = "children" })

      assert.are.same({}, entries)
    end)

    it("is registered in scanner registry as 'children'", function()
      local scanners = require("omni.scanners")
      wezterm._filesystem["/tmp/test"] = { "/tmp/test/child" }
      wezterm._filesystem["/tmp/test/child"] = {}

      local entries = scanners.dispatch({ path = "/tmp/test", type = "children" })

      assert.are.equal(1, #entries)
      assert.are.equal("/tmp/test/child", entries[1].id)
    end)
  end)
end)
