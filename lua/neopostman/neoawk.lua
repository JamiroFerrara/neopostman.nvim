local M = {}

-- TODO:
M.NeoAwk = {}

M.NeoAwk.filter_buffer_lines_with_awk = function(bufnr, pattern)
  -- Ensure the buffer is loaded
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_err_writeln("Buffer " .. bufnr .. " is not loaded.")
    return
  end

  -- Get all lines from the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local input = table.concat(lines, "\n")

  -- Prepare the awk command
  local awk_cmd = string.format([[awk '/%s/' ]], pattern:gsub("'", "'\\''"))

  -- Use vim.fn.system to call awk
  local output = vim.fn.systemlist(awk_cmd, input)

  -- Check for errors in execution
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_err_writeln("awk command failed: " .. table.concat(output, "\n"))
    return
  end

  -- Replace buffer contents with filtered lines
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
end

return M
