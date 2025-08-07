local U = require("neopostman.utils")

-- features/highlightable.lua
return function(self, buf, highlight)
  buf:on("CursorMoved", function() --Highlight current line only in split1
    U.highlight_current_line(buf.bufnr, highlight, self._active_ns)
    self:print(self:get_line())
  end)
end
