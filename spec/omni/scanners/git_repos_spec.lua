describe("plugin.scanners.git_repos", function()
  local git_repos_scanner
  local orig_run_child_process

  before_each(function()
    package.loaded["plugin.scanners.git_repos"] = nil
    package.loaded["plugin.scanners"] = nil
    wezterm._reset()
    orig_run_child_process = wezterm.run_child_process
    git_repos_scanner = require("plugin.scanners.git_repos")
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

    describe("windows fallback", function()
      before_each(function()
        wezterm.target_triple = "x86_64-pc-windows-msvc"
        package.loaded["plugin.scanners.git_repos"] = nil
        git_repos_scanner = require("plugin.scanners.git_repos")
      end)

      it("uses read_dir walk instead of find on Windows", function()
        wezterm._filesystem = {
          ["C:/Users/dev/projects"] = {
            "C:/Users/dev/projects/app-a",
            "C:/Users/dev/projects/app-b",
          },
          ["C:/Users/dev/projects/app-a"] = {
            "C:/Users/dev/projects/app-a/.git",
            "C:/Users/dev/projects/app-a/src",
          },
          ["C:/Users/dev/projects/app-a/.git"] = {},
          ["C:/Users/dev/projects/app-a/src"] = {},
          ["C:/Users/dev/projects/app-b"] = {
            "C:/Users/dev/projects/app-b/.git",
          },
          ["C:/Users/dev/projects/app-b/.git"] = {},
        }

        local entries = git_repos_scanner.scan({
          path = "C:/Users/dev/projects",
          type = "git_repos",
          max_depth = 3,
        })

        assert.are.equal(2, #entries)
        assert.are.equal("C:/Users/dev/projects/app-a", entries[1].id)
        assert.are.equal("projects/app-a", entries[1].label)
        assert.are.equal("projects/app-a", entries[1].workspace_name)
        assert.are.equal("C:/Users/dev/projects/app-b", entries[2].id)
        assert.are.equal("projects/app-b", entries[2].label)
        assert.are.equal("projects/app-b", entries[2].workspace_name)
      end)
      it("respects max_depth and does not descend beyond it", function()
        -- .git at depth 2 (projects/shallow/.git) → found with max_depth 2
        -- .git at depth 3 (projects/org/deep/.git) → NOT found with max_depth 2
        wezterm._filesystem = {
          ["C:/projects"] = { "C:/projects/shallow", "C:/projects/org" },
          ["C:/projects/shallow"] = { "C:/projects/shallow/.git" },
          ["C:/projects/shallow/.git"] = {},
          ["C:/projects/org"] = { "C:/projects/org/deep" },
          ["C:/projects/org/deep"] = { "C:/projects/org/deep/.git" },
          ["C:/projects/org/deep/.git"] = {},
        }

        local entries = git_repos_scanner.scan({
          path = "C:/projects",
          type = "git_repos",
          max_depth = 2,
        })

        assert.are.equal(1, #entries)
        assert.are.equal("C:/projects/shallow", entries[1].id)
      end)

      it("workspace_name has dots replaced with underscores", function()
        wezterm._filesystem = {
          ["C:/projects"] = { "C:/projects/my.dotted.project" },
          ["C:/projects/my.dotted.project"] = { "C:/projects/my.dotted.project/.git" },
          ["C:/projects/my.dotted.project/.git"] = {},
        }

        local entries = git_repos_scanner.scan({
          path = "C:/projects",
          type = "git_repos",
        })

        assert.are.equal("projects/my.dotted.project", entries[1].label)
        assert.are.equal("projects/my_dotted_project", entries[1].workspace_name)
      end)

      it("returns empty table when read_dir returns nil", function()
        -- No filesystem entries stubbed → read_dir returns nil
        local entries = git_repos_scanner.scan({
          path = "C:/nonexistent",
          type = "git_repos",
        })

        assert.are.same({}, entries)
      end)
    end)

    it("is registered in scanner registry as 'git_repos'", function()
      local scanners = require("plugin.scanners")
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
