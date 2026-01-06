# dailychamp.nvim

A Neovim plugin for managing daily task markdown files with the DailyChamp App (Flutter).

Provides powerful shortcuts, templates, and keybindings for efficient daily planning and task management in markdown format. Works seamlessly with semantic markdown parsing - tasks can appear anywhere in your document!

## Features

- **Quick task creation** with templates
- **Smart navigation** (jump to today, jump to date)
- **Task management** (toggle completion, copy to tomorrow)
- **Template generation** (new day, sections, goals, notes)
- **Statistics** (count completed/total tasks)
- **Fully customizable** keybindings and templates
- **Syntax highlighting** for completed/incomplete tasks
- **Auto-folding** by day headers

## Installation

### LazyVim / lazy.nvim

Add to your `~/.config/nvim/lua/plugins/dailychamp.lua`:

```lua
return {
  "your-username/dailychamp.nvim",
  ft = "markdown",
  config = function()
    require("dailychamp").setup({
      -- Optional: customize settings
      file_path = vim.fn.expand("~/Nextcloud/Notes/dailychamp/daily.md"),
      default_hours = "1.0",
    })
  end,
}
```

### Local Installation (for testing)

```bash
# Create local plugin directory
mkdir -p ~/.local/share/nvim/site/pack/plugins/start

# Symlink the plugin
ln -s /Users/gs/code/deliverists.io/dailychamp_app/nvim-plugin/dailychamp.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/dailychamp.nvim
```

Then restart Neovim.

## Default Keybindings

All keybindings use `<localleader>` prefix (filetype-specific, customizable):

### File Operations
| Key | Command | Description |
|-----|---------|-------------|
| `<localleader>o` | `:DailyChampOpen` | Open daily.md file |

### Navigation
| Key | Command | Description |
|-----|---------|-------------|
| `<localleader>t` | `:DailyChampJumpToday` | Jump to today's entry |
| `<localleader>j` | `:DailyChampJumpDate` | Jump to specific date (prompt) |

### Day Operations
| Key | Command | Description |
|-----|---------|-------------|
| `<localleader>n` | `:DailyChampNewDay` | Insert new day at top (newest first) |
| `<localleader>N` | `:DailyChampNewDayHere` | Insert new day at cursor |

### Task Operations
| Key | Command | Description |
|-----|---------|-------------|
| `<localleader>a` | `:DailyChampQuickTask` | Add task (quick, inline edit) |
| `<localleader>A` | `:DailyChampTask` | Add task (with prompts) |
| `<localleader>x` | `:DailyChampToggle` | Toggle task completion ([ ] ↔ [x]) |
| `<localleader>c` | `:DailyChampCopyTask` | Copy current task to tomorrow |

### Section Operations
| Key | Command | Description |
|-----|---------|-------------|
| `<localleader>s` | `:DailyChampSection` | Insert new section |
| `<localleader>g` | `:DailyChampGoal` | Add goal (list item) |
| `<localleader>i` | `:DailyChampNote` | Add note (list item) |

### Info
| Key | Command | Description |
|-----|---------|-------------|
| `<localleader>S` | `:DailyChampStats` | Show day statistics (X/Y completed) |

## Configuration

### Full Configuration Example

```lua
require("dailychamp").setup({
  -- Date formats (using os.date format strings)
  date_format = "%Y-%m-%d",  -- 2026-01-06
  day_format = "%A",         -- Monday
  
  -- Template sections (customize order and names)
  sections = {
    "Goals",
    "Tasks",
    "Notes", 
    "Reflections"
  },
  
  -- Default task time estimate
  default_hours = "1.0",
  
  -- File path (supports ~ expansion)
  file_path = vim.fn.expand("~/Nextcloud/Notes/dailychamp/daily.md"),
})
```

**Note:** Keybindings use `<localleader>` by default, which is filetype-specific and won't conflict with global mappings.

### Custom Keybindings

By default, keybindings use `<localleader>` which only works in dailychamp markdown files. To customize:

```lua
-- Change localleader globally (if not already set)
vim.g.maplocalleader = ","

-- Or use a different prefix entirely
require("dailychamp").setup({ leader = "<leader>d" })

-- Or set individual mappings after setup
local dailychamp = require("dailychamp")
vim.keymap.set('n', '<leader>tt', dailychamp.jump_to_today, { desc = 'Jump to today', buffer = true })
vim.keymap.set('n', '<leader>tn', dailychamp.insert_new_day, { desc = 'New day', buffer = true })
```

### Custom Sections

Change the default sections in new day templates:

```lua
require("dailychamp").setup({
  sections = {
    "Morning Routine",
    "Deep Work",
    "Tasks",
    "Evening Review"
  }
})
```

### Custom File Path

Point to a different markdown file:

```lua
require("dailychamp").setup({
  file_path = vim.fn.expand("~/Documents/daily.md"),
})
```

## Markdown Format

The plugin works with semantic markdown - tasks (`- [ ]`) are recognized **anywhere** in the document!

### Example Document

```markdown
# 2026-01-06 Tuesday

## Goals
- **Primary goal**: Complete the project
- Secondary goal with [link](https://example.com)

## Custom Section
- [ ] Task in custom section | 2.0h
- Regular note here

- [ ] Task without section header | 1.0h

Free paragraph text goes to reflections.

## Tasks
- [x] ~~Completed task~~ | 1.5h
- [ ] Task with **bold** and *italic* | 1.0h

## Reflections
End of day summary.

---

# 2026-01-05 Monday
...
```

