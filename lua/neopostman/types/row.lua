---@class Row
---@field file string
---@field lnum number
---@field col number
---@field text string
M = {}

function M:new(file, lnum, col, text)
  local row = {
    file = file,
    lnum = lnum,
    col = col,
    text = text
  }
  return row
end

---@param row Row
---@return string
function M:to_string(row)
    return string.format("%s:%d:%d: %s", row.file, row.lnum, row.col, row.text)
end

---@param rows Row[]
---@return string
function M:array_to_string(rows)
  local lines = "";
  for _, row in ipairs(rows) do
    local line = self:to_string(row)
    lines = lines .. line .. "\n"
  end
  return lines;
end

---@param lnum number
---@param rows Row[]
---@return Row | nil
function M:get_from_lnum(lnum, rows)
  for i, row in ipairs(rows) do
    if tostring(i) == tostring(lnum) then
      return row
    end
  end
  return nil
end

function M:get_from_current_lnum(rows)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return self:get_from_lnum(lnum, rows)
end

return M
