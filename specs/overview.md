# omni.wezterm Overview

## Summary

omni.wezterm is a WezTerm plugin that replaces the tmux-sessionizer workflow
with a native WezTerm workspace-based approach. It scans configurable directory
structures for projects, presents them via WezTerm's `InputSelector` with fuzzy
finding, and creates/switches WezTerm workspaces with the working directory set
to the selected project.

## Goals

1. Replace the tmux-sessionizer bash script with a native Lua plugin
2. Provide intelligent, configurable directory scanning to build a project list
3. Use WezTerm workspaces as the session primitive (analogous to tmux sessions)
4. Present projects in a fuzzy-searchable `InputSelector` overlay
5. Switch to existing workspaces or create new ones on selection
6. Be installable as a standard WezTerm plugin via `wezterm.plugin.require`
7. Provide a quick "list active workspaces" selector (tmux `<prefix+s>` equivalent)
8. Work cross-platform (Linux, macOS, Windows)

## Non-Goals

- Replicating tmux's pane/window management (WezTerm has its own)
- Providing a terminal multiplexer replacement beyond session/project switching
- Managing git operations or project scaffolding
- Replicating the exact behavior of tmux-sessionizer (this is a redesign
  optimized for WezTerm, not a 1:1 port)

## Design Note: Structured Scanning vs tmux-sessionizer

The original tmux-sessionizer uses a broad `find` that lists *all* directories
under `~/Repos` and `~/te-files`. This plugin intentionally replaces that with
structured, type-specific scanners. Directories that don't match any configured
scanner are excluded. If a directory is missing from the list, the user adds a
new source entry to the config. This is a deliberate tradeoff: precision and
clarity over catch-all discovery.

## Mapping: tmux-sessionizer to WezTerm

| tmux concept | WezTerm equivalent |
|---|---|
| tmux session | WezTerm workspace |
| `tmux new-session -s NAME -c DIR` | `SwitchToWorkspace { name = NAME, spawn = { cwd = DIR } }` |
| `tmux switch-client -t NAME` | `SwitchToWorkspace { name = NAME }` (switches if exists) |
| tmux session list (`<prefix+s>`) | WezTerm `InputSelector` showing active workspaces |
| `fzf` selection | `InputSelector` with `fuzzy = true` |
| `find ... \| fzf` | Lua directory scanner -> `InputSelector` choices |

## User Experience

1. User presses a configured keybinding (e.g., `CTRL+SHIFT+P`)
2. An `InputSelector` overlay appears with all discovered projects
3. Each entry shows a contextual label (e.g., `github.com/jorgengundersen/omni.wezterm`)
4. User fuzzy-searches and selects a project
5. If a workspace with that name already exists, switch to it
6. If not, create a new workspace with the shell opened in that directory
7. If the user cancels (presses Escape), do nothing silently

### Active Workspace Selector

1. User presses a configured keybinding (default: `CTRL+SHIFT+S`)
2. An `InputSelector` overlay appears with currently active workspaces
3. User fuzzy-searches and selects a workspace
4. Plugin switches to the selected workspace (no project discovery scan)
5. If no workspaces are available, show an info log and do nothing
6. If the user cancels (presses Escape), do nothing silently

## Plugin Installation

```lua
-- In wezterm.lua
local wezterm = require 'wezterm'
local omni = wezterm.plugin.require 'https://github.com/jorgengundersen/omni.wezterm'

local config = wezterm.config_builder()
omni.apply_to_config(config)
-- or with custom config:
omni.apply_to_config(config, {
  key = 'p',
  mods = 'CTRL|SHIFT',
  config_file = wezterm.home_dir .. '/.config/omni/config.toml',
})

return config
```

## Technology Decisions

- **Language**: Lua (WezTerm's plugin language)
- **Type hints**: LuaCATS annotations for IDE support
- **Configuration**: TOML file at `$HOME/.config/omni/config.toml`
  (parsed via `wezterm.serde.toml_decode`)
- **Directory scanning**: `wezterm.read_dir` and `wezterm.glob` for basic
  scanning; `wezterm.run_child_process` with platform-appropriate commands
  for deep tree walking (with Lua-native fallback on Windows)
- **UI**: `InputSelector` with fuzzy mode enabled
- **Session management**: WezTerm workspaces via `SwitchToWorkspace`
- **Testing**: busted framework, trophy model (mostly integration tests),
  black-box approach
- **Commits**: Conventional Commits format
- **Platform**: Cross-platform (Linux, macOS, Windows)

## Design Principles

### Fail-Fast with Meaningful Errors

The plugin follows a fail-fast strategy:

- **Hard errors** (invalid TOML syntax, missing required config fields, unknown
  scanner types) stop execution immediately and surface a clear error message
  via `wezterm.log_error` and a WezTerm toast notification so the user is
  immediately aware something is wrong
- **Soft warnings** (missing directory paths, unresolvable environment variables
  in paths, empty scan results) are logged via `wezterm.log_warn` and the
  source is skipped -- the plugin continues with remaining sources
- Error messages always include enough context to diagnose the problem
  (file path, source index, field name, expected vs actual values)

### Composable Primitives

Every module is a small, focused "lego brick":

- **Pure functions** for logic (path manipulation, name derivation, label
  formatting, config validation)
- **Thin wrappers** around WezTerm APIs for I/O (read_dir, run_child_process,
  toml_decode, InputSelector, SwitchToWorkspace)

## Future Optimizations (Not in v1)

- **Caching**: Directory discovery results could be cached in
  `wezterm.GLOBAL` with a TTL to avoid re-scanning on every selector
  invocation. Deferred until performance is measured and found lacking.
- **Active workspace highlighting**: Marking currently active workspaces
  in the project selector list.
