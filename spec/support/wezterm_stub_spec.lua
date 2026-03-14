describe("wezterm_stub", function()
  local wez

  before_each(function()
    -- spec_helper is loaded by busted automatically; it should set _G.wezterm
    wez = _G.wezterm
    wez._reset()
  end)

  describe("home_dir", function()
    it("returns a test home directory", function()
      assert.equal("/home/testuser", wez.home_dir())
    end)
  end)

  describe("logging", function()
    it("captures log_info messages", function()
      wez.log_info("hello")
      assert.equal(1, #wez._logs)
      assert.equal("info", wez._logs[1].level)
      assert.equal("hello", wez._logs[1].message)
    end)

    it("captures log_warn messages", function()
      wez.log_warn("careful")
      assert.equal(1, #wez._logs)
      assert.equal("warn", wez._logs[1].level)
      assert.equal("careful", wez._logs[1].message)
    end)

    it("captures log_error messages", function()
      wez.log_error("boom")
      assert.equal(1, #wez._logs)
      assert.equal("error", wez._logs[1].level)
      assert.equal("boom", wez._logs[1].message)
    end)
  end)

  describe("read_dir", function()
    it("returns entries from _filesystem table", function()
      wez._filesystem["/projects"] = { "alpha", "beta" }
      local entries = wez.read_dir("/projects")
      assert.same({ "alpha", "beta" }, entries)
    end)

    it("returns nil for unregistered paths", function()
      local entries = wez.read_dir("/nonexistent")
      assert.is_nil(entries)
    end)

    it("returns empty table for registered-but-empty paths", function()
      wez._filesystem["/empty"] = {}
      local entries = wez.read_dir("/empty")
      assert.same({}, entries)
    end)
  end)

  describe("action", function()
    it("InputSelector returns a descriptor table", function()
      local result = wez.action.InputSelector({ title = "Pick" })
      assert.equal("InputSelector", result.type)
      assert.equal("Pick", result.args.title)
    end)

    it("SwitchToWorkspace returns a descriptor table", function()
      local result = wez.action.SwitchToWorkspace({ name = "dev", spawn = { cwd = "/tmp" } })
      assert.equal("SwitchToWorkspace", result.type)
      assert.equal("dev", result.args.name)
    end)
  end)

  describe("action_callback", function()
    it("wraps function in a table", function()
      local fn = function() end
      local result = wez.action_callback(fn)
      assert.equal("action_callback", result.type)
      assert.equal(fn, result.fn)
    end)
  end)

  describe("target_triple", function()
    it("defaults to linux triple", function()
      assert.equal("x86_64-unknown-linux-gnu", wez.target_triple)
    end)

    it("is configurable per test", function()
      wez.target_triple = "x86_64-pc-windows-msvc"
      assert.equal("x86_64-pc-windows-msvc", wez.target_triple)
    end)

    it("resets to default after _reset", function()
      wez.target_triple = "aarch64-apple-darwin"
      wez._reset()
      assert.equal("x86_64-unknown-linux-gnu", wez.target_triple)
    end)
  end)

  describe("run_child_process", function()
    it("returns default response when no responses configured", function()
      local success, stdout, stderr = wez.run_child_process({ "find", "/tmp" })
      assert.is_false(success)
      assert.equal("", stdout)
      assert.equal("", stderr)
    end)

    it("returns configured response keyed by first arg", function()
      wez._child_process_responses["find"] = { true, "/tmp/project\n", "" }
      local success, stdout, stderr = wez.run_child_process({ "find", "/tmp" })
      assert.is_true(success)
      assert.equal("/tmp/project\n", stdout)
      assert.equal("", stderr)
    end)

    it("returns default response for unconfigured commands", function()
      wez._child_process_responses["git"] = { true, "output", "" }
      local success, stdout, stderr = wez.run_child_process({ "find", "/tmp" })
      assert.is_false(success)
      assert.equal("", stdout)
      assert.equal("", stderr)
    end)
  end)

  describe("_reset", function()
    it("clears _filesystem and _logs", function()
      wez._filesystem["/foo"] = { "bar" }
      wez.log_info("something")
      wez._reset()
      assert.same({}, wez._filesystem)
      assert.same({}, wez._logs)
    end)

    it("clears child process responses", function()
      wez._child_process_responses["find"] = { true, "output", "" }
      wez._reset()
      assert.same({}, wez._child_process_responses)
    end)
  end)
end)
