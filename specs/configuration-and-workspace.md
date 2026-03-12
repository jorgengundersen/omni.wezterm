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
# All paths support ~ expansion and $VAR / ${VAR} environment variables

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
   and log a `wezterm.log_info` message -- this is not an error
3. Parse TOML via `wezterm.serde.toml_decode`
   - **Fail-fast**: If the file exists but has TOML syntax errors, log the
     parse error via `wezterm.log_error`, show a toast notification with
     the error, and abort (do not open the selector)
4. Validate each source entry:
   - `path` is required and must be a string -- **fail-fast** if missing
     or wrong type
   - `type` is required and must be one of: `git_repos`, `children`,
     `grandchildren`, `self` -- **fail-fast** if missing or unknown
   - `max_depth` is optional (only relevant for `git_repos`), defaults to 5
   - Validation errors include the source index and field name in the
     error message
5. Expand `~` and `$VAR` / `${VAR}` in all paths
   - If an environment variable does not resolve, **warn** and skip that
     source (do not fail the entire config)
6. Return the validated config

### Error Surfacing

Config errors (TOML parse failures, validation failures) are surfaced via:
1. `wezterm.log_error` with a detailed message
2. A WezTerm toast notification (`window:toast_notification`) so the user
   sees it immediately without needing to open the debug overlay

Example messages:
- `"omni.wezterm: failed to parse config at ~/.config/omni/config.toml: invalid TOML at line 12"`
- `"omni.wezterm: config error in source #3: missing required field 'type'"`
- `"omni.wezterm: config error in source #5: unknown type 'foobar' (expected git_repos|children|grandchildren|self)"`

### Config Reload

The TOML config is read on every invocation of the project selector (each
keypress). This means changes to the config file take effect on the next
selector invocation without restarting WezTerm.

If WezTerm config reload is triggered, `wezterm.add_to_config_reload_watch_list`
can be used to watch the TOML file for changes too.

## Workspace Management

### Name Derivation

The workspace name is derived from the project entry's `label` field, not
from the absolute path. This ensures workspace names carry contextual
information about where the project comes from.

```lua
---@param label string  Contextual label from the scanner
---@return string       Workspace name
function derive_name(label)
  -- Replace dots with underscores (matching tmux-sessionizer convention)
  return label:gsub("%.", "_")
end
```

Examples:
| Label | Workspace Name |
|---|---|
| `github.com/jorgengundersen/omni.wezterm` | `github_com/jorgengundersen/omni_wezterm` |
| `local/my-experiment` | `local/my-experiment` |
| `1_Projects/My-Project` | `1_Projects/My-Project` |
| `3_Resources/C/Courses` | `3_Resources/C/Courses` |
| `0_Inbox` | `0_Inbox` |
| `dotfiles` | `dotfiles` |

This approach eliminates name collisions by construction. Two entries can
only have the same workspace name if they have the same label, which means
they represent the same relative path from the same source type.

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

### Cancellation Behavior

When the user presses Escape or otherwise cancels the InputSelector, the
callback receives `nil` for both `id` and `label`. The plugin does nothing
in this case -- no workspace switch, no error, no log message. This is
intentional and expected.

```lua
action = wezterm.action_callback(function(window, pane, id, label)
  if not id then
    return  -- User cancelled, do nothing
  end
  -- ... proceed with workspace switch
end)
```

## InputSelector Configuration

The InputSelector is configured with:

```lua
{
  title = opts.title or "Switch Project",
  fuzzy = opts.fuzzy ~= false,  -- default true
  choices = choices,  -- from discovery
  action = wezterm.action_callback(function(window, pane, id, label)
    if not id then
      return  -- User cancelled
    end
    -- id contains the workspace_name, label contains the display label
    -- We need to look up the absolute path from the original entries
    local entry = entries_by_workspace_name[id]
    if entry then
      switch_or_create(window, pane, entry.id, entry.workspace_name)
    end
  end),
}
```

### Choice Format

Each project entry is converted to an InputSelector choice:

```lua
{
  label = entry.label,            -- e.g., "github.com/jorgengundersen/omni.wezterm"
  id = entry.workspace_name,      -- e.g., "github_com/jorgengundersen/omni_wezterm"
}
```

The `label` is what the user sees and fuzzy-finds against. The `id` is the
workspace name used for `SwitchToWorkspace`. The absolute path (`entry.id`)
is looked up from the original entry list when a selection is made.

### Sorting

