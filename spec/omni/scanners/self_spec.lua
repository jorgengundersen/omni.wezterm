describe("plugin.scanners.self", function()
  local self_scanner

  before_each(function()
    package.loaded["plugin.scanners.self"] = nil
    package.loaded["plugin.scanners"] = nil
    wezterm._reset()
    self_scanner = require("plugin.scanners.self")
  end)

  describe("scan", function()
    it("returns single entry with correct id, label, workspace_name", function()
      wezterm._filesystem["/home/user/projects/my-app"] = {}

      local entries = self_scanner.scan({ path = "/home/user/projects/my-app", type = "self" })

      assert.are.equal(1, #entries)
      assert.are.equal("/home/user/projects/my-app", entries[1].id)
      assert.are.equal("my-app", entries[1].label)
      assert.are.equal("my-app", entries[1].workspace_name)
    end)

    it("label is basename of path", function()
      wezterm._filesystem["/tmp/deeply/nested/cool-project"] = {}

      local entries = self_scanner.scan({ path = "/tmp/deeply/nested/cool-project", type = "self" })

      assert.are.equal("cool-project", entries[1].label)
    end)

    it("workspace_name has dots replaced with underscores", function()
      wezterm._filesystem["/home/user/my.dotted.project"] = {}

      local entries = self_scanner.scan({ path = "/home/user/my.dotted.project", type = "self" })

      assert.are.equal("my.dotted.project", entries[1].label)
      assert.are.equal("my_dotted_project", entries[1].workspace_name)
    end)

    it("missing path logs wezterm.log_warn and returns {}", function()
      local entries = self_scanner.scan({ path = "/nonexistent/path", type = "self" })

      assert.are.same({}, entries)
      assert.are.equal(1, #wezterm._logs)
      assert.are.equal("warn", wezterm._logs[1].level)
      assert.truthy(wezterm._logs[1].message:find("does not exist"))
    end)

    it("is registered in scanner registry as 'self'", function()
      local scanners = require("plugin.scanners")
      wezterm._filesystem["/tmp/test"] = {}

      local entries = scanners.dispatch({ path = "/tmp/test", type = "self" })

      assert.are.equal(1, #entries)
      assert.are.equal("/tmp/test", entries[1].id)
    end)
  end)
end)
