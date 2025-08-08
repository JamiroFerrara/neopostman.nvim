local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")

---@diagnostic disable: undefined-field
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")
local highlightable = require("neopostman.traits.highlightable")
local help = require("neopostman.traits.help")

---@class Neogithub
M.Neogithub = {}

function M.Neogithub:init()
  vim.api.nvim_create_user_command("Neogithub", function() self:run() end, {})

  self.is_open = false
  self.split1 = Split({ position = "right", size = "50%", enter = false })

  self:init_mappings()

  --Traits
  toggleable(self, { self.split1 })
  debuggable(self, { self.split1 })
  highlightable(self, self.split1, "Character")
  help(self, { self.split1 }, {
    "p: Pull repositories",
    "n: Create a new repository",
    "d: Delete a repository",
  })

  self.split1:on("CursorMoved", function() self:print(self:get_line()) end)
end

function M.Neogithub:init_mappings()
  self.split1:map("n", "p", function() self:pull() end, {})
  self.split1:map("n", "r", function() self:refresh() end, {})
  self.split1:map("n", "n", function() self:create() end, {})
  self.split1:map("n", "d", function() self:delete() end, {})
end

function M.Neogithub:pull()
  S.Spinner:show_loading("Pulling repositories..")
  local line = self:get_repo_line()

  U.put_text(self.split1.bufnr, "")
  U.run("gh repo clone " .. line, function(res)
    -- Final result callback (optional)
    S.Spinner:hide_loading()
    self:toggle()
  end, function(data)
    -- Stream callback for real-time output
    if data and data ~= "" then
      U.append_text(self.split1.bufnr, data)
    end
  end)

  -- self:toggle()
end

function M.Neogithub:create()
  U.put_text(self.split1.bufnr, { "public", "private" })
  self.split1:map("n", "<cr>", function()
    U.put_text(self.split1.bufnr, "")
    self.split1:map("n", "<cr>", function()
      self:create_repo(self:get_line())
      self:toggle()
    end, {})
  end, {})
end

function M.Neogithub:create_repo(name)
  U.run("gh repo create --private " .. name, function()
    U.run("gh repo clone " .. name)
    self:toggle()
  end)
end

function M.Neogithub:delete()
  S.Spinner:show_loading("Deleting repository..")
  local line = self:get_repo_line()
  U.run("gh repo delete --yes " .. line, function()
    self:refresh()
  end)
end

function M.Neogithub:run()
  self:open()
  U.put_text(self.split1.bufnr, "")
  S.Spinner:show_loading("Loading..")

  U.run("gh repo list", function(res)
    local stripped = {}
    for line in res:gmatch("[^\r\n]+") do
      local repo = line:match("^(%S+)")
      if repo then
        table.insert(stripped, repo)
      end
    end
    U.put_text(self.split1.bufnr, stripped)
    S.Spinner:hide_loading()
  end)
end

function M.Neogithub:refresh()
  S.Spinner:show_loading("Refreshing..")
  self:run()
end

function M.Neogithub:get_line()
  local line = vim.api.nvim_get_current_line()
  self.last_command = line
  return line
end

function M.Neogithub:get_repo_line()
  local line = self:get_line()
  --- Get up until first space
  line = line:match("^(%S+)")
  return line
end

return M
