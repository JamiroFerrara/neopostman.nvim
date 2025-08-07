local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")

---@diagnostic disable: undefined-field
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")
local insertable = require("neopostman.traits.insertable")
local completable = require("neopostman.traits.completable")
local highlightable = require("neopostman.traits.highlightable")
local help = require("neopostman.traits.help")

---@class Layout
M.Neopostman = {}

function M.Neopostman:init()
	vim.api.nvim_create_user_command("Neopostman", function() self:run() end, {})

  self.is_open = false
  self.split1 = Split({ position = "right", size = "50%", enter = false })
  self.split2 = Split({ position = "right", size = "50%", enter = false })
  self.jqsplit = Split({ position = "bottom", size = "10%", enter = false })
  self.json = {}

  vim.api.nvim_buf_set_option(self.split2.bufnr, "filetype", "json")

  self:init_mappings()

  --Traits
  toggleable(self, { self.split1, self.split2, self.jqsplit })
  debuggable(self, { self.split1, self.split2, self.jqsplit })

  highlightable(self, self.split1, "Character")
  highlightable(self, self.split2, "Error")

  insertable(self, self.jqsplit)
  completable(self.split2, self.jqsplit)
  help(self, { self.split1, self.split2, self.jqsplit }, {
    "p: Toggle Neopostman",
    "r: Rerun last command",
    "e: Edit current script",
    "Enter: Run current script",
    "jq: Enter jq command in bottom split",
  })
end

function M.Neopostman:init_mappings()
  ---Split 1
  self.split1:map("n", "<C-p>", function() self:toggle() end, {})
  self.split1:map("n", "<cr>", function() self:run_current() end, {})
  self.split1:map("n", "r", function() self:rerun() end, {})
  self.split1:map("n", "e", function() self:edit_file() end, {})

  ---Split 2
  self.split2:map("n", "r", function() self:rerun() end, {})
  self.split2:map("n", "<cr>", function() self:rerun() end, {})

  ---Jq 2
  self.jqsplit:map("n", "<cr>", function() self:jq_exec() end, {})
  self.jqsplit:map("i", "<cr>", function() self:jq_exec() end, {})
end

function M.Neopostman:run()
	self:get_scripts()
	self:toggle()
end

function M.Neopostman:jq_exec()
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

function M.Neopostman:run_script(line)
  S.Spinner:show_loading("Loading..")

  U.run("chmod +x .neopostman/" .. line)
  U.run("./.neopostman/" .. line, function(res)
    S.Spinner:hide_loading()
    self.content = res
    U.put_text(self.split2.bufnr, res)
  end)
end

---Gets required scripts from .neopostman dir
function M.Neopostman:get_scripts()
  local res = U.run("ls .neopostman")
  U.put_text(self.split1.bufnr, res)
end

function M.Neopostman:edit_file()
  vim.cmd("edit " .. ".neopostman/" .. self:get_line())
end

function M.Neopostman:rerun()
  self:run_script(self.last_command)
end

function M.Neopostman:get_line()
  local line = vim.api.nvim_get_current_line()
  self.last_command = line
  return line
end

function M.Neopostman:run_current()
  local line = self:get_line()
  self:run_script(line)
end

return M
