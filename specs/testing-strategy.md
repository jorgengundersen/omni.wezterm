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
  derivation, config validation)
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

-- Reset between tests
function M._reset()
  M._filesystem = {}
end

return M
```

## TOML Parsing in Tests

### Approach: Pre-Parsed Lua Tables

Config tests bypass TOML parsing entirely and work with pre-parsed Lua
tables. The `config` module is tested via a `validate(lua_table)` function
that accepts already-parsed data, not raw TOML strings.

**Rationale**: `wezterm.serde.toml_decode` is WezTerm's built-in parser
(backed by Rust's `toml` crate). It is not available outside WezTerm and
would require a separate Lua TOML library to stub. Adding a test-only TOML
dependency introduces risk of parser divergence (the Lua library may parse
differently than WezTerm's Rust implementation), giving false confidence.

**What this covers**:
- Config validation (required fields, type checking, unknown scanner types)
- Path expansion (`~`, `$VAR`, `${VAR}`)
- Config merging (defaults + overrides)
- Error handling (fail-fast on validation errors)

**What this does NOT cover**:
- Actual TOML parsing (syntax errors, encoding edge cases, TOML spec
  compliance). These are covered by manual E2E testing in WezTerm.
- The TOML-to-Lua-table conversion itself.

**Known limitation**: A typo in TOML key names (e.g., `paths` instead of
`path`) would not be caught by automated tests. This is accepted as a
reasonable tradeoff. The config validation layer catches missing required
fields, which covers the most common case.

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

    it("expands $HOME environment variable", function()
      -- With HOME=/home/user in the test environment
      assert.equal("/home/user/Repos", path.expand("$HOME/Repos"))
    end)

    it("expands ${VAR} syntax", function()
      assert.equal("/home/user/Repos", path.expand("${HOME}/Repos"))
    end)

    it("returns original path when env var is unresolvable", function()
      -- path.expand returns nil or the original when var is not set
      local result, err = path.expand("$NONEXISTENT/foo")
      assert.is_nil(result)
      assert.matches("unresolved", err)
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
end)
```

### 2. Workspace Name Derivation Tests (Unit)

```lua
describe("omni.workspace", function()
  describe("derive_name", function()
    it("replaces dots with underscores", function()
      assert.equal(
        "github_com/jorgengundersen/omni_wezterm",
        workspace.derive_name("github.com/jorgengundersen/omni.wezterm")
      )
    end)

    it("preserves slashes", function()
      assert.equal("local/my-experiment", workspace.derive_name("local/my-experiment"))
    end)

    it("handles simple basenames", function()
      assert.equal("dotfiles", workspace.derive_name("dotfiles"))
    end)

    it("handles PARA category labels", function()
      assert.equal("1_Projects/My-Project", workspace.derive_name("1_Projects/My-Project"))
    end)
  end)
end)
```

### 3. Config Tests (Unit + Integration)

```lua
describe("omni.config", function()
  it("validates a correct config table", function()
    local raw = {
      sources = {
        { path = "~/Repos", type = "git_repos" },
        { path = "~/dotfiles", type = "self" },
      }
    }
    local config = config_mod.validate(raw)
    assert.equal(2, #config.sources)
    assert.equal("git_repos", config.sources[1].type)
  end)

  it("expands ~ in paths", function()
    local raw = {
      sources = {
        { path = "~/Repos", type = "git_repos" },
      }
    }
    local config = config_mod.validate(raw)
    assert.matches("^/home/", config.sources[1].path)
  end)

  it("fails fast on unknown scanner type", function()
    local raw = {
      sources = {
        { path = "~/Repos", type = "foobar" },
      }
    }
    assert.has_error(function()
      config_mod.validate(raw)
    end, "unknown type 'foobar'")
  end)

  it("fails fast on missing required field", function()
    local raw = {
      sources = {
        { path = "~/Repos" },  -- missing type
      }
    }
    assert.has_error(function()
      config_mod.validate(raw)
    end)
  end)

  it("returns defaults when config file is missing", function()
    local config = config_mod.load("/nonexistent/path.toml")
    assert.is_table(config.sources)
    assert.equal(0, #config.sources)
  end)
end)
```

### 4. Scanner Tests (Integration)

Each scanner is tested against a simulated filesystem.

