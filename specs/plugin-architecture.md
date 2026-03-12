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
      path.lua            -- Path utilities (expand ~, env vars, basename, etc.)
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
- Registers keybindings for project selector and active workspace selector
- Wires together config -> discovery -> UI -> workspace switching

### `omni.config`

- `load(path?) -> omni.Config` -- loads and validates TOML config
- `default() -> omni.Config` -- returns sensible defaults
- `merge(defaults, overrides) -> omni.Config` -- merges configs
- Uses `wezterm.serde.toml_decode` and file I/O to read the TOML file
- **Fail-fast**: TOML parse errors and validation errors raise immediately
  (see Error Handling section)

### `omni.discovery`

- `discover(config) -> omni.ProjectEntry[]` -- runs all configured scanners
  and returns a deduplicated, sorted list
- Iterates over `config.sources`, dispatches to the appropriate scanner,
  collects and deduplicates results
- Sorting is case-sensitive ASCII (standard string comparison)

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

- `derive_name(label) -> string` -- derives a workspace name from a label
  by replacing dots with underscores
- `list_active() -> string[]` -- returns active workspace names from mux API
- `switch_or_create(window, pane, path, name)` -- switches to an existing
  workspace or creates a new one with the given cwd
- `switch_to(window, pane, name)` -- switches to an existing workspace by name

### `omni.ui`

- `build_choices(entries) -> InputSelector.choices[]` -- converts project
  entries to InputSelector choice format
- `build_workspace_choices(names) -> InputSelector.choices[]` -- converts
  workspace names to InputSelector choice format
- `show_selector(window, pane, choices, callback)` -- triggers the
  InputSelector overlay

### `omni.path`

Pure utility functions:
- `expand(path) -> string` -- expands `~` to home directory and `$VAR` /
  `${VAR}` environment variables
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

The plugin follows a **fail-fast** strategy with two severity levels:

#### Hard Errors (fail immediately)

These stop execution and surface the error via `wezterm.log_error` **and**
a WezTerm toast notification (`window:toast_notification`) so the user is
immediately aware:

- TOML config file exists but has syntax errors
- A source entry has an unknown `type` (not one of `git_repos`, `children`,
  `grandchildren`, `self`)
- A source entry is missing required fields (`path` or `type`)
- A required field has the wrong type (e.g., `path` is a number)

Error messages include:
- The config file path
- The source index (e.g., "source #3")
- The field name and expected vs actual value
- Example: `"omni.wezterm: config error in source #3: unknown type 'foobar' (expected git_repos|children|grandchildren|self)"`

#### Soft Warnings (log and continue)

These are logged via `wezterm.log_warn` and the affected source is skipped.
The plugin continues processing remaining sources:

- Config file does not exist (logged via `wezterm.log_info`, uses empty
  sources -- user may not have created it yet)
- A configured path does not exist on disk (supports multi-machine configs)
- An environment variable in a path does not resolve
- A scanner returns zero entries for a valid path
- `wezterm.run_child_process` returns a non-zero exit code (the scanner
  logs the error and returns an empty list)

## Public API

The plugin exposes exactly one public function:

```lua
---@param config table     WezTerm config builder
---@param opts? table      Plugin options
---  opts.key: string      Keybinding key (default: "p")
---  opts.mods: string     Keybinding modifiers (default: "CTRL|SHIFT")
---  opts.active_key: string   Active workspace selector key (default: "s")
---  opts.active_mods: string  Active selector modifiers (default: "CTRL|SHIFT")
---  opts.config_file: string  Path to TOML config (default: ~/.config/omni/config.toml)
---  opts.title: string    InputSelector title (default: "Switch Project")
---  opts.fuzzy: boolean   Start in fuzzy mode (default: true)
---  opts.active_title: string   Active selector title (default: "Switch Workspace")
---  opts.active_fuzzy: boolean  Active selector fuzzy mode (default: true)
function M.apply_to_config(config, opts) end
```

### Idempotency

`apply_to_config` must be safe to call only once. If called multiple times,
it must not register duplicate keybindings. The implementation should track
whether it has already been applied (e.g., via a flag on the config table
or in a module-level variable) and skip registration on subsequent calls.

```lua
-- Guard against double registration
if config._omni_applied then
  wezterm.log_warn("omni.wezterm: apply_to_config called more than once, skipping")
  return
end
config._omni_applied = true
```

### Behavior

`apply_to_config` appends a key binding to `config.keys` that, when triggered:
1. Loads/refreshes the TOML config
2. Runs discovery to get the project list
3. Shows the InputSelector
4. On selection, switches to or creates the workspace
5. On cancellation (Escape), does nothing silently

`apply_to_config` also appends an active workspace key binding that, when
triggered:
1. Reads active workspace names from the mux API
2. Builds and shows an InputSelector over active names
3. On selection, switches to that workspace
4. On cancellation (Escape), does nothing silently

**Note**: This plugin only works with the default key table (`config.keys`).
Users who use WezTerm's `key_tables` for modal keybindings will need to
register the actions manually.

## Future Optimizations (Not in v1)

- **Caching**: Directory discovery results could be cached in
  `wezterm.GLOBAL` with a TTL to avoid re-scanning on every selector
  invocation. Deferred until performance is measured and found lacking.
  When implemented, `wezterm.GLOBAL` writes should be atomic (replace
  the whole table rather than mutating in place) since it is shared
  across all callbacks.

## Thread Safety

WezTerm's Lua runs single-threaded per event callback. No concurrent access
concerns within a single callback.
