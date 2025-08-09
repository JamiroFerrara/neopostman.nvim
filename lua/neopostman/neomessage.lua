local M = {}

local Snacks = require("snacks")
local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")
local A = require("neopostman.neoawk").NeoAwk

---@diagnostic disable: undefined-field
local help = require("neopostman.traits.help")
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")

M.NeoMessage = {}

function M.NeoMessage:init()
  vim.api.nvim_create_user_command("NeoNotifications", function() self:run() end, {})

  self.split = Split({ position = "bottom", size = "20%", enter = true })
  self.preview = Split({ position = "top", size = "80%", enter = false })

  self.split:on("CursorMoved", function() --Highlight current line only in split1
    U.highlight_current_line(self.split.bufnr, "Error", self._active_ns)
  end)

  self.split:on("BufEnter", function()
    local winid = self.split.winid
    if winid and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_set_cursor(winid, { 1, 0 })
    end
  end)

  toggleable(self, { self.split, self.preview }, true)
  debuggable(self, { self.split })

  self:init_mappings()
end

function M.NeoMessage:init_mappings()
  help(self, self.split, {
    { "n", "<CR>", function() self:preview_message() end, "View Full Message", },
  })
end

function M.NeoMessage:preview_message()
  self._toggleable_prev_buf = vim.api.nvim_get_current_buf()

  local line = vim.api.nvim_get_current_line()
  if line == "" then
    return
  end

  local id = line:match("^(%d+):")
  local notification = self:get_notification(id)
  self:print(self._toggleable_prev_buf, self.split.bufnr)
  U.replace_window(self._toggleable_prev_buf, self.preview.bufnr)
  U.put_text(self.preview.bufnr, notification.msg)
end

function M.NeoMessage:run()
  self:toggle_init()
  self.split:show()

  local notifications = Snacks.notifier.get_history()
  for _, notification in ipairs(notifications) do
    U.append_text(self.split.bufnr, notification.id .. ":" .. notification.icon .. " " .. notification.msg)
  end
  --- remove first line
  U.remove_line(self.split.bufnr, 1)
end

function M.NeoMessage:get_notification(id)
  local notifications = Snacks.notifier.get_history()
  for _, notification in ipairs(notifications) do
    if notification.id == tonumber(id) then
      return notification
    end
  end
  return ""
end

return M
