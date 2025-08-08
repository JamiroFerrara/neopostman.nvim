local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")

---@diagnostic disable: undefined-field
local help = require("neopostman.traits.help")
local toggleable = require("neopostman.traits.toggleable")

---@class Layout
M.Neogrep = {}

function M.Neogrep:init()
  vim.api.nvim_create_user_command("Neogrep", function() self:run() end, {})
  vim.api.nvim_create_user_command("NeogrepWord", function() M.Neogrep:grep_under_cursor() end, {})

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
  local content = U.run("rg --vimgrep " .. res)
  U.put_text(self.split1.bufnr, content)

  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
end

function M.Neogrep:confirm_open_file()
  -- Hide the split
  self.split1:hide()

  -- Clear the highlight in the preview buffer if it exists
  if self.preview_bufnr and self._highlight_ns then
    vim.api.nvim_buf_clear_namespace(self.preview_bufnr, self._highlight_ns, 0, -1)
  end
end

function M.Neogrep:init_mappings()
  help(self, self.split1, {
    { "n", "<cr>", function() self:confirm_open_file() end, "Open file under cursor", },
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
  local content = U.run("rg --vimgrep " .. word)
  U.put_text(self.split1.bufnr, content)
end

return M
