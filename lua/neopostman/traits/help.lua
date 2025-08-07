local Popup = require("nui.popup")
local U = require("neopostman.utils.utils")

-- features/help.lua
return function(self, bufs, lines)
  self.is_open_help = false

  -- Calculate dynamic height and bottom-right positioning
  local height = #lines
  local width = 40
  local row = vim.o.lines - height - 2 -- -2 accounts for command line etc.
  local col = vim.o.columns - width - 2

  self.help_buf = Popup({
    position = {
      row = row,
      col = col,
    },
    size = {
      width = width,
      height = height,
    },
    enter = true,
    focusable = true,
    zindex = 1000,
    relative = "editor",
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    border = {
      style = "rounded",
    },
  })

  -- Close mappings
  self.help_buf:map("n", "<Esc>", function() self:close_help() end, {})
  self.help_buf:map("n", "q", function() self:close_help() end, {})
  self.help_buf:map("n", "?", function() self:close_help() end, {})

  -- Set "?" to toggle help in each buffer
  for _, buf in ipairs(bufs) do
    if buf.bufnr then
      vim.keymap.set("n", "?", function()
        self:toggle_help()
      end, { buffer = buf.bufnr, noremap = true, silent = true })
    end
  end

  function self:open_help()
    U.put_text(self.help_buf.bufnr, lines)
    self.help_buf:show()
    self.is_open_help = true
  end

  function self:close_help()
    self.help_buf:hide()
    self.is_open_help = false
  end

  function self:toggle_help()
    if self.is_open_help then
      self:close_help()
    else
      self:open_help()
    end
  end
end

