local M = {}

---Creates a new scratch buffer.
---@param horizontal boolean
---@return integer
M.new_scratch = function()
    local buf = vim.api.nvim_create_buf(false, true) -- Create a new scratch buffer
    vim.bo[buf].buftype = "nofile" -- set buffer type to nofile
    vim.bo[buf].buflisted = false -- do not list this buffer in the buffer list
    vim.bo[buf].swapfile = false -- disable swap file for this buffer

    vim.api.nvim_set_current_buf(buf) -- switch to the new buffer
    return buf
end

M.split = function(horizontal)
    if horizontal then
        vim.api.nvim_command("split") -- Create a horizontal split
    else
        vim.api.nvim_command("vsplit") -- Create a vertical split
    end
end

M.nmap = function(key, func, buf)
    vim.keymap.set("n", key, func, { buffer = buf, noremap = true, silent = true })
end

M.imap = function(key, func, buf)
    vim.keymap.set("i", key, func, { buffer = buf, noremap = true, silent = true })
end

M.vmap = function(key, func, buf)
    vim.keymap.set("v", key, func, { buffer = buf, noremap = true, silent = true })
end

M.put_text = function(buffer, text)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(text, "\n"))
end

M.get_text = function(buffer)
    --gets all text from buffer
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    return table.concat(lines, "\n")
end

-- Writes content lines to a temp file, runs a function with the filename, then deletes the file
function M.with_tempfile(content_lines, fn)
  local tmpfile = vim.fn.tempname()
  vim.fn.writefile(content_lines, tmpfile)
  local result = fn(tmpfile)
  vim.fn.delete(tmpfile)
  return result
end

-- Checks if a string is nil or empty
function M.is_empty(s)
  return s == nil or s == ""
end

-- Namespace for highlights (create or reuse)
M._active_ns = vim.api.nvim_create_namespace("highlight_current_line")
function M.highlight_current_line(bufnr, highlight_group)
  local row = unpack(vim.api.nvim_win_get_cursor(0))
  -- Clear previous highlights in this namespace
  vim.api.nvim_buf_clear_namespace(bufnr, M._active_ns, 0, -1)

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line then
    return
  end

  -- Use the passed highlight group
  vim.api.nvim_buf_add_highlight(bufnr, M._active_ns, highlight_group or "NeopostmanCursorLine", row - 1, 0, -1)
end

return M
