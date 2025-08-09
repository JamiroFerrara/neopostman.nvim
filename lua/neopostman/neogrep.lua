--TOOO:
-- Add a spinner while running the command
-- Split panes
-- Global grep (home)
-- Fuzzy search?
-- Enable / Disable Preview with config file
-- Hidden files
local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")
local A = require("neopostman.neoawk").NeoAwk

---@diagnostic disable: undefined-field
local help = require("neopostman.traits.help")
local toggleable = require("neopostman.traits.toggleable")

---@class Layout
M.Neogrep = {}

function M.Neogrep:init()
  vim.api.nvim_create_user_command("Neogrep", function() self:run() end, {})
  vim.api.nvim_create_user_command("NeogrepWord", function() M.Neogrep:grep_under_cursor() end, {})
  vim.api.nvim_create_user_command("NeogrepBuffer", function() M.Neogrep:grep_current_buffer() end, {})
  vim.api.nvim_create_user_command("NeogrepWordInBuffer", function() M.Neogrep:grep_word_in_current_buffer() end, {})

  --TODO: Move me out to NeoAwk module
  vim.api.nvim_create_user_command("FilterBuffer", function()
    A.filter_buffer_lines_with_awk(vim.api.nvim_get_current_buf(), vim.fn.input("Find lines: "))
  end, {})

  self.split1 = Split({ position = "bottom", size = "20%", enter = true })

  self.split1:on("CursorMoved", function()
    U.highlight_current_line(self.split1.bufnr, "Error", self._active_ns, ":", 3)
    self:open_file()
  end)

  self.split1:on("WinClosed", function()
    if self.preview_bufnr and self._highlight_ns then
      vim.api.nvim_buf_clear_namespace(self.preview_bufnr, self._highlight_ns, 0, -1)
    end
  end)

  self.split1:on("BufEnter", function()
    vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 0 })
  end)

  --Traits
  toggleable(self, { self.split1 }, false)

  self:init_mappings()
end

function M.Neogrep:run()
  -- Save origin buffer and window
  self.origin_bufnr = vim.api.nvim_get_current_buf()
  self.origin_winid = vim.api.nvim_get_current_win()

  self:open()

  local res = vim.fn.input("Grep: ")
  local content = U.run("rg --vimgrep -i " .. vim.fn.shellescape(res))
  U.put_text(self.split1.bufnr, content)

  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
end

function M.Neogrep:confirm_open_file(split_type)
  -- Hide the split
  self.split1:hide()

  -- Clear highlight in the preview buffer if it exists
  if self.preview_bufnr and self._highlight_ns then
    vim.api.nvim_buf_clear_namespace(self.preview_bufnr, self._highlight_ns, 0, -1)
  end

  local line = vim.api.nvim_get_current_line()
  local file, lnum, col = line:match("^(.-):(%d+):(%d+):")
  if not file then
    return
  end

  lnum = tonumber(lnum)
  col = tonumber(col)

  -- Save origin buffer if modified
  if vim.api.nvim_buf_get_option(self.origin_bufnr, "modifiable") and vim.api.nvim_buf_get_option(self.origin_bufnr, "modified") then
    vim.api.nvim_buf_call(self.origin_bufnr, function()
      vim.cmd("write")
    end)
  end

  vim.api.nvim_set_current_win(self.origin_winid)

  if split_type == "vsplit" then
    vim.cmd("vsplit " .. vim.fn.fnameescape(file))
  elseif split_type == "split" then
    vim.cmd("split " .. vim.fn.fnameescape(file))
  else
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  end

  vim.cmd("filetype detect")
  vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
end

function M.Neogrep:init_mappings()
  help(self, self.split1, {
    { "n", "<cr>", function() self:confirm_open_file() end, "Open file under cursor" },
    { "n", "<M-n>", function() self:next() end, "Next result" },
    { "n", "<C-n>", function() self:next() end, "Next result" },

    -- New mappings
    { "n", "s", function() self:confirm_open_file("vsplit") end, "Open in vertical split" },
    { "n", "S", function() self:confirm_open_file("split") end, "Open in horizontal split" },
  })
end