### Task Format

```markdown
- [ ] Task title | 2.0h          # Incomplete task
- [x] Task title | 1.5h          # Completed task
- [ ] Task with [link](url) | 1h  # Task with markdown
```

The `| X.Xh` time estimate is optional. Default is `1.0h`.

## Commands Reference

All commands available via `:DailyChamp<Tab>`:

- `:DailyChampNewDay` - Insert new day entry at top
- `:DailyChampNewDayHere` - Insert new day entry at cursor
- `:DailyChampTask` - Insert task with prompts
- `:DailyChampQuickTask` - Insert task inline (fastest)
- `:DailyChampToggle` - Toggle task completion
- `:DailyChampSection` - Insert new section
- `:DailyChampJumpToday` - Jump to today's entry
- `:DailyChampJumpDate` - Jump to specific date
- `:DailyChampCopyTask` - Copy task to tomorrow
- `:DailyChampGoal` - Add goal
- `:DailyChampNote` - Add note
- `:DailyChampStats` - Show day statistics
- `:DailyChampOpen` - Open daily.md file

## Workflow Tips

### Daily Workflow

1. **Start your day**: `<localleader>o` to open daily.md
2. **Jump to today**: `<localleader>t`
3. **Add tasks quickly**: `<localleader>a` (opens inline)
4. **Mark complete**: `<localleader>x` on task line
5. **Check progress**: `<localleader>S`

### Creating New Day

The plugin creates days in **reverse chronological order** (newest first):

```bash
<localleader>n  # Inserts new day at top of file
```

Template automatically includes:
- Date header (`# 2026-01-06 Tuesday`)
- Configured sections
- Day separator (`---`)

### Copying Tasks Forward

Didn't finish a task today? Copy it to tomorrow:

1. Move cursor to task line
2. Press `<localleader>c`
3. Task copied to tomorrow's Tasks section (as incomplete)

### Custom Sections

Not limited to Goals/Tasks/Notes/Reflections! Create any section:

```bash
<localleader>s  # Prompts for section name
```

## Syntax Highlighting

The plugin automatically highlights tasks:

- **Incomplete tasks** (`- [ ]`) - Blue color
- **Completed tasks** (`- [x]`) - Gray with strikethrough

## Folding

Days are folded by headers for easy navigation:

- `zo` - Open fold
- `zc` - Close fold  
- `za` - Toggle fold
- `zR` - Open all folds
- `zM` - Close all folds

## Troubleshooting

### Plugin not loading

Check if it's in the right location:
```bash
ls -la ~/.local/share/nvim/site/pack/plugins/start/
```

### Keybindings not working

Check your localleader key:
```vim
:echo maplocalleader
```

Set it if undefined (typically in your init.lua):
```lua
vim.g.maplocalleader = ","  -- or any other key
```

Or change the plugin prefix:
```lua
require("dailychamp").setup({ leader = "<leader>d" })
```

### Commands not found

Restart Neovim after installation:
```bash
:qa
nvim
```

## Customization Examples

### Minimal Setup (defaults)

```lua
require("dailychamp").setup()
```

### Power User Setup

```lua
require("dailychamp").setup({
  file_path = vim.fn.expand("~/sync/daily.md"),
  leader = "<leader>t",  -- Use <leader>t for tasks
  default_hours = "0.5",  -- 30-minute default
  sections = {
    "🎯 Goals",
    "✅ Tasks",
    "📝 Notes",
    "💭 Reflections",
    "🔗 Links"
  },
})

-- Extra custom mappings (buffer-local)
local dailychamp = require("dailychamp")
vim.keymap.set('n', '<leader>tx', function()
  dailychamp.toggle_task()
  dailychamp.copy_task_to_tomorrow()
end, { desc = 'Complete & copy to tomorrow', buffer = true })
```

### Work/Personal Split

```lua
-- Two different files with separate configs
vim.keymap.set('n', '<leader>dw', function()
  require("dailychamp").setup({
    file_path = vim.fn.expand("~/work/daily.md"),
  })
  require("dailychamp").open_file()
end, { desc = 'Open work dailychamp' })

vim.keymap.set('n', '<leader>dp', function()
  require("dailychamp").setup({
    file_path = vim.fn.expand("~/personal/daily.md"),
  })
  require("dailychamp").open_file()
end, { desc = 'Open personal dailychamp' })
```

## Integration with DailyChamp App

This plugin is designed to work seamlessly with the DailyChamp App (Flutter):

1. Both use the same markdown format
2. Semantic parsing (tasks work anywhere)
3. Supports all markdown features (bold, links, code, etc.)
4. Reverse chronological order (newest first)
5. 7-task limit enforced in app (not in Neovim)

Edit in Neovim, view on your phone!

## License

MIT

## Contributing

The plugin is designed to be easily customizable. Feel free to:

1. Fork and modify for your needs
2. Submit PRs for improvements
3. Open issues for bugs/features

## Roadmap

Future enhancements being considered:

- Telescope integration for fuzzy date search
- Task templates (recurring tasks)
- Time tracking summaries
- Week view generation
- Export to other formats
- Integration with calendar apps

Contributions and ideas welcome!

## Author

Created for the DailyChamp App project.

## See Also

- DailyChamp App (Flutter) - Mobile/desktop task management
- LazyVim - Neovim configuration framework
