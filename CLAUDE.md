# omni.wezterm — Development Conventions

WezTerm plugin that scans directories for projects and switches workspaces.
See `specs/` for detailed design rationale.

## Module Structure

```
lua/omni/
  init.lua            [orchestration] — wires config → discovery → UI → workspace
  config.lua          [primitive]     — loads/validates TOML config, returns data
  discovery.lua       [primitive]     — runs scanners, deduplicates, sorts (composed primitive)
  scanners/
    init.lua           — scanner registry
    git_repos.lua      — recursive .git finder
    children.lua       — immediate subdirectories
    grandchildren.lua  — two-level deep subdirectories
    self.lua           — single directory entry
  workspace.lua       [primitive]     — name derivation, workspace switching
  ui.lua              [primitive]     — InputSelector construction
  path.lua            [primitive]     — path expansion, basename, join
```

**Orchestration** modules decide flow and sequence work (`omni.init`).
**Primitive** modules do work and return output — no opinions on what happens next.
Keep them separate. `discovery` is a *composed primitive*: it combines scanner
results but doesn't decide what to do with them.

## ProjectEntry Contract

Every scanner returns `ProjectEntry[]`. Each entry has exactly 3 fields:

```lua
{ id = "/absolute/path",         -- used as cwd when creating workspace
  label = "contextual/display",  -- shown in InputSelector, used for fuzzy-find
  workspace_name = "label_with_dots_replaced" }  -- dots → underscores
```

## Error Handling

**Hard errors** — stop execution, surface immediately:
```lua
error("omni.wezterm: config error in source #3: unknown type 'foobar' (expected git_repos|children|grandchildren|self)")
```
Use for: invalid TOML, unknown scanner types, missing required fields, wrong field types.
Include: source index, field name, expected vs actual.

**Soft warnings** — log and skip, continue with remaining sources:
```lua
wezterm.log_warn("omni.wezterm: source #2 path does not exist, skipping")
```
Use for: missing paths, unresolvable env vars, empty scan results, child process failures.

## Adding a New Scanner

1. Create `lua/omni/scanners/{name}.lua`
2. Export `M.scan(source) -> ProjectEntry[]`
3. Register in `scanners/init.lua`
4. Add to valid types list in `config.lua` validation
5. Create `spec/omni/scanners/{name}_spec.lua`
6. Scanner must return entries with all 3 fields: `id`, `label`, `workspace_name`

## Naming Conventions

Use domain-oriented names, not technical ones:
- `discovery` not `scanner_orchestrator`
- `workspace` not `session_manager`
- `ProjectEntry` not `ScanResult`

## Testing

**Framework**: busted — run with `busted spec/`

**Approach**: black-box, trophy model
- Test public APIs and contracts, not internals
- Do: "given this input, module returns this output"
- Don't: "internal function `_walk_tree` is called with these args"

**Trophy model priority**: integration tests (bulk) > unit tests (pure functions) > E2E (manual)

**WezTerm stubs**: tests run outside WezTerm; use stubs from `spec/support/`

**Config tests**: use pre-parsed Lua tables, not TOML strings (avoids parser divergence)

**TDD cycle**: red (failing test) → green (minimum code) → refactor → commit

## Commits

Conventional Commits format:
```
feat(scanners): add children scanner
test(scanners): add tests for children scanner
fix(config): validate max_depth is positive integer
```

## Tools

- `luacheck lua/ spec/` — lint
- `stylua --check lua/ spec/` — format check
- `busted spec/` — tests