Tests verify the three-field `ProjectEntry` model (`id`, `label`,
`workspace_name`):

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

  it("returns immediate child directories with contextual labels", function()
    local results = children.scan({ path = "/home/user/te-files/1_Projects" })
    assert.equal(2, #results)

    assert.equal("/home/user/te-files/1_Projects/project-a", results[1].id)
    assert.equal("1_Projects/project-a", results[1].label)
    assert.equal("1_Projects/project-a", results[1].workspace_name)
  end)

  it("returns empty list for missing directory", function()
    local results = children.scan({ path = "/nonexistent" })
    assert.equal(0, #results)
  end)
end)

describe("self scanner", function()
  it("returns a single entry for the directory itself", function()
    stub_fs({
      ["/home/user/dotfiles"] = {},
    })
    local results = self_scanner.scan({ path = "/home/user/dotfiles" })
    assert.equal(1, #results)
    assert.equal("/home/user/dotfiles", results[1].id)
    assert.equal("dotfiles", results[1].label)
    assert.equal("dotfiles", results[1].workspace_name)
  end)
end)

describe("grandchildren scanner", function()
  before_each(function()
    stub_fs({
      ["/home/user/te-files/3_Resources"] = {
        "/home/user/te-files/3_Resources/C",
        "/home/user/te-files/3_Resources/P",
      },
      ["/home/user/te-files/3_Resources/C"] = {
        "/home/user/te-files/3_Resources/C/Courses",
      },
      ["/home/user/te-files/3_Resources/P"] = {
        "/home/user/te-files/3_Resources/P/Photography",
      },
    })
  end)

  it("returns two-level deep entries with contextual labels", function()
    local results = grandchildren.scan({ path = "/home/user/te-files/3_Resources" })
    assert.equal(2, #results)
    assert.equal("3_Resources/C/Courses", results[1].label)
    assert.equal("3_Resources/C/Courses", results[1].workspace_name)
  end)
end)
```

### 5. Discovery Tests (Integration)

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

  it("deduplicates entries with same absolute path", function()
    local config = {
      sources = {
        { path = "/home/user/mydir", type = "self" },
        { path = "/home/user/mydir", type = "self" },
      }
    }
    local entries = discovery.discover(config)
    assert.equal(1, #entries)
  end)

  it("sorts entries by label using case-sensitive ASCII order", function()
    -- Setup: entries with labels "0_Inbox", "dotfiles", "github.com/..."
    local entries = discovery.discover(config_with_mixed_sources)
    for i = 1, #entries - 1 do
      assert.is_true(entries[i].label < entries[i + 1].label)
    end
  end)

  it("returns entries with all three fields populated", function()
    local config = {
      sources = {
        { path = "/home/user/dotfiles", type = "self" },
      }
    }
    local entries = discovery.discover(config)
    assert.equal(1, #entries)
    assert.equal("/home/user/dotfiles", entries[1].id)
    assert.equal("dotfiles", entries[1].label)
    assert.equal("dotfiles", entries[1].workspace_name)
  end)
end)
```

### 6. Active Workspace Selector Tests (Integration)

Tests for tmux `<prefix+s>` equivalent behavior:

```lua
describe("active workspace selector", function()
  it("shows active workspaces from mux API", function()
    wezterm_stub.mux_workspace_names = { "dotfiles", "github_com/jorgengundersen/omni_wezterm" }
    local choices = ui.build_workspace_choices(workspace.list_active())
    assert.equal(2, #choices)
    assert.equal("dotfiles", choices[1].id)
  end)

  it("switches to selected workspace", function()
    local window = fake_window()
    workspace.switch_to(window, fake_pane(), "github_com/jorgengundersen/omni_wezterm")
    assert.action_called(window, "SwitchToWorkspace", {
      name = "github_com/jorgengundersen/omni_wezterm"
    })
  end)

  it("returns early when no active workspaces", function()
    wezterm_stub.mux_workspace_names = {}
    local handled = omni.handle_active_workspace_selector(fake_window(), fake_pane(), {})
    assert.is_true(handled)
    assert.log_called("info", "No active workspaces")
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

**Note**: The `git_repos` scanner uses `wezterm.run_child_process` with
`find` on Linux/macOS or Lua-native walking on Windows. In tests, the
`run_child_process` stub simulates `find` output based on the test fixture
directory structure. On CI, tests that need real filesystem access create
temp directories and use the Lua-native code path.

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
