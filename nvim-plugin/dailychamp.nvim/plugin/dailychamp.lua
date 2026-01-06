-- plugin/dailychamp.lua
-- Entry point for dailychamp.nvim plugin

-- Only load once
if vim.g.loaded_dailychamp then
  return
end
vim.g.loaded_dailychamp = 1

-- Load the main module
local dailychamp = require('dailychamp')

-- Create user commands
vim.api.nvim_create_user_command('DailyChampNewDay', function()
  dailychamp.insert_new_day()
end, { desc = 'Insert new day entry at top' })

vim.api.nvim_create_user_command('DailyChampNewDayHere', function()
  dailychamp.insert_new_day_at_cursor()
end, { desc = 'Insert new day entry at cursor' })

vim.api.nvim_create_user_command('DailyChampTask', function()
  dailychamp.insert_task()
end, { desc = 'Insert new task with prompt' })

vim.api.nvim_create_user_command('DailyChampQuickTask', function()
  dailychamp.quick_task()
end, { desc = 'Insert new task (quick, inline)' })

vim.api.nvim_create_user_command('DailyChampToggle', function()
  dailychamp.toggle_task()
end, { desc = 'Toggle task completion' })

vim.api.nvim_create_user_command('DailyChampSection', function()
  dailychamp.insert_section()
end, { desc = 'Insert new section' })

vim.api.nvim_create_user_command('DailyChampJumpToday', function()
  dailychamp.jump_to_today()
end, { desc = 'Jump to today\'s entry' })

vim.api.nvim_create_user_command('DailyChampJumpDate', function()
  dailychamp.jump_to_date()
end, { desc = 'Jump to specific date' })

vim.api.nvim_create_user_command('DailyChampCopyTask', function()
  dailychamp.copy_task_to_tomorrow()
end, { desc = 'Copy task to tomorrow' })

vim.api.nvim_create_user_command('DailyChampGoal', function()
  dailychamp.add_goal()
end, { desc = 'Add goal' })

vim.api.nvim_create_user_command('DailyChampNote', function()
  dailychamp.add_note()
end, { desc = 'Add note' })

vim.api.nvim_create_user_command('DailyChampStats', function()
  dailychamp.count_day_stats()
end, { desc = 'Show day statistics' })

vim.api.nvim_create_user_command('DailyChampOpen', function()
  dailychamp.open_file()
end, { desc = 'Open dailychamp/daily.md file' })

-- Setup default keybindings (only for dailychamp markdown files)
local function setup_keymaps()
  local leader = dailychamp.config.leader
  local opts = { buffer = true, silent = true }
  
  -- File operations
  vim.keymap.set('n', leader .. 'o', '<cmd>DailyChampOpen<cr>', vim.tbl_extend('force', opts, { desc = 'Open daily.md' }))
  
  -- Navigation
  vim.keymap.set('n', leader .. 't', '<cmd>DailyChampJumpToday<cr>', vim.tbl_extend('force', opts, { desc = 'Jump to today' }))
  vim.keymap.set('n', leader .. 'j', '<cmd>DailyChampJumpDate<cr>', vim.tbl_extend('force', opts, { desc = 'Jump to date' }))
  
  -- Day operations
  vim.keymap.set('n', leader .. 'n', '<cmd>DailyChampNewDay<cr>', vim.tbl_extend('force', opts, { desc = 'New day (top)' }))
  vim.keymap.set('n', leader .. 'N', '<cmd>DailyChampNewDayHere<cr>', vim.tbl_extend('force', opts, { desc = 'New day (cursor)' }))
  
  -- Task operations
  vim.keymap.set('n', leader .. 'a', '<cmd>DailyChampQuickTask<cr>', vim.tbl_extend('force', opts, { desc = 'Add task (quick)' }))
  vim.keymap.set('n', leader .. 'A', '<cmd>DailyChampTask<cr>', vim.tbl_extend('force', opts, { desc = 'Add task (prompt)' }))
  vim.keymap.set('n', leader .. 'x', '<cmd>DailyChampToggle<cr>', vim.tbl_extend('force', opts, { desc = 'Toggle task' }))
  vim.keymap.set('n', leader .. 'c', '<cmd>DailyChampCopyTask<cr>', vim.tbl_extend('force', opts, { desc = 'Copy task to tomorrow' }))
  
  -- Section operations
  vim.keymap.set('n', leader .. 's', '<cmd>DailyChampSection<cr>', vim.tbl_extend('force', opts, { desc = 'New section' }))
  vim.keymap.set('n', leader .. 'g', '<cmd>DailyChampGoal<cr>', vim.tbl_extend('force', opts, { desc = 'Add goal' }))
  vim.keymap.set('n', leader .. 'i', '<cmd>DailyChampNote<cr>', vim.tbl_extend('force', opts, { desc = 'Add note' }))
  
  -- Info
  vim.keymap.set('n', leader .. 'S', '<cmd>DailyChampStats<cr>', vim.tbl_extend('force', opts, { desc = 'Show stats' }))
end

-- Auto-setup keymaps only for dailychamp markdown files
-- Autocmd: Set filetype-specific settings and keybindings for daily.md
vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
  pattern = {"*/daily.md", "*/dailychamp/*.md"},
  callback = function()
    -- Setup keymaps (buffer-local)
    setup_keymaps()
    
    -- Set markdown filetype
    vim.bo.filetype = "markdown"
    
    -- Enable spell checking
    vim.wo.spell = true
    
    -- Set line wrapping
    vim.wo.wrap = true
    vim.wo.linebreak = true
    
    -- Folding by headers
    vim.wo.foldmethod = "expr"
    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.wo.foldlevel = 1 -- Start with day headers folded
    
    print("DailyChamp loaded - Use " .. dailychamp.config.leader .. " for commands")
  end,
})

-- Autocmd: Highlight tasks differently based on completion
vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
  pattern = {"*/daily.md", "*/dailychamp/*.md"},
  callback = function()
    -- Custom syntax highlighting for tasks
    vim.cmd([[
      syntax match DailyChampTaskIncomplete /^\s*- \[ \].*$/
      syntax match DailyChampTaskComplete /^\s*- \[[xX]\].*$/
      
      highlight DailyChampTaskIncomplete guifg=#7aa2f7 gui=none
      highlight DailyChampTaskComplete guifg=#565f89 gui=strikethrough
    ]])
  end,
})
