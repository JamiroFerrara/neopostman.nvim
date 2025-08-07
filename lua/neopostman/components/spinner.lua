local M = {}

local Object = require("nui.object")
local Popup = require("nui.popup")

---@class M.Spinner
---@field loading_popup unknown
---@field index integer
---@field timer unknown
M.Spinner = Object("Spinner")

M.Spinner.index = 1
M.Spinner.timer = nil
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.Spinner:show_loading(message)
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

  self.index = 1
  local function center_line(text)
    local width = 30
    local padding = math.floor((width - #text) / 2)
    return string.rep(" ", padding) .. text
  end

  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if not self.loading_popup then
        return
      end

      local frame = spinner_frames[self.index]
      local line = center_line(frame .. " " .. message)

      vim.api.nvim_buf_set_lines(self.loading_popup.bufnr, 0, -1, false, { "", line, "" })

      self.index = (self.index % #spinner_frames) + 1
    end)
  )
end

function M.Spinner:hide_loading()
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end

  if self.loading_popup then
    self.loading_popup:unmount()
    self.loading_popup = nil
  end
end

return M
