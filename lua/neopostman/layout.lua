local M = {}

local Split = require("nui.split")
local Object = require("nui.object")
local U = require("neopostman.utils")
local S = require("neopostman.spinner")
local highlightable = require("neopostman.features.highlightable")

---@diagnostic disable: undefined-field
local toggleable = require("neopostman.features.toggleable")
local debuggable = require("neopostman.features.debuggable")

---@class JLayout
---@field is_open boolean
---@field prev_buf unknown
---@field last_command string
---@field content string
M.Layout = Object("JLayout")

function M.Layout:init()
  self.is_open = false
  self.split1 = Split({ relative = "editor", position = "right", size = "50%", enter = false })
  self.split2 = Split({ relative = "editor", position = "right", size = "50%", enter = false })
  self.jqsplit = Split({ relative = "editor", position = "bottom", size = "10%", enter = false })

  vim.api.nvim_buf_set_option(self.split2.bufnr, "filetype", "json")

  self:init_mappings()
  self:init_events()

  --Traits
  toggleable(self, { self.split1, self.split2, self.jqsplit })
  debuggable(self, { self.split1, self.split2, self.jqsplit })
  highlightable(self, self.split1, "Character")
  highlightable(self, self.split2, "Error")
end

function M.Layout:init_mappings()
  ---Split 1
  self.split1:map("n", "<cr>", function() self:run_current() end, {})
  self.split1:map("n", "r", function() self:rerun() end, {})
  self.split1:map("n", "e", function() self:edit() end, {})
  self.split1:map("n", "<C-p>", function() self:toggle() end, {})

  ---Split 2
  self.split2:map("n", "r", function() self:rerun() end, {})
  self.split2:map("n", "<cr>", function() self:rerun() end, {})

  ---Jq 2
  self.jqsplit:map("n", "<cr>", function() self:jq_exec() end, {})
  self.jqsplit:map("i", "<cr>", function() self:jq_exec() end, {})
end

function M.Layout:init_events()
  self.jqsplit:on("InsertEnter", function() --nvim-cmp from buffer
    U.completion_from_buffer(self.split2.bufnr)
  end)

  self.jqsplit:on("BufEnter", function() --enter insert mode in jq split
    vim.cmd("startinsert")
  end)
end

function M.Layout:jq_exec()
  local command = vim.api.nvim_get_current_line()
  if command == nil or command[1] == "" then
    self:rerun()
    return
  end

  U.with_tempfile(self.content, function(tmpfile)
    local cmd = string.format("jq '%s' %s", command, tmpfile)
    local res = vim.fn.system(cmd)
    vim.api.nvim_buf_set_lines(self.split2.bufnr, 0, -1, false, vim.split(res, "\n"))
  end)
end

function M.Layout:edit()
  local line = self:get_line()
  local file_path = ".neopostman/" .. line
  vim.cmd("edit " .. file_path)
end

function M.Layout:rerun()
  self:run_script(self.last_command)
end

function M.Layout:get_line()
  local line = vim.api.nvim_get_current_line()
  self.last_command = line
  return line
end

function M.Layout:run_current()
  local line = self:get_line()
  self:run_script(line)
end

function M.Layout:run_script(line)
  S.Spinner:show_loading("Loading..")

  U.run("chmod +x .neopostman/" .. line)
  U.run("./.neopostman/" .. line, function(res)
    S.Spinner:hide_loading()
    self.content = res
    U.put_text(self.split2.bufnr, res)
  end)
end

---Gets required scripts from .neopostman dir
function M.Layout:get_scripts()
  local res = U.run("ls .neopostman")
  U.put_text(self.split1.bufnr, res)
end

return M
