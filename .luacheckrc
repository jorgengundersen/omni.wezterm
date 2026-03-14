std = "lua54"
max_line_length = 120

globals = {
  "wezterm",
}

read_globals = {
  -- busted
  "describe",
  "it",
  "assert",
  "before_each",
  "after_each",
  "setup",
  "teardown",
  "pending",
  "spy",
  "stub",
  "mock",
}

exclude_files = {
  ".devenv/",
  ".beads/",
  "tmp/",
}
