local Split = require("nui.split")
local U = require("neopostman.utils")

-- features/debuggable.lua
return function(self, bufs)
  self.is_large_debug = false
  self.is_open_debug = false
  self.debug_buf = Split({ relative = "editor", position = "bottom", size = "20%", enter = false })

  self.debug_buf:map("n", "<Esc>", function() self:close() end, {})
  self.debug_buf:map("n", "q", function() self:close() end, {})
  self.debug_buf:map("n", "L", function() self:toggle_large_debug() end, {})
  self.debug_buf:map("n", "q", function() self:close() end, {})

  for _, buf in ipairs(bufs) do
    if buf.bufnr then
      vim.keymap.set("n", "\\",
        function()
          self:toggle_debug()
        end,
        { buffer = buf.bufnr, noremap = true, silent = true }
      )
    end
  end

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
