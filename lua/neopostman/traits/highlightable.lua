local U = require("neopostman.utils.utils")

-- features/highlightable.lua
return function(self, buf, highlight)
  buf:on("CursorMoved", function() --Highlight current line only in split1
    U.highlight_current_line(buf.bufnr, highlight, self._active_ns)
  end)
end
