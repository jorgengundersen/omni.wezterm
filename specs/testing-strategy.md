# Testing Strategy

## Summary

This spec defines the testing approach for omni.wezterm following the trophy
testing model with black-box testing principles.

## Trophy Testing Model

The trophy model prioritizes tests roughly as:

```
         /\
        /  \       E2E (manual, minimal)
       /----\
      /      \     Integration (bulk of tests)
     /--------\
    /          \   Unit (pure functions only)
   /------------\
  / Static Types \  LuaCATS annotations
```

- **Static analysis**: LuaCATS type annotations catch type errors at edit time
- **Unit tests**: Small, focused tests for pure functions (path utils, name
  derivation, config parsing)
- **Integration tests**: Tests that exercise scanner -> discovery -> choices
  pipeline with a controlled filesystem fixture
- **E2E**: Manual testing in WezTerm (not automated)

## Black-Box Testing

Tests interact with modules through their public API only. Internal
implementation details are never tested directly.

**Do test**: "Given this filesystem structure, `discover(config)` returns these
entries"

**Don't test**: "The `_walk_tree` internal function is called with these
arguments"

This ensures tests don't break when internals are refactored.

## Test Framework

- **busted** for Lua testing (standard in the Lua ecosystem)
- Tests live in `spec/` mirroring the `lua/` structure
- Run via: `busted spec/`

## WezTerm API Stubs

Since tests run outside WezTerm, we need to stub WezTerm APIs. A shared
test helper module provides these stubs:

```lua
-- spec/support/wezterm_stub.lua

---@class WezTermStub
local M = {}

-- Simulated filesystem for read_dir
M._filesystem = {}

---@param path string
---@return string[]
function M.read_dir(path)
  return M._filesystem[path] or error("No such directory: " .. path)
end

---@return string
function M.home_dir()
  return "/home/testuser"
end

---@param args string[]
---@return boolean, string, string
function M.run_child_process(args)
  -- Simulate find command output based on _filesystem
  ...
end

function M.serde.toml_decode(text)
  -- Use a pure Lua TOML parser or pre-parsed test data
  ...
end

-- Reset between tests
function M._reset()
  M._filesystem = {}
end

return M
```

## Test Categories

### 1. Path Utility Tests (Unit)

Pure functions, no stubs needed.

```lua
describe("omni.path", function()
  describe("expand", function()
    it("replaces ~ with home directory", function()
      assert.equal("/home/user/Repos", path.expand("~/Repos", "/home/user"))
    end)

    it("leaves absolute paths unchanged", function()
      assert.equal("/etc/config", path.expand("/etc/config", "/home/user"))
    end)
  end)

  describe("basename", function()
    it("returns last component", function()
      assert.equal("project", path.basename("/home/user/Repos/project"))
    end)

    it("handles trailing slash", function()
      assert.equal("project", path.basename("/home/user/Repos/project/"))
    end)
  end)

  describe("derive_workspace_name", function()
    it("replaces dots with underscores", function()
      assert.equal("omni_wezterm", workspace.derive_name("/path/to/omni.wezterm"))
    end)
  end)
end)
```

### 2. Config Tests (Unit + Integration)

```lua
describe("omni.config", function()
  it("parses a valid TOML config", function()
    local toml = [[
      [[sources]]
      path = "~/Repos"
      type = "git_repos"
    ]]
    local config = config_mod.parse(toml)
    assert.equal(1, #config.sources)
    assert.equal("git_repos", config.sources[1].type)
  end)

  it("expands ~ in paths", function()
    local config = config_mod.parse(toml_with_tilde)
    assert.matches("^/home/", config.sources[1].path)
  end)

  it("returns defaults when config file is missing", function()
    local config = config_mod.load("/nonexistent/path.toml")
    assert.is_table(config.sources)
  end)
end)
```

### 3. Scanner Tests (Integration)

Each scanner is tested against a simulated filesystem:

```lua
describe("children scanner", function()
  before_each(function()
    stub_fs({
      ["/home/user/te-files/1_Projects"] = {
        "/home/user/te-files/1_Projects/project-a",
        "/home/user/te-files/1_Projects/project-b",
        "/home/user/te-files/1_Projects/some-file.txt",  -- should be filtered
      },
    })
  end)

  it("returns immediate child directories", function()
    local results = children.scan({ path = "/home/user/te-files/1_Projects" })
    assert.equal(2, #results)
    assert.equal("project-a", results[1].label)
    assert.equal("/home/user/te-files/1_Projects/project-a", results[1].id)
  end)

  it("returns empty list for missing directory", function()
    local results = children.scan({ path = "/nonexistent" })
    assert.equal(0, #results)
  end)
end)
```

### 4. Discovery Tests (Integration)

Tests the full pipeline from config to project list:

```lua
describe("omni.discovery", function()
  it("combines results from multiple sources", function()
    local config = {
      sources = {
        { path = "/home/user/te-files/1_Projects", type = "children" },
        { path = "/home/user/dotfiles", type = "self" },
      }
    }
    local entries = discovery.discover(config)
    -- Should contain children of 1_Projects + dotfiles itself
    assert.is_true(#entries >= 2)
  end)

  it("deduplicates entries with same path", function()
    local config = {
      sources = {
        { path = "/home/user/mydir", type = "self" },
        { path = "/home/user/mydir", type = "self" },
      }
    }
    local entries = discovery.discover(config)
    assert.equal(1, #entries)
  end)
end)
```

## Test Fixtures

For `git_repos` scanner testing, we create actual temporary directory
structures on disk with `.git` directories:

```lua
-- spec/support/fixtures.lua
local M = {}

function M.create_git_tree(base)
  -- Creates:
  -- base/github.com/org/repo-a/.git/
  -- base/github.com/org/repo-b/.git/
  -- base/local/experiment/.git/
  os.execute("mkdir -p " .. base .. "/github.com/org/repo-a/.git")
  os.execute("mkdir -p " .. base .. "/github.com/org/repo-b/.git")
  os.execute("mkdir -p " .. base .. "/local/experiment/.git")
end

function M.cleanup(base)
  os.execute("rm -rf " .. base)
end

return M
```

## Running Tests

```bash
# Install busted
luarocks install busted

# Run all tests
busted spec/

# Run specific test file
busted spec/omni/path_spec.lua

# Run with verbose output
busted spec/ --verbose
```

## CI Integration

Tests should be runnable in CI without WezTerm installed. The WezTerm stub
layer makes this possible. Only the `git_repos` scanner tests need actual
filesystem access (via temp directories).

## Test-Driven Development Workflow

Following red/green TDD:

1. **Red**: Write a failing test for the next small behavior
2. **Green**: Write the minimum code to make it pass
3. **Refactor**: Clean up while keeping tests green
4. **Commit**: Conventional commit with the feature/fix

Example cycle:
```
feat(path): add expand function for ~ replacement
test(path): add tests for path.expand
feat(scanners): add children scanner
test(scanners): add tests for children scanner
...
```
