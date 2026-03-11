# Directory Discovery

## Summary

The directory discovery system is the core engine of omni.wezterm. It scans
configured directory structures using type-specific strategies and produces a
flat list of project entries for the UI to display.

## Concepts

### Project Entry

A project entry is the fundamental data type returned by all scanners:

```lua
---@class omni.ProjectEntry
---@field id string     -- absolute path to the directory
---@field label string  -- human-readable display label for InputSelector
```

### Scanner

A scanner is a pure function that takes a base path and returns a list of
`ProjectEntry` tables. Different directory structures require different
scanning strategies.

### Source

A source is a configuration entry that pairs a path with a scanner type.
The configuration file defines a list of sources.

## Scanner Types

### 1. `git_repos` -- Git Repository Scanner

Recursively walks a directory tree and returns any directory containing a
`.git` subdirectory. Stops descending into `.git` directories themselves.

**Use case**: `$HOME/Repos/`

**Behavior**:
- Walk the tree using `wezterm.run_child_process` with `find` to locate
  `.git` directories efficiently
- Return the parent of each `.git` directory as a project entry
- Do NOT descend into `.git` directories or their children
- Support configurable max depth (default: 5)

**Label format**: Path relative to the source base, e.g., `github.com/jorgengundersen/omni.wezterm`

**Example results for `$HOME/Repos/`**:
```
github.com/tietoevry/project-a
github.com/tietoevry/project-b
github.com/jorgengundersen/omni.wezterm
github.com/jorgengundersen/dotfiles
local/my-experiment
```

### 2. `children` -- Immediate Children Scanner

Lists immediate subdirectories of a given path (one level deep, no recursion).

**Use case**: `$HOME/te-files/1_Projects/`, `$HOME/te-files/2_Areas/`,
`$HOME/te-files/4_Archive/`

**Behavior**:
- Use `wezterm.read_dir` to list the directory
- Filter to directories only (exclude files)
- Return each child directory as a project entry

**Label format**: Directory basename, e.g., `my-project`

### 3. `grandchildren` -- Two-Level Children Scanner

Lists directories that are exactly two levels deep (skips the intermediate
grouping level).

**Use case**: `$HOME/te-files/3_Resources/` where structure is
`3_Resources/{A..Z}/{name}`

**Behavior**:
- Use `wezterm.read_dir` to list first-level children
- For each first-level child, use `wezterm.read_dir` to list second-level
  children
- Return the second-level directories as project entries

**Label format**: `{group}/{name}`, e.g., `C/Courses`

### 4. `self` -- Direct Path Entry

Returns the directory itself as a single project entry (no scanning).

**Use case**: `$HOME/te-files/0_Inbox/`, `$HOME/te-files/5_Zettel/`,
`$HOME/dotfiles/` -- any specific directory the user wants listed as-is.

**Behavior**:
- Validate the path exists and is a directory
- Return a single project entry for that path

**Label format**: Directory basename, e.g., `0_Inbox`

## Configuration

### TOML Config File

Location: `$HOME/.config/omni/config.toml`

```toml
# Git repository trees -- recursively find repos by .git presence
[[sources]]
path = "~/Repos"
type = "git_repos"
max_depth = 5

# PARA method directories
[[sources]]
path = "~/te-files/0_Inbox"
type = "self"

[[sources]]
path = "~/te-files/1_Projects"
type = "children"

[[sources]]
path = "~/te-files/2_Areas"
type = "children"

[[sources]]
path = "~/te-files/3_Resources"
type = "grandchildren"

[[sources]]
path = "~/te-files/4_Archive"
type = "children"

[[sources]]
path = "~/te-files/5_Zettel"
type = "self"

# Arbitrary additional directories
[[sources]]
path = "~/dotfiles"
type = "self"
```

### Configuration Schema

```lua
---@class omni.SourceConfig
---@field path string          -- base path (supports ~ expansion)
---@field type string          -- scanner type: "git_repos" | "children" | "grandchildren" | "self"
---@field max_depth? number    -- max depth for git_repos scanner (default: 5)

---@class omni.Config
---@field sources omni.SourceConfig[]
```

### Path Expansion

All paths in the configuration support `~` expansion to `$HOME`.
The expansion is done at config load time.

### Missing Paths

If a configured path does not exist, the scanner for that source silently
returns an empty list and logs a warning via `wezterm.log_warn`. This is
intentional -- the user may have paths that only exist on certain machines.

## Deduplication

If multiple sources produce the same absolute path, it should appear only once
in the final list. The first occurrence wins (preserving the order from config).

## Workspace Name Derivation

When a project is selected, the workspace name is derived from the directory
path. The workspace name must be safe for WezTerm (no special characters that
could cause issues).

**Algorithm**:
1. Take the directory basename
2. Replace `.` with `_` (matching the tmux-sessionizer behavior)
3. If a workspace with that name already exists at a *different* path,
   append a disambiguating suffix (e.g., the parent directory name)

## Performance Considerations

- `git_repos` scanning is the most expensive operation. It uses
  `wezterm.run_child_process` with `find` to avoid slow Lua-level recursion.
- Results could be cached in `wezterm.GLOBAL` with a TTL or manual refresh.
- The initial implementation should be correct first; caching can be added
  if performance is an issue.
