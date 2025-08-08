local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")

---@diagnostic disable: undefined-field
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")
local highlightable = require("neopostman.traits.highlightable")
local map = require("neopostman.traits.help")

---@class Neogithub
M.Neogithub = {}

function M.Neogithub:init()
  vim.api.nvim_create_user_command("Neogithub", function() self:run() end, {})

  self.is_open = false
  self.split1 = Split({ position = "right", size = "50%", enter = false })
  self.preview_split = Split({ position = "right", size = "50%", enter = false })

  -- Traits
  toggleable(self, { self.split1, self.preview_split }, true)
  debuggable(self, { self.split1, self.preview_split })
  highlightable(self, self.split1, "Character")

  self:init_mappings()

  self.split1:on("CursorMoved", function()
    local repo = self:get_repo_line()
    if repo and repo ~= "" then
      self:show_readme_preview(repo)
    end
  end)
end

function M.Neogithub:init_mappings()
  map(self, self.split1, {
    { "n", "p", function() self:pull() end, "Pull repositories" },
    { "n", "n", function() self:create() end, "Create a new repository" },
    { "n", "d", function() self:delete() end, "Delete a repository" },
    { "n", "r", function() self:refresh() end, "Refresh repositories" },
  })
end

function M.Neogithub:show_readme_preview(repo)
  U.put_text(self.preview_split.bufnr, "")
  S.Spinner:show_loading("Fetching README...")

  -- Get repo HTTPS URL
  U.run("gh repo view " .. repo .. " --json url -q .url", function(url)
    if not url or url == "" then
      U.put_text(self.preview_split.bufnr, { "No README found." })
      S.Spinner:hide_loading()
      return
    end

    -- Convert repo URL to raw README URL
    -- Example: https://github.com/user/repo -> https://raw.githubusercontent.com/user/repo/HEAD/README.md
    local raw_url = url:gsub("https://github.com/", "https://raw.githubusercontent.com/") .. "/HEAD/README.md"

    -- Curl README content
    U.run("curl -s " .. raw_url, function(res)
      if res and res ~= "" then
        local lines = {}
        for line in res:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
        U.put_text(self.preview_split.bufnr, lines)
        vim.bo[self.preview_split.bufnr].filetype = "markdown"
      else
        U.put_text(self.preview_split.bufnr, { "No README.md found in default branch." })
      end
      S.Spinner:hide_loading()
    end)
  end)
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
  self.preview_split:hide()
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
