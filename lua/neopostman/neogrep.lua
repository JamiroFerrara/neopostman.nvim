--TOOO:
-- Split panes
-- Hidden files
local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")
local A = require("neopostman.neoawk").NeoAwk
local Row = require("neopostman.types.row");

---@diagnostic disable: undefined-field
local help = require("neopostman.traits.help")
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")

---@class Layout
M.Neogrep = {}

function M.Neogrep:init()
  vim.api.nvim_create_user_command("Neogrep", function() self:run() end, {})
  vim.api.nvim_create_user_command("NeogrepWord", function() M.Neogrep:grep_under_cursor() end, {})
  vim.api.nvim_create_user_command("NeogrepBuffer", function() M.Neogrep:grep_buffer() end, {})

  self._highlight_ns = vim.api.nvim_create_namespace("NeogrepPreviewHighlight")

  --TODO: Move me out to NeoAwk module
  vim.api.nvim_create_user_command("FilterBuffer", function()
    A.filter_buffer_lines_with_awk(vim.api.nvim_get_current_buf(), vim.fn.input("Find lines: "))
  end, {})

  self.split1 = Split({ position = "bottom", size = "20%", enter = true })

  self.split1:on("CursorMoved", function()
    U.highlight_current_line(self.split1.bufnr, "Error", self._active_ns, ":", 3)
    self:goto_file()
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
  debuggable(self, { self.split1 })

  self:init_mappings()
end

function M.Neogrep:init_mappings()
  help(self, self.split1, {
    { "n", "<cr>", function() self:open_file() end, "Open file under cursor" },
    { "n", "<M-n>", function() U:next() end, "Next result" },
    { "n", "<C-n>", function() U:next() end, "Next result" },
    { "n", "<leader>fw", function() U:run() end, "Next result" },
  })
end

function M.Neogrep:save_origin()
  -- Save origin buffer and window
  self.origin_bufnr = vim.api.nvim_get_current_buf()
  self.origin_winid = vim.api.nvim_get_current_win()
end

function M.Neogrep:run()
  self:save_origin()
  self:open()

  self.results = self:grep(vim.fn.input("Grep: "));
  local string_res = Row:array_to_string(self.results);
  U.put_text(self.split1.bufnr, string_res)
  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
end

function M.Neogrep:grep_under_cursor()
  -- Get the word under the cursor in the current window
  local word = vim.fn.expand("<cword>")
  self:save_origin()
  self:open()

  self.results = self:grep(word);
  U.put_text(self.split1.bufnr, Row:array_to_string(self.results))
  self:goto_file()
end

function M.Neogrep:grep_buffer()
  local path = vim.fn.expand("%:p")
  print(path)

  self:save_origin()
  self:open()

  self.results = self:grep(vim.fn.input("Grep: "), path);
  local string_res = Row:array_to_string(self.results);
  U.put_text(self.split1.bufnr, string_res)
  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
end

function M.Neogrep:goto_file()
  local parsed = Row:get_from_current_lnum(self.results)
  if parsed == nil then return end

  local current_win = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(self.origin_winid)
  vim.cmd("keepjumps edit " .. vim.fn.fnameescape(parsed.file))
  vim.cmd("filetype detect")

  self.preview_bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_cursor(0, { parsed.lnum, parsed.col - 1 })

  -- Highlight the entire line visually in the preview buffer
  vim.api.nvim_buf_clear_namespace(self.preview_bufnr, self._highlight_ns, 0, -1)
  vim.api.nvim_buf_add_highlight(self.preview_bufnr, self._highlight_ns, "Visual", parsed.lnum - 1, 0, -1)

  vim.api.nvim_set_current_win(current_win)
end

function M.Neogrep:open_file()
  local parsed = Row:get_from_current_lnum(self.results)

  self.split1:hide()
  vim.api.nvim_buf_clear_namespace(self.preview_bufnr, self._highlight_ns, 0, -1)

  vim.api.nvim_set_current_win(self.origin_winid)
  vim.api.nvim_win_set_cursor(0, { parsed.lnum, parsed.col - 1 })
  vim.cmd("filetype detect")
end

---@return Row[]
---@param word string
---@param file? string
function M.Neogrep:grep(word, file)
  local rows = {}

  local res = "";
  if file == nil then
    res = U.run("rg --vimgrep " .. vim.fn.shellescape(word))
  else
    res = U.run("rg --vimgrep " .. vim.fn.shellescape(word) .. " " .. vim.fn.shellescape(file))
  end

  local lines = U.split(res, "\n")
  table.remove(lines) --Remove last line
  for _, r in ipairs(lines) do
    local split_line = U.split(r, ":")
    table.insert(rows, Row:new(split_line[1], tonumber(split_line[2]), tonumber(split_line[3]), split_line[4]));
  end
  return rows
end

return M
