# Plugin Architecture

## Summary

This spec defines the module structure, plugin entry point, and internal
architecture of omni.wezterm following WezTerm plugin conventions and Lua
best practices.

## File Structure

```
omni.wezterm/
  plugin/
    init.lua              -- Plugin entry point (required by WezTerm)
  lua/
    omni/
      init.lua            -- Main module, exports apply_to_config
      config.lua          -- Config loading and validation
      discovery.lua       -- Orchestrates scanners, produces project list
      scanners/
        init.lua          -- Scanner registry
        git_repos.lua     -- git_repos scanner
        children.lua      -- children scanner
        grandchildren.lua -- grandchildren scanner
        self.lua          -- self scanner
      workspace.lua       -- Workspace name derivation and switching logic
      ui.lua              -- InputSelector construction
      path.lua            -- Path utilities (expand ~, basename, is_dir, etc.)
  spec/
    omni/
      config_spec.lua
      discovery_spec.lua
      scanners/
        git_repos_spec.lua
        children_spec.lua
        grandchildren_spec.lua
        self_spec.lua
      workspace_spec.lua
      path_spec.lua
  specs/                  -- Specification documents (this directory)
  CHANGELOG.md
  README.md
```

## Plugin Entry Point

`plugin/init.lua` is the file WezTerm loads via `wezterm.plugin.require`.
It must return a table with an `apply_to_config` function.

```lua
-- plugin/init.lua

-- Set up package.path so we can require our internal modules
local this_dir = debug.getinfo(1, "S").source:match("@(.*/)") or ""
package.path = this_dir .. "../lua/?.lua;" .. this_dir .. "../lua/?/init.lua;" .. package.path

local omni = require("omni")
return omni
```

**Note**: The `package.path` manipulation follows WezTerm plugin conventions
for multi-file plugins (see plugin docs "Managing a Plugin with Multiple Lua
Modules").

## Module Responsibilities

### `omni.init` (main module)

- Exports `apply_to_config(config, opts?)` as the plugin's public API
- Loads configuration (TOML or inline)
- Registers a keybinding that triggers the project selector
- Wires together config -> discovery -> UI -> workspace switching

### `omni.config`

- `load(path?) -> omni.Config` -- loads and validates TOML config
- `default() -> omni.Config` -- returns sensible defaults
- `merge(defaults, overrides) -> omni.Config` -- merges configs
- Uses `wezterm.serde.toml_decode` and file I/O to read the TOML file

### `omni.discovery`

- `discover(config) -> omni.ProjectEntry[]` -- runs all configured scanners
  and returns a deduplicated, sorted list
- Iterates over `config.sources`, dispatches to the appropriate scanner,
  collects and deduplicates results

### `omni.scanners.*`

Each scanner module exports a single function:

```lua
---@param source omni.SourceConfig
---@return omni.ProjectEntry[]
function M.scan(source) end
```

Scanners are pure functions over the filesystem. They depend on
`wezterm.read_dir` or `wezterm.run_child_process` but have no other
side effects.

### `omni.workspace`

- `derive_name(path) -> string` -- derives a workspace name from a path
- `switch_or_create(window, pane, path, name)` -- switches to an existing
  workspace or creates a new one with the given cwd

### `omni.ui`

- `build_choices(entries) -> InputSelector.choices[]` -- converts project
  entries to InputSelector choice format
- `show_selector(window, pane, choices, callback)` -- triggers the
  InputSelector overlay

### `omni.path`

Pure utility functions:
- `expand(path) -> string` -- expands `~` to home directory
- `basename(path) -> string` -- returns last path component
- `is_directory(path) -> boolean` -- checks if path is a directory
- `relative(path, base) -> string` -- makes path relative to base
- `join(...) -> string` -- joins path components

## Design Principles

### Composable Primitives

Every module is a small, focused "lego brick":

- **Pure functions** for logic (path manipulation, name derivation, label
  formatting, config merging)
- **Thin wrappers** around WezTerm APIs for I/O (read_dir, run_child_process,
  toml_decode, InputSelector, SwitchToWorkspace)

### Dependency Injection for Testability

Scanner functions accept their dependencies (path utilities, directory readers)
as parameters or via module-level configuration, making them testable without
mocking the entire WezTerm runtime.

For testing, we provide a `test_helpers` module that stubs WezTerm APIs:

```lua
-- In tests, we can replace wezterm.read_dir with a fake
local fake_fs = {
  ["/home/user/te-files/1_Projects"] = {
    "/home/user/te-files/1_Projects/project-a",
    "/home/user/te-files/1_Projects/project-b",
  },
}
```

### Error Handling

- Scanner errors (missing paths, permission denied) are caught and logged
  via `wezterm.log_warn`, never crashing the plugin
- Config errors produce clear error messages and fall back to defaults
- The plugin should always be usable even if some sources fail

## Public API

The plugin exposes exactly one public function:

```lua
---@param config table     WezTerm config builder
---@param opts? table      Plugin options
---  opts.key: string      Keybinding key (default: "p")
---  opts.mods: string     Keybinding modifiers (default: "CTRL|SHIFT")
---  opts.config_file: string  Path to TOML config (default: ~/.config/omni/config.toml)
---  opts.title: string    InputSelector title (default: "Switch Project")
---  opts.fuzzy: boolean   Start in fuzzy mode (default: true)
function M.apply_to_config(config, opts) end
```

`apply_to_config` appends a key binding to `config.keys` that, when triggered:
1. Loads/refreshes the TOML config
2. Runs discovery to get the project list
3. Shows the InputSelector
4. On selection, switches to or creates the workspace

## Caching Strategy

Directory discovery can be expensive (especially `git_repos`). The plugin uses
`wezterm.GLOBAL` to cache results:

```lua
wezterm.GLOBAL.omni_cache = {
  entries = { ... },       -- cached project entries
  timestamp = 1234567890,  -- when the cache was built
}
```

Cache is invalidated:
- After a configurable TTL (default: 300 seconds / 5 minutes)
- When the user explicitly refreshes (optional future feature)
- On WezTerm config reload

## Thread Safety

WezTerm's Lua runs single-threaded per event callback. No concurrent access
concerns within a single callback. However, `wezterm.GLOBAL` is shared across
all callbacks, so cache reads/writes should be atomic (replace the whole table
rather than mutating in place).
