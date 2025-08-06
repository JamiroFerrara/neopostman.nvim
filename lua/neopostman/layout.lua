local M = {}

local Split = require("nui.split")
local Object = require("nui.object")
local Job = require("plenary.job")
local U = require("neopostman.utils")
local S = require("neopostman.spinner")

---@class JLayout
---@field open boolean
---@field split1 unknown
---@field split2 unknown
---@field jqsplit unknown
---@field prev_buf unknown
---@field last_command string
---@field content string
M.Layout = Object("JLayout")

function M.Layout:init()
  self.open = false
  self.split1 = Split({ relative = "editor", position = "right", size = "50%", enter = false })
  self.split2 = Split({ relative = "editor", position = "right", size = "50%", enter = false })
  self.jqsplit = Split({ relative = "editor", position = "bottom", size = "10%", enter = false })

  vim.api.nvim_buf_set_option(self.split2.bufnr, "filetype", "json")

  self:init_mappings()
  self:init_events()
end

function M.Layout:init_events()
  --NOTE: Setup completions for jq buffer
  self.jqsplit:on("InsertEnter", function()
    require("cmp").setup.buffer({
      sources = {
        {
          name = "buffer",
          option = {
            get_bufnrs = function()
              return { self.split2.bufnr }
            end,
          },
        },
      },
    })
  end)

  --NOTE: Highlight current line only in split1
  self.split1:on("CursorMoved", function()
      U.highlight_current_line(self.split1.bufnr, "Character")
  end)

  self.jqsplit:on("BufEnter", function()
    vim.cmd("startinsert")
  end)
end

function M.Layout:close()
  self.split1:hide()
  self.split2:hide()
  vim.api.nvim_set_current_buf(self.prev_buf)
  self.open = false
end

---TODO: Make this configurable from setup
function M.Layout:init_mappings()
  ---Split 1
  self.split1:map("n", "<cr>", function() self:run_current() end, {})
  self.split1:map("n", "r", function() self:rerun() end, {})
  self.split1:map("n", "q", function() self:toggle() end, {})
  self.split1:map("n", "<leader>q", function() self:toggle() end, {})
  self.split1:map("n", "e", function() self:edit() end, {})
  self.split1:map("n", "<C-p>", function() self:toggle() end, {})

  ---Split 2
  self.split2:map("n", "r", function() self:rerun() end, {})
  self.split2:map("n", "<cr>", function() self:rerun() end, {})
  self.split2:map("n", "q", function() self:toggle() end, {})
  self.split2:map("n", "<leader>q", function() self:toggle() end, {})

  ---Jq 2
  self.jqsplit:map("n", "<cr>", function() self:jq_exec() end, {})
  self.jqsplit:map("i", "<cr>", function() self:jq_exec() end, {})
  self.jqsplit:map("n", "q", function() self:toggle() end, {})
end

function M.Layout:focus(split)
  -- Focus a split window
  if split and split.winid then
    vim.api.nvim_set_current_win(split.winid)
  end
end

function M.Layout:jq_exec()
  local command = vim.api.nvim_get_current_line()
  if command == nil or command[1] == "" then
    self:rerun()
    return
  end

  -- Write JSON content to a temporary file
  local tmpfile = vim.fn.tempname()
  vim.fn.writefile(vim.split(self.content, "\n"), tmpfile)

  local cmd = string.format("jq '%s' %s", command, tmpfile)
  local res = vim.fn.system(cmd)
  vim.fn.delete(tmpfile) -- clean up

  vim.api.nvim_buf_set_lines(self.split2.bufnr, 0, -1, false, vim.split(res, "\n"))
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

  Job:new({
    command = "sh",
    args = { "-c", string.format("chmod +x .neopostman/%s && .neopostman/%s", line, line) },
    cwd = vim.loop.cwd(),
    on_exit = function(j, return_val)
      local res = table.concat(j:result(), "\n")

      vim.schedule(function()
        S.Spinner:hide_loading()
        self.content = res
        U.put_text(self.split2.bufnr, res)
      end)
    end,
    on_stderr = function(_, data)
      vim.notify("stderr: " .. data, vim.log.levels.WARN)
    end,
  }):start()
end

function M.Layout:toggle()
  if self.open == false then
    self.prev_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(self.split1.bufnr)

    self.split2:show()
    self.jqsplit:show()
    self.open = true
  else
    self.split1:hide()
    self.split2:hide()
    self.jqsplit:hide()
    self.open = false

    vim.api.nvim_set_current_buf(self.prev_buf)

    -- If the previous buffer was a terminal, enter terminal insert mode
    if vim.bo[self.prev_buf].buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end
end

---Gets required scripts from .neopostman dir
function M.Layout:get_scripts()
  local res = vim.fn.system("ls .neopostman")
  U.put_text(self.split1.bufnr, res)
end

return M
