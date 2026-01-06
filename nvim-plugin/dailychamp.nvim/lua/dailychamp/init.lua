-- dailychamp.nvim
-- A Neovim plugin for managing daily task markdown files
-- Designed for use with DailyChamp App (Flutter)

local M = {}

-- Default configuration (easily customizable)
M.config = {
  -- Date format for day headers
  date_format = "%Y-%m-%d", -- 2026-01-06
  day_format = "%A",        -- Monday, Tuesday, etc.
  
  -- Template sections (customize order and names)
  sections = {
    "Goals",
    "Tasks", 
    "Notes",
    "Reflections"
  },
  
  -- Default task time estimate
  default_hours = "1.0",
  
  -- File paths (customize to your setup)
  file_path = vim.fn.expand("~/Nextcloud/Notes/dailychamp/daily.md"),
  
  -- Keybindings prefix (uses localleader for filetype-specific bindings)
  leader = "<localleader>",
}

-- Setup function to override defaults
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Helper: Get current date formatted
local function get_date_string()
  return os.date(M.config.date_format)
end

local function get_day_string()
  return os.date(M.config.day_format)
end

-- Helper: Get cursor position
local function get_cursor_pos()
  return vim.api.nvim_win_get_cursor(0)
end

-- Helper: Set cursor position
local function set_cursor_pos(row, col)
  vim.api.nvim_win_set_cursor(0, {row, col})
end

-- Helper: Insert lines at current position
local function insert_lines(lines)
  local row = get_cursor_pos()[1]
  vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, lines)
end

-- Helper: Append lines at end of buffer
local function append_lines(lines)
  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_buf_set_lines(0, line_count, line_count, false, lines)
end

-- Helper: Find line matching pattern
local function find_line(pattern)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      return i
    end
  end
  return nil
end

-- Template: New day entry
function M.new_day(date_override)
  local date = date_override or get_date_string()
  local day = get_day_string()
  
  local lines = {
    "# " .. date .. " " .. day,
    "",
  }
  
  -- Add configured sections
  for _, section in ipairs(M.config.sections) do
    table.insert(lines, "## " .. section)
    table.insert(lines, "")
  end
  
  table.insert(lines, "---")
  table.insert(lines, "")
  
  return lines
end

-- Command: Insert new day at top (newest first)
function M.insert_new_day()
  local lines = M.new_day()
  vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
  -- Move cursor to first section
  set_cursor_pos(3, 0) -- After first ## header
  print("Created new day entry for " .. get_date_string())
end

-- Command: Insert new day at cursor
function M.insert_new_day_at_cursor()
  local lines = M.new_day()
  insert_lines(lines)
  print("Inserted new day entry at cursor")
end

-- Template: New task (checkbox)
function M.new_task(title, hours)
  title = title or ""
  hours = hours or M.config.default_hours
  return "- [ ] " .. title .. " | " .. hours .. "h"
end

-- Command: Insert new task
function M.insert_task()
  vim.ui.input({ prompt = "Task title: " }, function(title)
    if not title or title == "" then return end
    
    vim.ui.input({ 
      prompt = "Estimated hours (" .. M.config.default_hours .. "): ",
      default = M.config.default_hours 
    }, function(hours)
      hours = (hours and hours ~= "") and hours or M.config.default_hours
      local task = M.new_task(title, hours)
      local row = get_cursor_pos()[1]
      vim.api.nvim_buf_set_lines(0, row, row, false, {task})
      set_cursor_pos(row + 1, 0)
      print("Added task: " .. title)
    end)
  end)
end

-- Command: Quick insert task (no prompts, enter inline)
function M.quick_task()
  local row = get_cursor_pos()[1]
  local task = M.new_task("", M.config.default_hours)
  vim.api.nvim_buf_set_lines(0, row, row, false, {task})
  -- Move cursor to title position (after "- [ ] ")
  set_cursor_pos(row + 1, 6)
  -- Enter insert mode
  vim.cmd("startinsert")
end

-- Command: Toggle task completion
function M.toggle_task()
  local row = get_cursor_pos()[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  
  if line:match("^%s*%- %[ %]") then
    -- Incomplete -> Complete
    local new_line = line:gsub("^(%s*%- )%[ %]", "%1[x]")
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, {new_line})
    print("Task completed ✓")
  elseif line:match("^%s*%- %[[xX]%]") then
    -- Complete -> Incomplete
    local new_line = line:gsub("^(%s*%- )%[[xX]%]", "%1[ ]")
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, {new_line})
    print("Task reopened")
  else
    print("Not a task line")
  end
end

