--TOOO:
-- Split panes
-- Hidden files
local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")
local A = require("neopostman.neoawk").NeoAwk
local Row = require("neopostman.types.row");
local NeoMake = require("neopostman.neomake").Neomake;

---@diagnostic disable: undefined-field
local help = require("neopostman.traits.help")
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")

---@class Layout
M.Neogrep = {}

function M.Neogrep:init()
  vim.api.nvim_create_user_command("Neogrep", function() self:run(true) end, {})
  vim.api.nvim_create_user_command("NeogrepToggle", function() self:toggle() end, {})
  vim.api.nvim_create_user_command("NeogrepWord", function() M.Neogrep:grep_under_cursor() end, {})
  vim.api.nvim_create_user_command("NeogrepBuffer", function() M.Neogrep:grep_buffer() end, {})
  vim.api.nvim_create_user_command("TmuxSessions", function() M.Neogrep:tmux_sessions() end, {})
  vim.api.nvim_create_user_command("NeoMake", function() M.Neogrep:run_make() end, {})

  self._highlight_ns = vim.api.nvim_create_namespace("NeogrepPreviewHighlight")

  --TODO: Move me out to NeoAwk module
  vim.api.nvim_create_user_command("FilterBuffer", function()
    A.filter_buffer_lines_with_awk(vim.api.nvim_get_current_buf(), vim.fn.input("Find lines: "))
  end, {})

  self.split1 = Split({ position = "bottom", size = "20%", enter = true })

  self.split1:on("CursorMoved", function()
    U.highlight_current_line(self.split1.bufnr, "Error", self._active_ns, ":", 3)

    if self.mode == "grep" then
      self:goto_file()
    end
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
    { "n", "<leader>fw", function() self:run(false) end, "Next result" },
    { "n", "s", function() self:run(false) end, "Next result" },
    { "n", "<C-d>", function() A.filter_buffer_lines_with_awk(vim.api.nvim_get_current_buf(), vim.fn.input("Find lines: ")) end, "Next result" },
  })
end

function M.Neogrep:save_origin()
  -- Save origin buffer and window
  self.origin_bufnr = vim.api.nvim_get_current_buf()
  self.origin_winid = vim.api.nvim_get_current_win()
end

function M.Neogrep:run(save_origin)
  M.Neogrep.mode = "grep";
  if save_origin then
    self:save_origin()
  end

  self:open()

  local word = vim.fn.input("Grep: ")
  self.results = self:grep(word);
  local string_res = Row:array_to_string(self.results);
  U.put_text(self.split1.bufnr, string_res)
  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
  self:highlight_matches(word)
end

function M.Neogrep:run_make()
  self.mode = "make"
  self:save_origin()
  self:open()

  local rows = {}
  local makefile = NeoMake:parse_make_headers()
  for _, cmd in ipairs(makefile) do
    table.insert(rows, Row:new("", 0, 0, cmd))
  end

  local launched_from_term = NeoMake:launched_with_terminal()
  if launched_from_term then
    vim.api.nvim_set_current_buf(self.split1.bufnr)
  end

  self.results = rows
  local content = Row:array_to_string(rows, true)
  U.put_text(self.split1.bufnr, content)
  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 1 })
end

function M.Neogrep:grep_under_cursor()
  M.Neogrep.mode = "grep";
  -- Get the word under the cursor in the current window
  local word = vim.fn.expand("<cword>")
  self:save_origin()
  self:open()

  self.results = self:grep(word);
  U.put_text(self.split1.bufnr, Row:array_to_string(self.results))
  self:highlight_matches(word)
  self:goto_file()
end

function M.Neogrep:get_tmux_sessions()
  M.Neogrep.mode = "tmux";
  local sessions = U.run("tmux list-sessions -F '#{session_name}'")
  local session_list = U.split(sessions, "\n")

  local session_rows = {}
  for _, session in ipairs(session_list) do
    if session ~= "" then
      table.insert(session_rows, Row:new(session, 0, 0, ""))
    end
  end

  return session_rows
end

function M.Neogrep:tmux_sessions()
  self:save_origin()
  self:open()

  self.results = self:get_tmux_sessions()

  local string_res = Row:array_to_string(self.results)
  U.put_text(self.split1.bufnr, string_res)

  -- Highlight the first session
  vim.api.nvim_buf_add_highlight(self.split1.bufnr, self._highlight_ns, "Error", 0, 0, -1)
  vim.api.nvim_win_set_cursor(self.split1.winid, { 1, 0 })
end

function M.Neogrep:grep_buffer()
  local path = vim.fn.expand("%:p")
  print(path)

  self:save_origin()
  self:open()

  local word =vim.fn.input("Grep: ");
  self.results = self:grep(word, path);
  local string_res = Row:array_to_string(self.results);
  U.put_text(self.split1.bufnr, string_res)
  self:highlight_matches(word)
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
  if self.mode == "make" then
    --- Go to tmux session
    local parsed = Row:get_from_current_lnum(self.results)
    self.split1:hide()

    local launched_from_term = NeoMake:launched_with_terminal()
    if launched_from_term then
      NeoMake:run_in_nvim_terminal("make " .. parsed.text)
    else
      NeoMake:run_in_tmux("make " .. parsed.text)
    end
  end

  if self.mode == "tmux" then
    --- Go to tmux session
    local parsed = Row:get_from_current_lnum(self.results)
    self.split1:hide()
    vim.api.nvim_set_current_win(self.origin_winid)
    U.run("tmux switch-client -t " .. vim.fn.shellescape(parsed.file))
  end

  if self.mode == "grep" then 
    local parsed = Row:get_from_current_lnum(self.results)

    self.split1:hide()
    vim.api.nvim_buf_clear_namespace(self.preview_bufnr, self._highlight_ns, 0, -1)

    vim.api.nvim_set_current_win(self.origin_winid)
    vim.api.nvim_win_set_cursor(0, { parsed.lnum, parsed.col - 1 })
    vim.cmd("filetype detect")
  end
end

function M.Neogrep:highlight_matches(word)
  local bufnr = self.split1.bufnr
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local hl_group = "Error" -- You can define your own if needed

  for i, line in ipairs(lines) do
    local start = 1
    while true do
      local s, e = string.find(line, word, start)
      if not s then break end
      vim.api.nvim_buf_add_highlight(bufnr, self._highlight_ns, hl_group, i - 1, s - 1, e)
      start = e + 1
    end
  end
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
    -- Split up to the 4th colon
    local text = table.concat(split_line, ":", 4)
    table.insert(rows, Row:new(split_line[1], tonumber(split_line[2]), tonumber(split_line[3]), text));
  end
  return rows
end

return M
