describe("omni.discovery", function()
  local discovery
  local scanners

  before_each(function()
    -- Clear both modules so discovery gets a fresh scanners instance
    package.loaded["omni.scanners"] = nil
    package.loaded["omni.discovery"] = nil

    scanners = require("omni.scanners")
    discovery = require("omni.discovery")
  end)

  describe("discover", function()
    it("dispatches each source through scanners.dispatch", function()
      scanners.register("self", {
        scan = function(source)
          return {
            { id = source.path, label = "dotfiles", workspace_name = "dotfiles" },
          }
        end,
      })

      local config = {
        sources = {
          { path = "/home/user/dotfiles", type = "self" },
        },
      }
      local entries = discovery.discover(config)
      assert.equal(1, #entries)
      assert.equal("/home/user/dotfiles", entries[1].id)
    end)

    it("combines results from multiple sources", function()
      scanners.register("self", {
        scan = function(source)
          local basename = source.path:match("([^/]+)$")
          return {
            { id = source.path, label = basename, workspace_name = basename },
          }
        end,
      })

      local config = {
        sources = {
          { path = "/home/user/dotfiles", type = "self" },
          { path = "/home/user/notes", type = "self" },
        },
      }
      local entries = discovery.discover(config)
      assert.equal(2, #entries)
    end)

    it("deduplicates entries with same id", function()
      scanners.register("self", {
        scan = function(source)
          local basename = source.path:match("([^/]+)$")
          return {
            { id = source.path, label = basename, workspace_name = basename },
          }
        end,
      })

      local config = {
        sources = {
          { path = "/home/user/dotfiles", type = "self" },
          { path = "/home/user/dotfiles", type = "self" },
        },
      }
      local entries = discovery.discover(config)
      assert.equal(1, #entries)
    end)

    it("sorts entries by label", function()
      scanners.register("self", {
        scan = function(source)
          local basename = source.path:match("([^/]+)$")
          return {
            { id = source.path, label = basename, workspace_name = basename },
          }
        end,
      })

      local config = {
        sources = {
          { path = "/home/user/zebra", type = "self" },
          { path = "/home/user/alpha", type = "self" },
        },
      }
      local entries = discovery.discover(config)
      assert.equal("alpha", entries[1].label)
      assert.equal("zebra", entries[2].label)
    end)

    it("propagates validation errors from scanners.dispatch", function()
      scanners.register("bad", {
        scan = function()
          return {
            { id = 42, label = "x", workspace_name = "x" },
          }
        end,
      })

      local config = {
        sources = {
          { path = "/tmp", type = "bad" },
        },
      }
      assert.has_error(function()
        discovery.discover(config)
      end, "omni.wezterm: scanner 'bad' returned invalid entry #1: field 'id' must be a string, got number")
    end)
  end)
end)
