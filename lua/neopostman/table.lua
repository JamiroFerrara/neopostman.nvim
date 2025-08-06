local M = {}
local Split = require("nui.split")
local U = require("./utils")

local debuggable = require("neopostman.features.debuggable")

M.TableView = {}

function M.TableView:init(data)
  self.data = M.convert_json_array_to_flat_table(data) or {}
  self.total_width = vim.o.columns
  self.col_widths = self:calculate_full_column_widths(self.data, self.total_width)

  self.split = Split({
    relative = "editor",
    position = "bottom",
    size = #self.data + 4,
    enter = true,
    win_options = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
      cursorline = false,
      foldcolumn = "0",
      wrap = false,
    },
  })

  self.split:mount()
  self.bufnr = self.split.bufnr

  U.nmap("<cr>", function() M.TableView:exec() end, self.bufnr)
  vim.api.nvim_buf_set_option(self.bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(self.bufnr, "swapfile", false)

  local lines = self:build_table_lines()
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)

  -- Create custom highlight group with red text
  -- vim.cmd("highlight TableHover guifg=#ff0000 gui=bold")
  vim.cmd("highlight TableHover guifg=#ff0000 gui=bold")

  self:setup_highlighting()

  debuggable(self, { self.split })
end

function M.TableView:exec()
  local row, byte_col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(self.bufnr, row - 1, row, false)[1]
  if not line then
    return
  end

  local display_col = vim.fn.strdisplaywidth(line:sub(1, byte_col))

  -- Skip header or border rows
  local border_rows = {
    [1] = true,
    [3] = true,
    [#self.data + 3] = true,
  }

  -- Find column index
  local visual_col = 1
  for col_index, width in ipairs(self.col_widths) do
    local left = visual_col + 1 -- skip left border
    local right = visual_col + width

    if display_col >= left and display_col <= right then
      local data_row = row - 3 -- Adjust for header and borders
      local cell_value = self.data[data_row + 1] and self.data[data_row + 1][col_index]
      self:print(string.format("Cell[%d,%d]: %s", data_row, col_index, cell_value or "nil"))
      return
    end

    visual_col = right + 1
  end
end

function M.TableView:calculate_full_column_widths(data, total_width)
  local max_widths = {}
  for _, row in ipairs(data) do
    for col, val in ipairs(row) do
      local display_len = vim.fn.strdisplaywidth(val)
      max_widths[col] = math.max(max_widths[col] or 0, display_len)
    end
  end

  local total = 0
  for _, w in ipairs(max_widths) do
    total = total + w
  end

  local separator_space = (#max_widths + 1) -- borders/separators
  local usable_width = total_width - separator_space

  local scaled = {}
  local scaled_total = 0
  for i, w in ipairs(max_widths) do
    local sw = math.floor((w / total) * usable_width)
    scaled[i] = sw
    scaled_total = scaled_total + sw
  end

  local extra = usable_width - scaled_total
  for i = 1, extra do
    scaled[i] = scaled[i] + 1
  end

  return scaled
end

function M.TableView:build_table_lines()
  local lines = {}
  table.insert(lines, self:draw_border("╭", "┬", "╮", "─"))
  table.insert(lines, self:build_row(self.data[1]))
  table.insert(lines, self:draw_border("├", "┼", "┤", "─"))
  for i = 2, #self.data do
    table.insert(lines, self:build_row(self.data[i]))
  end
  table.insert(lines, self:draw_border("╰", "┴", "╯", "─"))
  return lines
end

function M.TableView:build_row(row)
  local line = "│"
  for i, cell in ipairs(row) do
    local width = self.col_widths[i]
    local text = tostring(cell)
    local pad = width - vim.fn.strdisplaywidth(text)
    local left = math.floor(pad / 2)
    local right = pad - left
    line = line .. string.rep(" ", left) .. text .. string.rep(" ", right) .. "│"
  end
  return line
end

function M.TableView:draw_border(left, mid, right, fill)
  local line = left
  for i, width in ipairs(self.col_widths) do
    line = line .. string.rep(fill, width)
    if i < #self.col_widths then
      line = line .. mid
    end
  end
  line = line .. right
  return line
end

function M.TableView:setup_highlighting()
  self._active_ns = vim.api.nvim_create_namespace("TableViewHighlight")
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = self.bufnr,
    callback = function()
      local row, byte_col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_buf_get_lines(self.bufnr, row - 1, row, false)[1]
      if not line then
        return
      end

      local display_col = vim.fn.strdisplaywidth(line:sub(1, byte_col))

      -- Skip header or border rows
      local border_rows = {
        [1] = true,
        [3] = true,
        [#self.data + 3] = true,
      }
      if border_rows[row] then
        vim.api.nvim_buf_clear_namespace(self.bufnr, self._active_ns, 0, -1)
        return
      end

      local visual_col = 1
      for i, width in ipairs(self.col_widths) do
        local left_border = visual_col
        local right_border = visual_col + width

        if display_col >= left_border + 1 and display_col <= right_border then
          vim.api.nvim_buf_clear_namespace(self.bufnr, self._active_ns, 0, -1)
          local line = vim.api.nvim_buf_get_lines(self.bufnr, row - 1, row, false)[1]

          local start_col = vim.str_byteindex(line, left_border) -- get byte index of the 5th character (0-based)
          local end_col = vim.str_byteindex(line, right_border) -- 11th character (exclusive)

          vim.api.nvim_buf_add_highlight(self.bufnr, self._active_ns, "TableHover", row - 1, start_col, end_col)

          break
        end

        visual_col = right_border + 1
      end
    end,
  })
end

M.convert_json_array_to_flat_table = function(json_array)
  if type(json_array) ~= "table" or #json_array == 0 then
    return {}
  end

  -- Extract headers from the first item
  local headers = {}
  for key, _ in pairs(json_array[1]) do
    table.insert(headers, key)
  end

  -- Sort headers alphabetically for consistent order (optional)
  table.sort(headers)

  -- Prepare the flat table with headers as the first row
  local flat_table = { headers }

  -- Add each object's values in header order
  for _, obj in ipairs(json_array) do
    local row = {}
    for _, key in ipairs(headers) do
      local value = obj[key]
      table.insert(row, tostring(value or ""))
    end
    table.insert(flat_table, row)
  end

  return flat_table
end

M.append_text = function(buffer, text)
  local current_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local new_lines = vim.split(text, "\n")
  local updated_lines = vim.list_extend(current_lines, new_lines)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, updated_lines)
  ---force redraw
  vim.api.nvim_buf_call(buffer, function()
    vim.cmd("normal! G") -- Move to the end of the buffer
  end)
end

return M
