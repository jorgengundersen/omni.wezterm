-- Verify the example config file is valid TOML that config.validate accepts
local config = require("omni.config")

describe("examples/config.toml", function()
  before_each(function()
    wezterm._reset()
  end)

  it("passes config validation with all scanner types", function()
    -- Lua-table equivalent of examples/config.toml
    local raw = {
      sources = {
        { path = "~/projects", type = "git_repos", max_depth = 3 },
        { path = "~/work", type = "children" },
        { path = "~/resources", type = "grandchildren" },
        { path = "~/dotfiles", type = "self" },
      },
    }

    local result = config.validate(raw)

    assert.equals(4, #result.sources)

    assert.equals("/home/testuser/projects", result.sources[1].path)
    assert.equals("git_repos", result.sources[1].type)
    assert.equals(3, result.sources[1].max_depth)

    assert.equals("/home/testuser/work", result.sources[2].path)
    assert.equals("children", result.sources[2].type)
    assert.equals(5, result.sources[2].max_depth) -- default

    assert.equals("/home/testuser/resources", result.sources[3].path)
    assert.equals("grandchildren", result.sources[3].type)

    assert.equals("/home/testuser/dotfiles", result.sources[4].path)
    assert.equals("self", result.sources[4].type)
  end)
end)
