local Popup = require("nui.popup")
local U = require("neopostman.utils.utils")

local highlightable = require("neopostman.traits.highlightable")

-- features/help.lua
return function(self, buf, mappings)
  self.is_open_help = false

  -- Extract lines from mapping definitions
  local lines = {}
  for _, m in ipairs(mappings) do
    local _, key, _, desc = m[1], m[2], m[3], m[4]
    table.insert(lines, string.format("%s: %s", key, desc))
  end

  -- Calculate dynamic height and bottom-right positioning
  local height = #lines
  local width = 50
  local row = vim.o.lines - height - 2
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

  highlightable(self, self.help_buf, "Error");

  -- Close mappings for the help window
  self.help_buf:map("n", "<Esc>", function() self:close_help() end, {})
  self.help_buf:map("n", "q", function() self:close_help() end, {})
  self.help_buf:map("n", "?", function() self:close_help() end, {})

  -- Set "?" in each buffer to toggle help
  if buf.bufnr then
    vim.keymap.set("n", "?", function() self:toggle_help() end, { buffer = buf.bufnr, noremap = true, silent = true })
  end

  -- Register the provided mappings
  for _, m in ipairs(mappings) do
    local mode, key, fn = m[1], m[2], m[3]
    -- Ensure mode is a table for multiple modes
    if type(mode) ~= "table" then
      mode = { mode }
    end
    for _, mod in ipairs(mode) do
      buf:map(mod, key, function() fn() end, {})
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

