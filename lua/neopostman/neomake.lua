local M = {}

local Snacks = require("snacks")
local U = require("neopostman.utils.utils")

---@class Neomake
M.Neomake = {}

function M.Neomake:init()
  vim.api.nvim_create_user_command("Neomake", function() self:run() end, {})
end

-- Extract make commands from Makefile
function M.Neomake:parse_make_headers()
  local makefile_path = self:get_make_path()
  if not makefile_path then
    vim.api.nvim_err_writeln("No Makefile found in the current directory.")
    return {}
  end

  local commands = {}
  local makefile_content = vim.fn.readfile(makefile_path)
  for _, line in ipairs(makefile_content) do
    -- Match target names at start of line before colon, ignoring comments and empty lines
    local target = line:match("^([%w%-%_]+):")
    if target and target ~= "" then
      table.insert(commands, target)
    end
  end

  return commands
end

function M.Neomake:get_make_path()
  local makefile_path = vim.fn.getcwd() .. "/Makefile"
  if vim.fn.filereadable(makefile_path) == 1 then
    return makefile_path
  else
    return nil
  end
end

-- Run a command inside a tmux split at bottom
function M.Neomake:run_in_tmux(cmd)
  -- Make sure tmux is running and inside tmux session
  -- Create horizontal split at bottom with 15 lines height and run the command
  local tmux_cmd = string.format(
    "tmux split-window -v -l 15 '%s'",
    cmd:gsub("'", "'\\''") -- escape single quotes inside cmd
  )
  -- Run shell command asynchronously, no need to wait
  vim.fn.system(tmux_cmd)
end

function M.Neomake:run()
  local commands = self:parse_make_headers()
  if #commands == 0 then
    vim.api.nvim_err_writeln("No make targets found in Makefile")
    return
  end

  local items = {}
  for _, cmd in ipairs(commands) do
    table.insert(items, { label = cmd, text = cmd })
  end

  Snacks.picker.pick("custom", {
    -- prompt = "Make:",
    layout = {
      preset = "ivy_split",
    },
    items = items,
    confirm = function(picker, selected)
      picker:close()
      if selected and selected.label then
        self:run_in_tmux("make " .. selected.label)
      end
    end,
  })
end

return M