function M.Neogrep:open_file()
  local cursor_line = vim.api.nvim_win_get_cursor(self.split1.winid)[1]

  if self.last_cursor_line == cursor_line then
    return
  end
  self.last_cursor_line = cursor_line

  local line = vim.api.nvim_buf_get_lines(self.split1.bufnr, cursor_line - 1, cursor_line, false)[1]
  local file, lnum, col = line:match("^(.-):(%d+):(%d+):")
  if not file then
    return
  end

  lnum = tonumber(lnum)
  col = tonumber(col)

  -- Save origin buffer if modified
  if vim.api.nvim_buf_get_option(self.origin_bufnr, "modifiable") and vim.api.nvim_buf_get_option(self.origin_bufnr, "modified") then
    vim.api.nvim_buf_call(self.origin_bufnr, function()
      vim.cmd("write")
    end)
  end

  local current_win = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(self.origin_winid)
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  vim.cmd("filetype detect")

  self.preview_bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })

  -- Use a dedicated namespace for highlights (or create one)
  if not self._highlight_ns then
    self._highlight_ns = vim.api.nvim_create_namespace("NeogrepPreviewHighlight")
  end

  -- Highlight the entire line visually in the preview buffer
  vim.api.nvim_buf_clear_namespace(self.preview_bufnr, self._highlight_ns, 0, -1)
  vim.api.nvim_buf_add_highlight(self.preview_bufnr, self._highlight_ns, "Visual", lnum - 1, 0, -1)

  vim.api.nvim_set_current_win(current_win)
end

function M.Neogrep:grep_under_cursor()
  -- Get the word under the cursor in the current window
  local word = vim.fn.expand("<cword>")
  if word == "" then
    print("No word under cursor")
    return
  end

  -- Save origin buffer and window
  self.origin_bufnr = vim.api.nvim_get_current_buf()
  self.origin_winid = vim.api.nvim_get_current_win()

  self:open()

  -- Run ripgrep with the word under the cursor
  local content = U.run("rg --vimgrep " .. vim.fn.shellescape(word))
  U.put_text(self.split1.bufnr, content)
  self.last_cursor_line = nil -- reset so open_file will run
  self:open_file()
end

function M.Neogrep:grep_current_buffer()
  local filepath = vim.fn.expand("%:p")
  if filepath == "" then
    print("Cannot determine current file path.")
    return
  end

  -- Save origin buffer and window
  self.origin_bufnr = vim.api.nvim_get_current_buf()
  self.origin_winid = vim.api.nvim_get_current_win()

  self:open()

  -- Ask the user for a search query
  local res = vim.fn.input("Grep in buffer: ")
  if res == "" then
    print("No input provided.")
    return
  end

  -- Run ripgrep limited to the current file
  local content = U.run("rg --vimgrep " .. res .. " " .. vim.fn.shellescape(filepath))
  U.put_text(self.split1.bufnr, content)

  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
  self.last_cursor_line = nil -- reset so open_file will run
  self:open_file()
end

function M.Neogrep:grep_word_in_current_buffer()
  -- Get the word under the cursor in the current window
  local word = vim.fn.expand("<cword>")
  if word == "" then
    print("No word under cursor.")
    return
  end

  -- Get current file path
  local filepath = vim.fn.expand("%:p")
  if filepath == "" then
    print("Cannot determine current file path.")
    return
  end

  -- Save origin buffer and window
  self.origin_bufnr = vim.api.nvim_get_current_buf()
  self.origin_winid = vim.api.nvim_get_current_win()

  self:open()

  -- Run ripgrep for the word under the cursor within the current file
  local content = U.run("rg --vimgrep -i " .. vim.fn.shellescape(word) .. " " .. vim.fn.shellescape(filepath))
  U.put_text(self.split1.bufnr, content)

  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
  self.last_cursor_line = nil -- reset so open_file will run
  self:open_file()
end

function M.Neogrep:next()
  --- Go down one with cursor
  local cursor_line = vim.api.nvim_win_get_cursor(self.split1.winid)[1]
  local total_lines = vim.api.nvim_buf_line_count(self.split1.bufnr)
  if cursor_line < total_lines then
    vim.api.nvim_win_set_cursor(self.split1.winid, { cursor_line + 1, 0 })
  else
    vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 0 }) -- Wrap around to the first line
  end
end

return M
