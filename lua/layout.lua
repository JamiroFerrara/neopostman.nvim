local M = {}

local Split = require("nui.split")
local Popup = require("nui.popup")
local Object = require("nui.object")
local Job = require("plenary.job")
local U = require("./utils")

local default_split_config = {
  relative = "editor",
  position = "right",
  size = "50%",
  enter = false,
}

---@class JLayout
---@field open boolean
---@field split1 unknown
---@field split2 unknown
---@field prev_buf unknown
---@field last_command string
M.Layout = Object("JLayout")

function M.Layout:init()
  self.open = false
  self.split1 = Split(default_split_config)
  self.split2 = Split(default_split_config)

  vim.api.nvim_buf_set_option(self.split2.bufnr, "filetype", "json")

  self:init_mappings()
  self:init_events()
end

function M.Layout:init_events()
  ---TODO:
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
  self.split1:map("n", "J", function() self:page(true) end, {})
  self.split1:map("n", "K", function() self:page(false) end, {})
  self.split1:map("n", "<C-p>", function() self:toggle() end, {})

  ---Split 2
  self.split2:map("n", "r", function() self:rerun() end, {})
  self.split2:map("n", "<cr>", function() self:rerun() end, {})
  self.split2:map("n", "q", function() self:toggle() end, {})
  self.split2:map("n", "<leader>q", function() self:toggle() end, {})
  self.split2:map("n", "<C-p>", function() self:toggle() end, {})
end

function M.Layout:edit()
  local line = self:get_line()
  local file_path = ".neopostman/" .. line

  ---TODO: Make this a controlled buffer so i can add commands
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
  -- self:show_loading("Loading.." .. self.last_command .. "..")
  self:show_loading("Loading..")

  Job:new({
    command = "chmod",
    args = { "+x", ".neopostman/" .. line },
    on_exit = function()
      Job:new({
        command = "./.neopostman/" .. line,
        cwd = vim.loop.cwd(), -- ensure working directory is correct
        on_exit = function(j, return_val)
          local res = table.concat(j:result(), "\n")

          vim.schedule(function()
            self:hide_loading()
            U.put_text(self.split2.bufnr, res)
          end)
        end,
        on_stderr = function(err, data)
          if data then
            vim.schedule(function()
              vim.notify("stderr: " .. data, vim.log.levels.WARN)
            end)
          end
        end,
      }):start()
    end,
  }):start()
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

    -- If the previous buffer was a terminal, enter terminal insert mode
    if vim.bo[self.prev_buf].buftype == 'terminal' then
      vim.cmd('startinsert')
    end
  end
end

---Gets required scripts from .neopostman dir
function M.Layout:get_scripts()
  local res = vim.fn.system("ls .neopostman")
  U.put_text(self.split1.bufnr, res)
end

--TODO: Make the loader stand alone
M.Layout.spinner_index = 1
M.Layout.spinner_timer = nil
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.Layout:show_loading(message)
  if self.loading_popup then
    return
  end

  self.loading_popup = Popup({
    enter = false,
    focusable = false,
    border = {
      style = "rounded",
      text = {
        top = "",
        top_align = "center",
      },
    },
    position = "50%",
    size = {
      width = 30,
      height = 3,
    },
    relative = "editor",
  })

  self.loading_popup:mount()

  self.spinner_index = 1
  local function center_line(text)
    local width = 30
    local padding = math.floor((width - #text) / 2)
    return string.rep(" ", padding) .. text
  end

  self.spinner_timer = vim.loop.new_timer()
  self.spinner_timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if not self.loading_popup then
        return
      end

      local frame = spinner_frames[self.spinner_index]
      local line = center_line(frame .. " " .. message)

      vim.api.nvim_buf_set_lines(self.loading_popup.bufnr, 0, -1, false, { "", line, "" })

      self.spinner_index = (self.spinner_index % #spinner_frames) + 1
    end)
  )
end

function M.Layout:hide_loading()
  if self.spinner_timer then
    self.spinner_timer:stop()
    self.spinner_timer:close()
    self.spinner_timer = nil
  end

  if self.loading_popup then
    self.loading_popup:unmount()
    self.loading_popup = nil
  end
end
return M
