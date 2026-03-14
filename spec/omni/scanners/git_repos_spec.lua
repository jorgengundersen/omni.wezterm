describe("omni.scanners.git_repos", function()
  local git_repos_scanner
  local orig_run_child_process

  before_each(function()
    package.loaded["omni.scanners.git_repos"] = nil
    package.loaded["omni.scanners"] = nil
    wezterm._reset()
    orig_run_child_process = wezterm.run_child_process
    git_repos_scanner = require("omni.scanners.git_repos")
  end)

  after_each(function()
    wezterm.run_child_process = orig_run_child_process
  end)

  describe("scan", function()
    it("constructs correct find command with max_depth and parses results", function()
      local captured_args
      wezterm.run_child_process = function(args)
        captured_args = args
        return true, "/home/user/projects/app-a/.git\n/home/user/projects/app-b/.git\n", ""
      end

      local entries = git_repos_scanner.scan({
        path = "/home/user/projects",
        type = "git_repos",
        max_depth = 3,
      })

      assert.are.same(
        { "find", "/home/user/projects", "-maxdepth", "3", "-type", "d", "-name", ".git" },
        captured_args
      )
      assert.are.equal(2, #entries)
      assert.are.equal("/home/user/projects/app-a", entries[1].id)
      assert.are.equal("projects/app-a", entries[1].label)
      assert.are.equal("projects/app-a", entries[1].workspace_name)
      assert.are.equal("/home/user/projects/app-b", entries[2].id)
      assert.are.equal("projects/app-b", entries[2].label)
      assert.are.equal("projects/app-b", entries[2].workspace_name)
    end)

    it("max_depth defaults to 5 when not specified", function()
      local captured_args
      wezterm.run_child_process = function(args)
        captured_args = args
        return true, "/home/user/projects/deep/nested/repo/.git\n", ""
      end

      local entries = git_repos_scanner.scan({
        path = "/home/user/projects",
        type = "git_repos",
      })

      assert.are.equal("5", captured_args[4])
      assert.are.equal(1, #entries)
      assert.are.equal("/home/user/projects/deep/nested/repo", entries[1].id)
    end)

    it("labels are relative to source base path", function()
      wezterm._child_process_responses["find"] = {
        true,
        "/tmp/deeply/nested/repos/my-project/.git\n",
        "",
      }

      local entries = git_repos_scanner.scan({
        path = "/tmp/deeply/nested/repos",
        type = "git_repos",
      })

      assert.are.equal("repos/my-project", entries[1].label)
    end)

    it("workspace_name has dots replaced with underscores", function()
      wezterm._child_process_responses["find"] = {
        true,
        "/home/user/projects/my.dotted.project/.git\n",
        "",
      }

      local entries = git_repos_scanner.scan({
        path = "/home/user/projects",
        type = "git_repos",
      })

      assert.are.equal("projects/my.dotted.project", entries[1].label)
      assert.are.equal("projects/my_dotted_project", entries[1].workspace_name)
    end)

    it("failed child process returns {} with warning", function()
      wezterm._child_process_responses["find"] = { false, "", "error occurred" }

      local entries = git_repos_scanner.scan({
        path = "/home/user/projects",
        type = "git_repos",
      })

      assert.are.same({}, entries)
      assert.are.equal(1, #wezterm._logs)
      assert.are.equal("warn", wezterm._logs[1].level)
    end)

    it("empty find output returns {}", function()
      wezterm._child_process_responses["find"] = { true, "", "" }

      local entries = git_repos_scanner.scan({
        path = "/home/user/projects",
        type = "git_repos",
      })

      assert.are.same({}, entries)
    end)

    it("handles trailing newline without creating empty entry", function()
      wezterm._child_process_responses["find"] = {
        true,
        "/home/user/projects/app/.git\n",
        "",
      }

      local entries = git_repos_scanner.scan({
        path = "/home/user/projects",
        type = "git_repos",
      })

      assert.are.equal(1, #entries)
    end)

    it("is registered in scanner registry as 'git_repos'", function()
      local scanners = require("omni.scanners")
      wezterm._child_process_responses["find"] = {
        true,
        "/tmp/test/repo/.git\n",
        "",
      }

      local entries = scanners.dispatch({ path = "/tmp/test", type = "git_repos" })

      assert.are.equal(1, #entries)
      assert.are.equal("/tmp/test/repo", entries[1].id)
    end)
  end)
end)
