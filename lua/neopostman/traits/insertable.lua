-- features/insertable.lua
return function(self, buf)
 buf:on("BufEnter", function() --enter insert mode in jq split
    vim.cmd("startinsert")
  end)
end