Choices are sorted by `label` using case-sensitive ASCII string comparison
(standard Lua `<` operator). This means uppercase letters sort before
lowercase (e.g., `0_Inbox` before `dotfiles`, `3_Resources/C/Courses`
before `github.com/...`).

## Active Workspace Listing

### Goal

Provide a fast "show active sessions" action equivalent to tmux `<prefix+s>`.
In WezTerm terms, this means listing active workspaces and switching to one.

### Data Source

The plugin reads active workspace names from WezTerm's multiplexer API:

```lua
local mux = wezterm.mux
local workspaces = mux.get_workspace_names()
```

Behavior requirements:
- Treat returned names as the source of truth for active workspaces
- Sort names alphabetically (case-sensitive ASCII) for stable ordering

### Selector Behavior

The active workspace selector uses `InputSelector` with:

```lua
{
  title = opts.active_title or "Switch Workspace",
  fuzzy = opts.active_fuzzy ~= false,  -- default true
  choices = {
    { label = "github_com/jorgengundersen/omni_wezterm", id = "github_com/jorgengundersen/omni_wezterm" },
    { label = "dotfiles", id = "dotfiles" },
  },
  action = wezterm.action_callback(function(window, pane, id, label)
    if not id then
      return  -- User cancelled
    end
    window:perform_action(
      wezterm.action.SwitchToWorkspace {
        name = id,
      },
      pane
    )
  end),
}
```

### No Workspaces Case

If `mux.get_workspace_names()` returns an empty list:
- Do not open an empty selector
- Log `wezterm.log_info("No active workspaces")`
- Return early without error

### Relationship to Project Selector

- Project selector (`CTRL+SHIFT+P` by default) remains focused on discovered
  project directories and may create new workspaces
- Active workspace selector (`CTRL+SHIFT+S` by default) lists only existing
  workspaces and never creates new ones

## Keybinding

The plugin registers two keybindings via `apply_to_config`:

```lua
-- Guard against double registration
if config._omni_applied then
  wezterm.log_warn("omni.wezterm: apply_to_config called more than once, skipping")
  return
end
config._omni_applied = true

-- Ensure config.keys exists
if not config.keys then
  config.keys = {}
end

-- Default project selector keybinding
table.insert(config.keys, {
  key = opts.key or 'p',
  mods = opts.mods or 'CTRL|SHIFT',
  action = wezterm.action_callback(function(window, pane)
    local ok, cfg = pcall(load_config, opts.config_file)
    if not ok then
      -- cfg contains the error message
      wezterm.log_error("omni.wezterm: " .. tostring(cfg))
      window:toast_notification("omni.wezterm", tostring(cfg), nil, 4000)
      return
    end

    local entries = discover(cfg)
    local choices = build_choices(entries)

    -- Build lookup table for absolute paths
    local entry_lookup = {}
    for _, entry in ipairs(entries) do
      entry_lookup[entry.workspace_name] = entry
    end

    window:perform_action(
      wezterm.action.InputSelector {
        title = opts.title or "Switch Project",
        fuzzy = opts.fuzzy ~= false,
        choices = choices,
        action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
          if not id then
            return  -- User cancelled
          end
          local entry = entry_lookup[id]
          if entry then
            switch_or_create(inner_window, inner_pane, entry.id, entry.workspace_name)
          end
        end),
      },
      pane
    )
  end),
})

-- Default active workspace selector keybinding
table.insert(config.keys, {
  key = opts.active_key or 's',
  mods = opts.active_mods or 'CTRL|SHIFT',
  action = wezterm.action_callback(function(window, pane)
    local names = wezterm.mux.get_workspace_names()
    if #names == 0 then
      wezterm.log_info('No active workspaces')
      return
    end

    table.sort(names)

    local choices = {}
    for _, name in ipairs(names) do
      table.insert(choices, { label = name, id = name })
    end

    window:perform_action(
      wezterm.action.InputSelector {
        title = opts.active_title or 'Switch Workspace',
        fuzzy = opts.active_fuzzy ~= false,
        choices = choices,
        action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
          if not id then
            return  -- User cancelled
          end
          inner_window:perform_action(
            wezterm.action.SwitchToWorkspace { name = id },
            inner_pane
          )
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

### Limitation: Default Key Table Only

This plugin registers keybindings in `config.keys` (the default key table).
Users who use WezTerm's `key_tables` for modal keybindings will need to
manually register the plugin's actions in their key tables. The
`action_callback` functions could be exposed as a future API for this use
case.
