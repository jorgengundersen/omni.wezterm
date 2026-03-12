# Directory Discovery

## Summary

The directory discovery system is the core engine of omni.wezterm. It scans
configured directory structures using type-specific strategies and produces a
flat list of project entries for the UI to display.

## Concepts

### Project Entry

A project entry is the fundamental data type returned by all scanners.
It carries three distinct pieces of information:

```lua
---@class omni.ProjectEntry
---@field id string             -- absolute path to the directory (used as cwd)
---@field label string          -- contextual display label for InputSelector
---@field workspace_name string -- sanitized workspace identity (unique, derived from label)
```

- **`id`**: The absolute path on disk. Used as `cwd` when creating a workspace.
  Example: `/home/user/Repos/github.com/jorgengundersen/omni.wezterm`
- **`label`**: The contextual path shown in the InputSelector and used for
  fuzzy-finding. Preserves dots, slashes, and original casing.
  Example: `github.com/jorgengundersen/omni.wezterm`
- **`workspace_name`**: Derived from `label` by replacing dots with underscores.
  Used as the WezTerm workspace identity. Must be unique across all entries.
  Example: `github_com/jorgengundersen/omni_wezterm`

### Scanner

A scanner is a pure function that takes a source config and returns a list of
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
- On Linux/macOS: use `wezterm.run_child_process` with `find` to locate
  `.git` directories efficiently
- On Windows: use a Lua-native recursive walk via `wezterm.read_dir` (no
  shell-out, since `find` is not available or behaves differently)
- Return the parent of each `.git` directory as a project entry
- Do NOT descend into `.git` directories or their children
- Support configurable max depth (default: 5)
- If `wezterm.run_child_process` fails (non-zero exit, command not found),
  log via `wezterm.log_warn` with the exit code and stderr, and return
  an empty list for this source

**Label derivation**: Path relative to the source base.

**Workspace name derivation**: Label with dots replaced by underscores.

**Example results for source path `~/Repos`**:

| Directory | `id` | `label` | `workspace_name` |
|---|---|---|---|
| `~/Repos/github.com/tietoevry/project-a` | `/home/user/Repos/github.com/tietoevry/project-a` | `github.com/tietoevry/project-a` | `github_com/tietoevry/project-a` |
| `~/Repos/github.com/jorgengundersen/omni.wezterm` | `/home/user/Repos/github.com/jorgengundersen/omni.wezterm` | `github.com/jorgengundersen/omni.wezterm` | `github_com/jorgengundersen/omni_wezterm` |
| `~/Repos/local/my-experiment` | `/home/user/Repos/local/my-experiment` | `local/my-experiment` | `local/my-experiment` |

### 2. `children` -- Immediate Children Scanner

Lists immediate subdirectories of a given path (one level deep, no recursion).

**Use case**: `$HOME/te-files/1_Projects/`, `$HOME/te-files/2_Areas/`,
`$HOME/te-files/4_Archive/`

**Behavior**:
- Use `wezterm.read_dir` to list the directory
- Filter to directories only (exclude files)
- Return each child directory as a project entry

**Label derivation**: `{source_basename}/{child_basename}`.

**Workspace name derivation**: Label with dots replaced by underscores.

**Example results for source path `~/te-files/1_Projects`**:

| Directory | `id` | `label` | `workspace_name` |
|---|---|---|---|
| `~/te-files/1_Projects/My-Project` | `/home/user/te-files/1_Projects/My-Project` | `1_Projects/My-Project` | `1_Projects/My-Project` |
| `~/te-files/1_Projects/other-work` | `/home/user/te-files/1_Projects/other-work` | `1_Projects/other-work` | `1_Projects/other-work` |

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

**Label derivation**: `{source_basename}/{group}/{name}`.

**Workspace name derivation**: Label with dots replaced by underscores.

**Example results for source path `~/te-files/3_Resources`**:

