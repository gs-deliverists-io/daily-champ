# QUICKSTART.md - DailyChamp Plugin for Neovim

## Installation (5 seconds)

For LazyVim, create `~/.config/nvim/lua/plugins/dailychamp.lua`:

```lua
return {
  dir = "~/code/deliverists.io/dailychamp_app/nvim-plugin/dailychamp.nvim",
  ft = "markdown",
  config = function()
    require("dailychamp").setup()
  end,
}
```

Restart Neovim.

## Quick Start (60 seconds)

1. **Open your daily.md file:**

   ```
   <leader>do
   ```

2. **Create new day (at top):**

   ```
   <leader>dn
   ```

   This creates:

   ```markdown
   # 2026-01-06 Tuesday
   
   ## Goals
   
   ## Tasks
   
   ## Notes
   
   ## Reflections
   
   ---
   ```

3. **Add a task (quick method):**

   ```
   <leader>da
   ```

   This inserts `- [ ]  | 1.0h` and puts you in insert mode to type the title.

4. **Toggle task completion:**

   ```
   <leader>dx
   ```

   Changes `- [ ]` to `- [x]` (and vice versa).

5. **Jump to today:**

   ```
   <leader>dt
   ```

## Most Useful Keybindings

| Key | Action |
|-----|--------|
| `<leader>do` | Open daily.md |
| `<leader>dt` | Jump to today |
| `<leader>dn` | New day (top) |
| `<leader>da` | Quick add task |
| `<leader>dx` | Toggle task complete |
| `<leader>dc` | Copy task to tomorrow |
| `<leader>dS` | Show stats |

## Customize

Edit sections in your config:

```lua
require("dailychamp").setup({
  sections = {
    "🎯 Goals",
    "✅ Tasks",
    "📝 Notes",
    "💭 Reflections"
  },
  default_hours = "0.5",  -- 30 min default
})
```

## Full Documentation

See [README.md](./README.md) for complete features and customization options.
