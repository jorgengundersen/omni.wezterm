describe("path", function()
  local path

  before_each(function()
    package.loaded["path"] = nil
    path = require("path")
  end)

  describe("basename", function()
    it("returns last component of a path", function()
      assert.equal("bar", path.basename("/foo/bar"))
    end)

    it("handles trailing slash", function()
      assert.equal("bar", path.basename("/foo/bar/"))
    end)

    it("returns single component", function()
      assert.equal("foo", path.basename("foo"))
    end)

    it("returns / for root path", function()
      assert.equal("/", path.basename("/"))
    end)
  end)

  describe("expand", function()
    it("replaces ~ with home parameter", function()
      assert.equal("/home/testuser/projects", path.expand("~/projects", "/home/testuser"))
    end)

    it("leaves absolute paths unchanged", function()
      assert.equal("/usr/local/bin", path.expand("/usr/local/bin", "/home/testuser"))
    end)

    it("expands $VAR using os.getenv", function()
      local original_home = os.getenv("HOME")
      if original_home then
        assert.equal(original_home .. "/code", path.expand("$HOME/code", "/unused"))
      end
    end)

    it("expands ${VAR} using os.getenv", function()
      local original_home = os.getenv("HOME")
      if original_home then
        assert.equal(original_home .. "/code", path.expand("${HOME}/code", "/unused"))
      end
    end)

    it("returns nil and error for unresolvable var", function()
      local result, err = path.expand("$NONEXISTENT_VAR_XYZZY_12345/foo", "/home/testuser")
      assert.is_nil(result)
      assert.matches("unresolvable", err)
    end)
  end)

  describe("join", function()
    it("joins two segments", function()
      assert.equal("foo/bar", path.join("foo", "bar"))
    end)

    it("avoids double slashes from trailing slash", function()
      assert.equal("foo/bar", path.join("foo/", "bar"))
    end)

    it("joins multiple segments", function()
      assert.equal("foo/bar/baz", path.join("foo", "bar", "baz"))
    end)
  end)
end)