| Directory | `id` | `label` | `workspace_name` |
|---|---|---|---|
| `~/te-files/3_Resources/C/Courses` | `/home/user/te-files/3_Resources/C/Courses` | `3_Resources/C/Courses` | `3_Resources/C/Courses` |
| `~/te-files/3_Resources/P/Photography` | `/home/user/te-files/3_Resources/P/Photography` | `3_Resources/P/Photography` | `3_Resources/P/Photography` |

### 4. `self` -- Direct Path Entry

Returns the directory itself as a single project entry (no scanning).

**Use case**: `$HOME/te-files/0_Inbox/`, `$HOME/te-files/5_Zettel/`,
`$HOME/dotfiles/` -- any specific directory the user wants listed as-is.

**Behavior**:
- Validate the path exists and is a directory
- Return a single project entry for that path

**Label derivation**: Directory basename.

**Workspace name derivation**: Label with dots replaced by underscores.

**Example results**:

| Source path | `id` | `label` | `workspace_name` |
|---|---|---|---|
| `~/te-files/0_Inbox` | `/home/user/te-files/0_Inbox` | `0_Inbox` | `0_Inbox` |
| `~/dotfiles` | `/home/user/dotfiles` | `dotfiles` | `dotfiles` |

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
---@field path string          -- base path (supports ~ and $VAR expansion)
---@field type string          -- scanner type: "git_repos" | "children" | "grandchildren" | "self"
---@field max_depth? number    -- max depth for git_repos scanner (default: 5)

---@class omni.Config
---@field sources omni.SourceConfig[]
```

### Path Expansion

All paths in the configuration support:
- `~` expansion to `$HOME`
- `$VAR` and `${VAR}` environment variable expansion

Expansion is done at config load time.

If an environment variable does not resolve, the source is skipped with a
`wezterm.log_warn` message (e.g., `"omni.wezterm: unresolved env var $FOO
in source #2 path, skipping"`). This supports multi-machine configs where
some environment variables may only exist on certain systems.

### Missing Paths

If a configured path does not exist after expansion, the scanner for that
source returns an empty list and logs a warning via `wezterm.log_warn`.
This is intentional -- the user may have paths that only exist on certain
machines.

## Deduplication

If multiple sources produce the same absolute path (`id`), it should appear
only once in the final list. The first occurrence wins (preserving the order
from config).

## Sorting

The final list of project entries is sorted by `label` using case-sensitive
ASCII string comparison (standard Lua `<` operator). This means uppercase
letters sort before lowercase (e.g., `0_Inbox` before `dotfiles`).

## Workspace Name Derivation

The workspace name is derived from the `label` field, NOT from the absolute
path. This ensures workspace names carry contextual information about where
the project comes from.

**Algorithm**:
1. Start with the `label` (contextual path produced by the scanner)
2. Replace `.` with `_` (matching the tmux-sessionizer convention for dots)
3. The result is the `workspace_name`

This approach eliminates name collisions by construction: two entries can
only have the same `workspace_name` if they have the same `label`, which
means they represent the same relative path from the same source type.

**Examples**:

| Scanner | Label | Workspace Name |
|---|---|---|
| `git_repos` | `github.com/jorgengundersen/omni.wezterm` | `github_com/jorgengundersen/omni_wezterm` |
| `git_repos` | `local/my-experiment` | `local/my-experiment` |
| `children` | `1_Projects/My-Project` | `1_Projects/My-Project` |
| `grandchildren` | `3_Resources/C/Courses` | `3_Resources/C/Courses` |
| `self` | `0_Inbox` | `0_Inbox` |
| `self` | `dotfiles` | `dotfiles` |

## Performance Considerations

- `git_repos` scanning is the most expensive operation. On Linux/macOS it
  uses `wezterm.run_child_process` with `find` to avoid slow Lua-level
  recursion. On Windows it falls back to Lua-native recursive walking via
  `wezterm.read_dir`.
- No caching in v1. If performance is an issue, caching can be added later
  using `wezterm.GLOBAL` with a TTL-based invalidation strategy.
