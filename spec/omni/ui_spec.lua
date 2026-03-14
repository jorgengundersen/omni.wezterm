describe("omni.ui", function()
  local ui

  before_each(function()
    package.loaded["omni.ui"] = nil
    ui = require("omni.ui")
  end)

  describe("build_choices", function()
    it("maps ProjectEntry[] to InputSelector choice format", function()
      local entries = {
        {
          id = "/home/user/projects/alpha",
          label = "projects/alpha",
          workspace_name = "projects/alpha",
        },
        {
          id = "/home/user/projects/beta.lua",
          label = "projects/beta.lua",
          workspace_name = "projects/beta_lua",
        },
      }

      local choices = ui.build_choices(entries)

      assert.are.equal(2, #choices)
      assert.are.equal("/home/user/projects/alpha", choices[1].id)
      assert.are.equal("projects/alpha", choices[1].label)
      assert.are.equal("/home/user/projects/beta.lua", choices[2].id)
      assert.are.equal("projects/beta.lua", choices[2].label)
    end)

    it("returns empty table for empty input", function()
      assert.are.same({}, ui.build_choices({}))
    end)
  end)

  describe("build_workspace_choices", function()
    it("maps workspace names to choices", function()
      local names = { "alpha", "beta_lua" }

      local choices = ui.build_workspace_choices(names)

      assert.are.equal(2, #choices)
      assert.are.equal("alpha", choices[1].id)
      assert.are.equal("alpha", choices[1].label)
      assert.are.equal("beta_lua", choices[2].id)
      assert.are.equal("beta_lua", choices[2].label)
    end)

    it("returns empty table for empty input", function()
      assert.are.same({}, ui.build_workspace_choices({}))
    end)
  end)
end)
