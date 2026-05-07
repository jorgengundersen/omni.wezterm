# Agent Instructions

This project uses **bd** (beads) v1 for issue tracking. Run `bd prime` for current workflow context.

## Quick Reference

```bash
bd prime             # Show current beads workflow context
bd ready             # Find available work
bd show <id>         # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>        # Complete work
bd dolt push         # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking

This project uses **bd (beads)** v1 for issue tracking.
Run `bd prime` for up-to-date workflow context, or install hooks with `bd hooks install` for auto-injection.

**Quick reference:**
- `bd ready --json` - Find unblocked work
- `bd create "Title" --type task --priority 2 --json` - Create an issue
- `bd update <id> --claim --json` - Claim work atomically
- `bd close <id> --reason "Completed" --json` - Complete work
- `bd dolt push` - Push beads data to the Dolt remote

**Rules:**
- Use bd for all task tracking; do not create markdown TODO lists.
- Use `--json` for programmatic commands.
- Link discovered work with `--deps discovered-from:<parent-id>`.
- Run `bd prime` when you need full workflow details.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt pull
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->
