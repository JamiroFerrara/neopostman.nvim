local U = require("neopostman.utils.utils")

-- features/completable.lua
return function(from_buf, to_buf)
  to_buf:on("InsertEnter", function() --nvim-cmp from buffer
    U.completion_from_buffer(from_buf.bufnr)
  end)
end
