local M = {}

local Snacks = require("snacks")
local U = require("neopostman.utils.utils")

---@class Neomake
M.Neomake = {}

function M.Neomake:init()
  vim.api.nvim_create_user_command("Neomake", function() self:run() end, {})
end

function M.Neomake:run_in_nvim_terminal(cmd)
  -- Iterate over all buffers to find a terminal buffer
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
      if buftype == "terminal" then
        -- Get terminal job id associated with the buffer
        local term_job_id = vim.b[buf].terminal_job_id
        if term_job_id and term_job_id > 0 then
          -- Send the command to this terminal
          vim.api.nvim_chan_send(term_job_id, cmd .. "\n")
          -- Switch to the terminal buffer window to show output (optional)
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == buf then
              vim.api.nvim_set_current_win(win)
              return
            end
          end
          -- If terminal buffer exists but no window found, open a split for it
          vim.cmd("botright split")
          vim.api.nvim_set_current_buf(buf)
          return
        end
      end
    end
  end

  -- No terminal buffer found: open a new one and run the command
  vim.cmd("botright split | terminal")
  local term_buf = vim.api.nvim_get_current_buf()
  local term_job_id = vim.b[term_buf].terminal_job_id
  if term_job_id and term_job_id > 0 then
    vim.api.nvim_chan_send(term_job_id, cmd .. "\n")
  end
end

function M.Neomake:run()
  local commands = self:parse_make_headers()
  if #commands == 0 then
    vim.api.nvim_err_writeln("No make targets found in Makefile")
    return
  end

  local items = {}
  for _, cmd in ipairs(commands) do
    table.insert(items, { label = cmd, text = cmd, file = "Makefile" })
  end

  local launched_from_term = self:launched_with_terminal()

  Snacks.picker.pick("custom", {
    layout = {
      preset = launched_from_term and "vscode" or "ivy",
    },
    items = items,
    confirm = function(picker, selected)
      picker:close()
      if selected and selected.label then
        local make_cmd = "make " .. selected.label
        if launched_from_term then
          self:run_in_nvim_terminal(make_cmd)
        else
          self:run_in_tmux(make_cmd)
        end
      end
    end,
    preview = "file",
  })
end

function M.Neomake:launched_with_terminal()
  local argv = vim.v.argv or {}
  for _, arg in ipairs(argv) do
    if arg == "+terminal" then
      return true
    end
  end
  return false
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

function M.Neomake:run_in_tmux(cmd)
  local keep_open_cmd = string.format("%s; echo 'Press any key to close...'; read", cmd)
  local tmux_cmd = string.format("tmux split-window -v -l 15 '%s'", keep_open_cmd:gsub("'", "'\\''"))
  vim.fn.system(tmux_cmd)
end

return M
