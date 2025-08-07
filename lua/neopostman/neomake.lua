local M = {}

local Popup = require("nui.popup")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")

---@diagnostic disable: undefined-field
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")
local highlightable = require("neopostman.traits.highlightable")
local help = require("neopostman.traits.help")

---@class Neomake
M.Neomake = {}

function M.Neomake:init()
  vim.api.nvim_create_user_command("Neomake", function() self:run() end, {})

  self.is_open = false
  self.split1 = Popup({
    position = "50%",
    size = {
      width = 80,
      height = 40,
    },
    enter = true,
    focusable = true,
    zindex = 50,
    relative = "editor",
    border = {
      style = "rounded",
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })

  self:init_mappings()

  --Traits
  toggleable(self, { self.split1 })
  debuggable(self, { self.split1 })
  highlightable(self, self.split1, "Character")
  help(self, { self.split1 }, {})
end

function M.Neomake:init_mappings()
  self.split1:map("n", "p", function() self:pull() end, {})
  self.split1:map("n", "<cr>", function() self:run_line() end, {})
end

function M.Neomake:run_line()
  local line = self:get_line()
  U.run("make " .. line, function() end, function(out) U.put_text(self.split1.bufnr, out) end)
end

function M.Neomake:parse_make_headers()
  -- Grabs make commands from makefile
  local makefile_path = self:get_make_path()
  if not makefile_path then
    U.put_text(self.split1.bufnr, "No Makefile found in the current directory.")
    return
  end

  U.put_text(self.split1.bufnr, "")
  local makefile_content = vim.fn.readfile(makefile_path)
  for _, line in ipairs(makefile_content) do
    if line:match("^[^#%s]") then -- Ignore comments and empty lines
      line = line:gsub(":", "")
      if line ~= "" then
        U.append_text(self.split1.bufnr, line)
      end
    end
  end
end

function M.Neomake:get_make_path()
  --- Check if makefile exists in the current directory
  local makefile_path = vim.fn.getcwd() .. "/Makefile"
  if vim.fn.filereadable(makefile_path) == 1 then
    return makefile_path
  else
    return nil
  end
end

function M.Neomake:run()
  self:parse_make_headers()
  self:toggle()
end

function M.Neomake:get_line()
  local line = vim.api.nvim_get_current_line()
  self.last_command = line
  return line
end

return M