-- Template: New section
function M.new_section(name)
  return {
    "## " .. name,
    ""
  }
end

-- Command: Insert new section
function M.insert_section()
  vim.ui.input({ prompt = "Section name: " }, function(name)
    if not name or name == "" then return end
    local lines = M.new_section(name)
    insert_lines(lines)
    print("Added section: " .. name)
  end)
end

-- Command: Jump to today's entry
function M.jump_to_today()
  local today = get_date_string()
  local pattern = "^# " .. today
  local line_num = find_line(pattern)
  
  if line_num then
    set_cursor_pos(line_num, 0)
    vim.cmd("normal! zz") -- Center screen
    print("Jumped to today: " .. today)
  else
    print("Today's entry not found. Create it with :DailyChampNewDay")
  end
end

-- Command: Jump to specific date
function M.jump_to_date()
  vim.ui.input({ 
    prompt = "Date (YYYY-MM-DD): ",
    default = get_date_string()
  }, function(date)
    if not date or date == "" then return end
    local pattern = "^# " .. date
    local line_num = find_line(pattern)
    
    if line_num then
      set_cursor_pos(line_num, 0)
      vim.cmd("normal! zz")
      print("Jumped to: " .. date)
    else
      print("Entry not found for: " .. date)
    end
  end)
end

-- Command: Copy task to tomorrow
function M.copy_task_to_tomorrow()
  local row = get_cursor_pos()[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  
  -- Check if it's a task
  if not line:match("^%s*%- %[[ xX]%]") then
    print("Not a task line")
    return
  end
  
  -- Extract task title and hours, make it incomplete
  local task = line:gsub("%- %[[xX]%]", "- [ ]")
  
  -- Find tomorrow's entry
  local tomorrow = os.date(M.config.date_format, os.time() + 86400) -- +1 day
  local pattern = "^# " .. tomorrow
  local line_num = find_line(pattern)
  
  if not line_num then
    print("Tomorrow's entry not found. Create it first!")
    return
  end
  
  -- Find Tasks section in tomorrow's entry
  local lines = vim.api.nvim_buf_get_lines(0, line_num, -1, false)
  local tasks_line = nil
  for i, l in ipairs(lines) do
    if l:match("^## [Tt]asks") then
      tasks_line = line_num + i
      break
    end
    -- Stop at next day separator
    if l:match("^%-%-%-") or l:match("^# %d") then
      break
    end
  end
  
  if tasks_line then
    vim.api.nvim_buf_set_lines(0, tasks_line, tasks_line, false, {task})
    print("Task copied to tomorrow")
  else
    print("Tasks section not found in tomorrow's entry")
  end
end

-- Command: Add goal
function M.add_goal()
  vim.ui.input({ prompt = "Goal: " }, function(goal)
    if not goal or goal == "" then return end
    local row = get_cursor_pos()[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, {"- " .. goal})
    set_cursor_pos(row + 1, 0)
    print("Added goal")
  end)
end

-- Command: Add note
function M.add_note()
  vim.ui.input({ prompt = "Note: " }, function(note)
    if not note or note == "" then return end
    local row = get_cursor_pos()[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, {"- " .. note})
    set_cursor_pos(row + 1, 0)
    print("Added note")
  end)
end

-- Command: Open dailychamp/daily.md file
function M.open_file()
  vim.cmd("edit " .. M.config.file_path)
end

-- Helper: Count tasks in current day
function M.count_day_stats()
  local row = get_cursor_pos()[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Find current day boundaries
  local day_start = nil
  local day_end = nil
  
  -- Find start (search backwards for # date)
  for i = row, 1, -1 do
    if lines[i]:match("^# %d%d%d%d%-%d%d%-%d%d") then
      day_start = i
      break
    end
  end
  
  -- Find end (search forwards for --- or next # date)
  for i = row, #lines do
    if lines[i]:match("^%-%-%-") or (i > row and lines[i]:match("^# %d%d%d%d%-%d%d%-%d%d")) then
      day_end = i
      break
    end
  end
  
  if not day_start then
    print("Not inside a day entry")
    return
  end
  
  day_end = day_end or #lines
  
  -- Count tasks
  local total = 0
  local completed = 0
  
  for i = day_start, day_end do
    if lines[i]:match("^%s*%- %[[ xX]%]") then
      total = total + 1
      if lines[i]:match("^%s*%- %[[xX]%]") then
        completed = completed + 1
      end
    end
  end
  
  local percentage = total > 0 and math.floor((completed / total) * 100) or 0
  print(string.format("Tasks: %d/%d completed (%d%%)", completed, total, percentage))
end

return M
