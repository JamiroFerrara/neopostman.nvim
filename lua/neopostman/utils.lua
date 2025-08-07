local M = {}

local Job = require("plenary.job")

M.put_text = function(buffer, text)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(text, "\n"))
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

M.get_text = function(buffer)
  --gets all text from buffer
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  return table.concat(lines, "\n")
end

-- Writes content lines to a temp file, runs a function with the filename, then deletes the file
function M.with_tempfile(content_lines, fn)
  local tmpfile = vim.fn.tempname()
  vim.fn.writefile(vim.split(content_lines, "\n"), tmpfile)
  local result = fn(tmpfile)
  vim.fn.delete(tmpfile)
  return result
end

-- Checks if a string is nil or empty
function M.is_empty(s)
  return s == nil or s == ""
end

---Get all window IDs displaying a given buffer
---@param bufnr number Buffer number
---@return table windows List of window IDs displaying the buffer (empty if none)
function M.get_win_ids_from_buf(bufnr)
  local wins = vim.api.nvim_list_wins()
  local result = {}
  for _, winid in ipairs(wins) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      table.insert(result, winid)
    end
  end
  return result
end

---Get the first window ID displaying a given buffer, or nil if none
---@param bufnr number Buffer number
---@return number|nil window ID or nil
M.get_win_id_from_buf = function(bufnr)
  local wins = M.get_win_ids_from_buf(bufnr)
  return wins[1]
end

--- Highlights the current line in the specified buffer using a namespace and highlight group.
-- @param bufnr number: Buffer number
-- @param highlight_group string|nil: Highlight group name (defaults to "NeopostmanCursorLine")
-- @param namespace number|nil: Namespace ID (creates one if not provided)
M.highlight_current_line = function(bufnr, highlight_group, namespace)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local win_id = M.get_win_id_from_buf(bufnr)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local row = cursor and cursor[1]
  if not row then
    return
  end

  namespace = namespace or vim.api.nvim_create_namespace("highlight_current_line_ns")
  highlight_group = highlight_group or "NeopostmanCursorLine"

  -- Clear previous highlights in this namespace
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line or line == "" then
    return
  end

  -- Apply highlight to the whole line
  vim.api.nvim_buf_add_highlight(bufnr, namespace, highlight_group, row - 1, 0, -1)
end

M.completion_from_buffer = function(bufnr)
  require("cmp").setup.buffer({
    sources = {
      {
        name = "buffer",
        option = {
          get_bufnrs = function()
            return { bufnr }
          end,
        },
      },
    },
  })
end

M.focus = function(split)
  if split and split.winid then
    vim.api.nvim_set_current_win(split.winid)
  end
end

M.run = function(command, callback)
  if callback ~= nil then
    return Job:new({
      command = "sh",
      args = { "-c", command },
      cwd = vim.loop.cwd(),
      on_exit = function(j, return_val)
        local res = table.concat(j:result(), "\n")

        vim.schedule(function()
          if callback then
            callback(res, return_val)
          end
        end)
      end,
    }):start()
  else
    return vim.fn.system(command)
  end
end

--- Read a JSON file and decode to Lua table
---@param filepath string
---@return table|nil
function M.read_json_file(filepath)
  local ok, content = pcall(vim.fn.readfile, filepath)
  if not ok then
    vim.notify("Failed to read file: " .. filepath, vim.log.levels.ERROR)
    return nil
  end

  local json_str = table.concat(content, "\n")

  local ok2, result = pcall(vim.fn.json_decode, json_str)
  if not ok2 then
    vim.notify("Failed to decode JSON in file: " .. filepath, vim.log.levels.ERROR)
    return nil
  end

  return result
end

return M
