local M = {}

local Split = require("nui.split")
local Object = require("nui.object")
local U = require("./utils")

local default_split_config = {
  relative = "editor",
  position = "right",
  size = "50%",
}

---@class JLayout
---@field open boolean
---@field split1 unknown
---@field split2 unknown
---@field prev_buf unknown
M.Layout = Object("JLayout")

function M.Layout:init()
  self.open = false
  self.split1 = Split(default_split_config)
  self.split2 = Split(default_split_config)

  self.split1:map("n", "<cr>", function()
    self:run_script()
  end, { remap = false, silent = true })
end

function M.Layout:run_script()
  local line = vim.api.nvim_get_current_line()
  vim.fn.system("chmod +x .neopostman/" .. line)
  local res = vim.fn.system("./.neopostman/" .. line)
  U.put_text(self.split2.bufnr, res)
end

function M.Layout:toggle()
  if self.open == false then
    self.prev_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(self.split1.bufnr)

    self.split2:show()
    self.open = true
  else
    self.split1:hide()
    self.split2:hide()
    self.open = false

    vim.api.nvim_set_current_buf(self.prev_buf)
  end
end

---Gets required scripts from .neopostman dir
function M.Layout:get_scripts()
  local res = vim.fn.system("ls .neopostman")
  vim.api.nvim_buf_set_lines(self.split1.bufnr, 0, -1, false, vim.split(res, "\n"))
end

return M
