i want to replace my tmux sessionizer with a native wezterm approach.

i want this to be a plugin i add in my wezterm config. ("github.com/jorgengundersen/omni.wezterm")

see my current `tmp/....` tmux sessionizer script.

it does not need to be 100% replication of the workflow,
but it needs to have a similar functionality (optimized for wezterm).

plugin documentation:

https://wezterm.org/config/plugins.html

i want to improve the way it finds the "project directories" to populate
the project list.

i have a couple of directory structures that is important to me:

`$HOME/Repos/`

this has the following structure:

`../github.com/tietoevry/`: work related repos
`../github.com/jorgengundersen/`: personal repos
`../local/`: local repos not connected to any git forges

**Note:** I might have add different git forges in the future. it will following the same pattern.

i want any repository that is a git repository (containing `.git`) to be listed

`$HOME/te-files/`

this has these main categories:

0_Inbox/ - Temporary items awaiting organization
1_Projects/ - Actionable items with deadlines
2_Areas/ - Ongoing responsibilities and maintenance
3_Resources/ - Future reference materials
4_Archive/ - Inactive items from other categories
5_Zettel/ - Zettelkasten knowledge notes

te-files details:

`0_Inbox`: i want this to be an available option when choosing a session/project from list in wezterm

`1_Projects` has project directories. i want any project directory inside `1_Projects` to be listed (but not any child directories)

`2_Areas` has area directories. i want any project directory inside `2_Areas` to be listed (but not any child directories)

`3_Resouces`: This has any reasouces that is not a project or an area. the first level of sub directories is `{A..Z}`.
The next level of is sorted in the directory that has the same first letter. Example: Directory "Courses" is filed under `3_Resources/C/Courses`, etc.
These is the once I want listed

`4_Archive`: any subdirectory one level down to be listed

`5_Zettle`: i want this directory to be listed


`Repos/` and `te-files` are special cases. i also want to be able to specify specific directories i want listed (without any recursive walking).
If i want my dotfiles listed, I want to be able do specify `$HOME/dotfiles/`

I want this to be configurable in a config toml file in `$HOME/.config/omni` (or in my wezterm config if that is better).

i want this project to follow best pracises for lua (with typehints), wezterm plugins, and have a solid architecture that is easy to extend and to test.

I want the code to be built up by robust "lego bricks". These are primitives that do one thing, and one thing well. they are either pure function for basic logic, or wrappers around external dependencies.
these primitives should be the composable building blocks. what architecture you choose, is what ever is recommended for lua and wezterm plugins.

when it comes to testing, i want trophy testing model and black-box testing, to avoid any testing headaches when duing internal refactoring. be mindful of this when designing the tests.

when implementing, i want red/green TDD approach, conventional commits, changelog

can you create one or more specs in `specs/` with this requirements and descriptions in mind?

