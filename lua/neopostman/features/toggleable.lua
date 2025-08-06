-- features/toggleable.lua
return function(self, splits)
  self.is_open = false
  self._toggleable_prev_buf = nil

  function self:open()
    self._toggleable_prev_buf = vim.api.nvim_get_current_buf()

    for i, split in ipairs(splits) do
      if i == 1 then
      -- For first split: just load/set buffer but don't show it
      -- Assuming split has a 'bufnr' field or method to set buffer
      -- This part depends on split implementation, for example:
      -- vim.api.nvim_buf_load(split.bufnr) -- load the buffer if needed
      -- But do NOT call split:show()
      -- If you want to just make sure the buffer exists and is loaded,
      -- you can do nothing or explicitly load it if lazy-loaded.
      else
        split:show()
      end
    end

    -- set focus to first split if available
    if splits[1] then
      vim.api.nvim_set_current_buf(splits[1].bufnr)
    end

    self.is_open = true
  end

  function self:close()
    for _, split in ipairs(splits) do
      split:hide()
    end

    -- restore buffer
    if self._toggleable_prev_buf and vim.api.nvim_buf_is_valid(self._toggleable_prev_buf) then
      vim.api.nvim_set_current_buf(self._toggleable_prev_buf)

      if vim.bo[self._toggleable_prev_buf].buftype == "terminal" then
        vim.cmd("startinsert")
      end
    end

    if self.debug_buf ~= nil then
      self:close_debug()
    end

    self.is_open = false
  end

  function self:toggle()
    if self.is_open then
      self:close()
    else
      self:open()
    end
  end
end
