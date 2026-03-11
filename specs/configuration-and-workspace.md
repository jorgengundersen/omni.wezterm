# Configuration & Workspace Management

## Summary

This spec details the configuration file format, loading behavior, and
workspace management (name derivation, creation, switching).

## Configuration File

### Location

Default: `$HOME/.config/omni/config.toml`

Overridable via the `config_file` option in `apply_to_config`:

```lua
omni.apply_to_config(config, {
  config_file = wezterm.home_dir .. '/.config/omni/config.toml',
})
```

### Full Configuration Example

```toml
# omni.wezterm configuration
# All paths support ~ expansion to $HOME

# --- Git repository trees ---
# Recursively finds directories containing .git
[[sources]]
path = "~/Repos"
type = "git_repos"
max_depth = 5

# --- PARA method (te-files) ---
# 0_Inbox: listed as a single entry
[[sources]]
path = "~/te-files/0_Inbox"
type = "self"

# 1_Projects: immediate children listed
[[sources]]
path = "~/te-files/1_Projects"
type = "children"

# 2_Areas: immediate children listed
[[sources]]
path = "~/te-files/2_Areas"
type = "children"

# 3_Resources: two levels deep (e.g., C/Courses)
[[sources]]
path = "~/te-files/3_Resources"
type = "grandchildren"

# 4_Archive: immediate children listed
[[sources]]
path = "~/te-files/4_Archive"
type = "children"

# 5_Zettel: listed as a single entry
[[sources]]
path = "~/te-files/5_Zettel"
type = "self"

# --- Additional specific directories ---
[[sources]]
path = "~/dotfiles"
type = "self"
```

### Config Loading Behavior

1. Read the file at the config path
2. If the file doesn't exist, use built-in defaults (empty sources list)
   and log a `wezterm.log_info` message
3. Parse TOML via `wezterm.serde.toml_decode`
4. Validate each source entry:
   - `path` is required and must be a string
   - `type` is required and must be one of: `git_repos`, `children`,
     `grandchildren`, `self`
   - `max_depth` is optional (only relevant for `git_repos`), defaults to 5
5. Expand `~` in all paths
6. Return the validated config

### Config Reload

The TOML config is read on every invocation of the project selector (each
keypress), unless caching is active. This means changes to the config file
take effect on the next selector invocation without restarting WezTerm.

If WezTerm config reload is triggered, `wezterm.add_to_config_reload_watch_list`
can be used to watch the TOML file for changes too.

## Workspace Management

### Name Derivation

The workspace name is derived from the selected directory path:

```lua
---@param path string  Absolute path to the project directory
---@return string      Workspace name
function derive_name(path)
  local name = basename(path)
  -- Replace dots with underscores (matching tmux-sessionizer convention)
  name = name:gsub("%.", "_")
  return name
end
```

Examples:
| Path | Workspace Name |
|---|---|
| `/home/user/Repos/github.com/jorgengundersen/omni.wezterm` | `omni_wezterm` |
| `/home/user/te-files/0_Inbox` | `0_Inbox` |
| `/home/user/te-files/3_Resources/C/Courses` | `Courses` |
| `/home/user/dotfiles` | `dotfiles` |

### Switching Logic

When the user selects a project from the InputSelector:

```lua
function switch_or_create(window, pane, path, name)
  window:perform_action(
    wezterm.action.SwitchToWorkspace {
      name = name,
      spawn = {
        cwd = path,
      },
    },
    pane
  )
end
```

`SwitchToWorkspace` handles both cases natively:
- If a workspace with `name` exists, it switches to it
- If not, it creates it with the shell started in `cwd = path`

### Workspace Name Conflicts

If two different projects produce the same workspace name (e.g.,
`github.com/org-a/utils` and `github.com/org-b/utils` both produce `utils`),
the user gets switched to whichever workspace was created first.

**Future enhancement**: Detect this case and use a longer name
(e.g., `org-a_utils` vs `org-b_utils`). For v1, the simple basename
approach is sufficient -- users can rename workspaces if needed.

## InputSelector Configuration

The InputSelector is configured with:

```lua
{
  title = opts.title or "Switch Project",
  fuzzy = opts.fuzzy ~= false,  -- default true
  choices = choices,  -- from discovery
  action = wezterm.action_callback(function(window, pane, id, label)
    if id then
      local name = derive_name(id)
      switch_or_create(window, pane, id, name)
    end
  end),
}
```

### Choice Format

Each project entry is converted to an InputSelector choice:

```lua
{
  label = entry.label,   -- e.g., "github.com/jorgengundersen/omni.wezterm"
  id = entry.id,         -- e.g., "/home/user/Repos/github.com/jorgengundersen/omni.wezterm"
}
```

### Sorting

Choices are sorted alphabetically by label. Active workspaces could
optionally be shown first or marked (future enhancement).

## Keybinding

The plugin registers a single keybinding via `apply_to_config`:

```lua
-- Default keybinding
table.insert(config.keys, {
  key = opts.key or 'p',
  mods = opts.mods or 'CTRL|SHIFT',
  action = wezterm.action_callback(function(window, pane)
    local cfg = load_config(opts.config_file)
    local entries = discover(cfg)
    local choices = build_choices(entries)
    window:perform_action(
      wezterm.action.InputSelector {
        title = opts.title or "Switch Project",
        fuzzy = opts.fuzzy ~= false,
        choices = choices,
        action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
          if id then
            local name = derive_name(id)
            switch_or_create(inner_window, inner_pane, id, name)
          end
        end),
      },
      pane
    )
  end),
})
```

### Ensuring `config.keys` Exists

The plugin must not overwrite existing key bindings:

```lua
if not config.keys then
  config.keys = {}
end
table.insert(config.keys, { ... })
```
