local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")

---@diagnostic disable: undefined-field
local help = require("neopostman.traits.help")
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")

---@class Layout
M.Neogrep = {}

function M.Neogrep:init()
  vim.api.nvim_create_user_command("Neogrep", function()
    self:run()
  end, {})

  self.split1 = Split({ position = "bottom", size = "50%", enter = true })

  self.split1:on("CursorMoved", function()
    -- Highlight current line (you already have this)
    U.highlight_current_line(self.split1.bufnr, "Error", self._active_ns, ":", 3)

    -- Auto-open file on cursor move
    self:open_file()
  end)

  --Traits
  toggleable(self, { self.split1 }, false)

  self:init_mappings()
end

function M.Neogrep:init_mappings()
  help(self, self.split1, {
    { "n", "<cr>", function() self:open_file() end, "Open file under cursor", },
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
  if not file then return end

  lnum = tonumber(lnum)
  col = tonumber(col)

  -- Save origin buffer if modified
  if vim.api.nvim_buf_get_option(self.origin_bufnr, "modifiable") and vim.api.nvim_buf_get_option(self.origin_bufnr, "modified") then
    vim.api.nvim_buf_call(self.origin_bufnr, function()
      vim.cmd("write")
    end)
  end

  local lines = vim.fn.readfile(file)
  if not lines then return end

  -- Replace origin buffer content with matched file's content WITHOUT changing the buffer name
  vim.api.nvim_buf_set_lines(self.origin_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.origin_bufnr, "modified", false)

  -- Set cursor in origin window, keep focus in split
  vim.api.nvim_buf_call(self.origin_bufnr, function()
    vim.api.nvim_win_set_cursor(self.origin_winid, {lnum, col - 1})
  end)
end

function M.Neogrep:run()
  -- Save origin buffer and window
  self.origin_bufnr = vim.api.nvim_get_current_buf()
  self.origin_winid = vim.api.nvim_get_current_win()

  self:open()

  local res = vim.fn.input("Grep: ")
  local content = U.run("rg --vimgrep " .. res)
  U.put_text(self.split1.bufnr, content)
end

return M
