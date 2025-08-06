local Popup = require("nui.popup")
local U = require("neopostman.utils")

-- features/debuggable.lua
return function(self)
  self.is_open_debug = false
  self.debug_buf = Popup({
    position = "50%",
    size = {
      width = 80,
      height = 40,
    },
    enter = true,
    focusable = true,
    zindex = 999,
    relative = "editor",
    border = {
      style = "rounded",
    },
  })

  self.debug_buf:map("n", "<Esc>", function() self:close() end, {})
  self.debug_buf:map("n", "q", function() self:close() end, {})
  vim.keymap.set("t", "\\", function() self:toggle_debug() end, {})
  vim.keymap.set("n", "\\", function() self:toggle_debug() end, {})

  function self:print(message)
    U.append_text(self.debug_buf.bufnr, message)
  end

  function self:open_debug()
    self.debug_buf:show()
  end

  function self:close_debug()
    self.debug_buf:hide()
  end

  function self:toggle_debug()
    if self.is_open_debug then
      self:close_debug()
      self.is_open_debug = false
    else
      self:open_debug()
      self.is_open_debug = true
    end
  end
end
