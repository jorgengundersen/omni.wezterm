# omni.wezterm

A WezTerm plugin that scans your directories for projects and switches workspaces — like tmux-sessionizer, but native.

## Features

- **4 scanner types** — `git_repos`, `children`, `grandchildren`, `self` — cover any directory layout
- **Fuzzy-find** — type partial names to quickly jump to any project
- **TOML config** — declarative `~/.config/omni/config.toml`, no Lua config needed
- **Hot-reload** — config is re-read on every invocation, changes take effect immediately
- **Cross-platform** — Linux, macOS, and Windows

## Installation

Add to your `wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local omni = wezterm.plugin.require 'https://github.com/jorgengundersen/omni.wezterm'

local config = wezterm.config_builder()
omni.apply_to_config(config)

return config
```

## Configuration

Create `~/.config/omni/config.toml`:

```toml
# Recursively find git repos (walks tree looking for .git directories)
[[sources]]
path = "~/Repos"
type = "git_repos"
max_depth = 5

# List immediate subdirectories as projects
[[sources]]
path = "~/Projects"
type = "children"

# Two levels deep — useful for grouped directories like Resources/A-Z/Name
[[sources]]
path = "~/Resources"
type = "grandchildren"

# A single directory, added as-is
[[sources]]
path = "~/dotfiles"
type = "self"
```

| Scanner        | Depth | Use case                                    |
|----------------|-------|---------------------------------------------|
| `git_repos`    | recursive (configurable `max_depth`, default 5) | Trees of git repositories |
| `children`     | 1     | Flat project directories                    |
| `grandchildren`| 2     | Grouped directories (`topic/name`)          |
| `self`         | 0     | Individual directories                      |

## Keybindings

| Default          | Action                              |
|------------------|-------------------------------------|
| `Ctrl+Shift+P`   | Open project selector (scan + pick) |
| `Ctrl+Shift+S`   | Switch between active workspaces    |

Override in `apply_to_config`:

```lua
omni.apply_to_config(config, {
  key = 'p',
  mods = 'CTRL|SHIFT',
  active_key = 's',
  active_mods = 'CTRL|SHIFT',
})
```

## How It Works

1. You press `Ctrl+Shift+P`
2. omni reads your TOML config and runs each scanner
3. Results are deduplicated, sorted, and shown in WezTerm's InputSelector
4. You fuzzy-search and pick a project
5. omni creates a new workspace (or switches to an existing one) with your shell opened in that directory

Each project gets a workspace name derived from its display label (dots replaced with underscores), so workspaces persist across selector invocations.

`Ctrl+Shift+S` shows only your currently active workspaces for quick switching without rescanning.

## Design

See [`specs/`](specs/) for detailed design documents covering architecture, configuration, discovery, and testing strategy.
