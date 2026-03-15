describe("config", function()
  local config

  before_each(function()
    package.loaded["config"] = nil
    wezterm._reset()
    config = require("config")
  end)

  describe("validate", function()
    it("errors when sources is not a table", function()
      assert.has_error(function()
        config.validate({ sources = "not a table" })
      end, 'omni.wezterm: config error: "sources" must be an array of tables')
    end)

    it("returns empty sources when sources is nil", function()
      local result = config.validate({})
      assert.are.same({}, result.sources)
    end)

    it("errors when source is missing path", function()
      assert.has_error(function()
        config.validate({ sources = { { type = "self" } } })
      end, "omni.wezterm: config error in source #1: missing required field 'path'")
    end)

    it("errors when path is not a string", function()
      assert.has_error(function()
        config.validate({ sources = { { path = 123, type = "self" } } })
      end, "omni.wezterm: config error in source #1: 'path' must be a string")
    end)

    it("errors when source is missing type", function()
      assert.has_error(function()
        config.validate({ sources = { { path = "/tmp" } } })
      end, "omni.wezterm: config error in source #1: missing required field 'type'")
    end)

    it("errors when type is unknown", function()
      assert.has_error(
        function()
          config.validate({ sources = { { path = "/tmp", type = "foobar" } } })
        end,
        "omni.wezterm: config error in source #1: unknown type 'foobar'"
          .. " (expected git_repos|children|grandchildren|self)"
      )
    end)

    it("defaults max_depth to 5", function()
      local result = config.validate({
        sources = { { path = "/tmp/repos", type = "git_repos" } },
      })
      assert.are.equal(5, result.sources[1].max_depth)
    end)

    it("preserves explicit max_depth", function()
      local result = config.validate({
        sources = { { path = "/tmp/repos", type = "git_repos", max_depth = 3 } },
      })
      assert.are.equal(3, result.sources[1].max_depth)
    end)

    it("expands ~ in paths", function()
      local result = config.validate({
        sources = { { path = "~/projects", type = "children" } },
      })
      assert.are.equal("/home/testuser/projects", result.sources[1].path)
    end)

    it("warns and skips sources with unresolvable env vars", function()
      local result = config.validate({
        sources = {
          { path = "$NONEXISTENT_VAR_12345/foo", type = "self" },
          { path = "/tmp/valid", type = "self" },
        },
      })
      assert.are.equal(1, #result.sources)
      assert.are.equal("/tmp/valid", result.sources[1].path)
      assert.are.equal(1, #wezterm._logs)
      assert.are.equal("warn", wezterm._logs[1].level)
    end)

    it("validates and returns a complete config", function()
      local result = config.validate({
        sources = {
          { path = "~/Repos", type = "git_repos", max_depth = 4 },
          { path = "/tmp/inbox", type = "self" },
          { path = "~/projects", type = "children" },
          { path = "~/resources", type = "grandchildren" },
        },
      })
      assert.are.equal(4, #result.sources)
      assert.are.same({
        path = "/home/testuser/Repos",
        type = "git_repos",
        max_depth = 4,
      }, result.sources[1])
      assert.are.same({
        path = "/tmp/inbox",
        type = "self",
        max_depth = 5,
      }, result.sources[2])
    end)

    it("includes source index in error messages", function()
      assert.has_error(function()
        config.validate({
          sources = {
            { path = "/valid", type = "self" },
            { path = "/also-valid", type = "children" },
            { type = "self" },
          },
        })
      end, "omni.wezterm: config error in source #3: missing required field 'path'")
    end)
  end)

  describe("load", function()
    it("returns empty sources when config file does not exist", function()
      local result = config.load("/nonexistent/config.toml")
      assert.are.same({ sources = {} }, result)
      assert.are.equal(1, #wezterm._logs)
      assert.are.equal("info", wezterm._logs[1].level)
      assert.truthy(wezterm._logs[1].message:find("not found"))
    end)

    it("uses default path when none provided", function()
      local result = config.load()
      assert.are.same({ sources = {} }, result)
      assert.truthy(wezterm._logs[1].message:find("/home/testuser/.config/omni/config.toml"))
    end)

    it("errors on TOML parse failure", function()
      wezterm._files["/tmp/bad.toml"] = "invalid toml {{{"
      -- Override toml_decode to simulate parse error
      wezterm.serde.toml_decode = function()
        error("invalid TOML at line 1")
      end

      assert.has_error(function()
        config.load("/tmp/bad.toml")
      end)
    end)

    it("parses TOML and validates sources", function()
      wezterm._files["/tmp/good.toml"] = "toml content"
      wezterm.serde.toml_decode = function()
        return {
          sources = {
            { path = "/tmp/projects", type = "children" },
          },
        }
      end

      local result = config.load("/tmp/good.toml")
      assert.are.equal(1, #result.sources)
      assert.are.equal("/tmp/projects", result.sources[1].path)
      assert.are.equal("children", result.sources[1].type)
      assert.are.equal(5, result.sources[1].max_depth)
    end)
  end)
end)
