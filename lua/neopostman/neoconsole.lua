local M = {}

local Tree = require("nui.tree")
local event = require("nui.utils.autocmd").event
local S = require("neopostman.components.spinner")
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")
local help = require("neopostman.traits.help")

---@class ChromeConsole
M.ChromeConsole = {}

function M.ChromeConsole:init()
  vim.api.nvim_create_user_command("ChromeConsole", function() self:run() end, {})

  -- main buffer
  self.bufnr = vim.api.nvim_create_buf(false, true)
  self.winid = nil
  self.logs = {}
  self.log_tree = nil
  self.ns = vim.api.nvim_create_namespace("neopostman_chromeconsole")

  self:init_mappings()
end

function M.ChromeConsole:init_mappings()
  local opts = { buffer = self.bufnr, silent = true }
  local map = vim.keymap.set

  map("n", "<CR>", function() self:toggle_node() end, opts)
  map("n", "r",    function() self:rerun() end, opts)
  map("n", "/",    function() self:filter_prompt() end, opts)
  map("n", "q",    function() self:close() end, opts)
end

-- open or reopen console buffer in current window
function M.ChromeConsole:open()
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = vim.api.nvim_create_buf(false, true)
  end
  vim.api.nvim_win_set_buf(0, self.bufnr)
  self.winid = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_name(self.bufnr, "ChromeConsole")
  vim.bo[self.bufnr].buftype = "nofile"
  vim.bo[self.bufnr].bufhidden = "wipe"
  vim.bo[self.bufnr].filetype = "chromeconsole"
end

function M.ChromeConsole:run()
  self:open()
  self:start_stream()
end

function M.ChromeConsole:start_stream()
  self.logs = {}
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})

  local spinner_hidden = false
  local cmd = "chrome-console-stream.exe"

  -- S.Spinner:show_loading("Connecting to Chrome Console...")

  -- Initialize tree now that we have bufnr
  self.log_tree = Tree({
    bufnr = self.bufnr,
    winid = self.winid,
    nodes = {},
  })

  vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    on_stdout = function(_, data, _)
      if not spinner_hidden then
        S.Spinner:hide_loading()
        spinner_hidden = true
      end
      if not data then return end
      for _, line in ipairs(data) do
        if line == "" then goto continue end
        local ok, decoded = pcall(vim.fn.json_decode, line)
        if ok and decoded then
          self:add_log(decoded)
        end
        ::continue::
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          vim.notify("[ConsoleStream] " .. line, vim.log.levels.WARN)
        end
      end
    end,
  })
end

function M.ChromeConsole:add_log(entry)
  local url = entry.pageUrl or "unknown"
  local text = entry.text or (entry.args and vim.inspect(entry.args) or "")
  local timestamp = entry.timestamp or os.date("%H:%M:%S")

  local summary = string.format("[%s] %s: %s", timestamp, url, text)
  local id = #self.logs + 1
  self.logs[id] = entry

  local node = Tree.Node({
    id = id,
    summary = summary,
    expanded = false,
    children = {},
  })

  self.log_tree:add_node(node)
  self:render_tree()
end

-- recursively convert a Lua table to Tree.Node children
local function json_to_nodes(tbl, indent)
  local nodes = {}
  indent = indent or ""
  if type(tbl) ~= "table" then
    table.insert(nodes, Tree.Node({ summary = indent .. tostring(tbl) }))
    return nodes
  end
  for k, v in pairs(tbl) do
    local key_str = string.format("%s%s:", indent, tostring(k))
    if type(v) == "table" then
      local child = Tree.Node({
        summary = key_str,
        expanded = false,
        children = json_to_nodes(v, indent .. "  "),
      })
      table.insert(nodes, child)
    else
      local val_str = string.format("%s %s", key_str, tostring(v))
      table.insert(nodes, Tree.Node({ summary = val_str }))
    end
  end
  return nodes
end

function M.ChromeConsole:toggle_node()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(self.bufnr, row - 1, row, false)[1]
  if not line or line == "" then return end

  local node = nil
  for _, n in ipairs(self.log_tree.nodes) do
    if n.summary == line then
      node = n
      break
    end
  end

  if not node then
    -- maybe child node
    for _, n in ipairs(self.log_tree.nodes) do
      for _, c in ipairs(n:get_nodes()) do
        if c.summary == line then node = c break end
      end
    end
  end
  if not node then return end

  if node:has_children() then
    if node:is_expanded() then
      node:collapse()
    else
      node:expand()
    end
  else
    -- expand root node with args
    local entry = self.logs[node.id]
    if entry and entry.args then
      node.children = json_to_nodes(entry.args, "  ")
      node:expand()
    end
  end
  self:render_tree()
end

function M.ChromeConsole:render_tree()
  local lines = {}
  local function render_node(n, depth)
    table.insert(lines, string.rep(" ", depth * 2) .. n.summary)
    if n:has_children() and n:is_expanded() then
      for _, c in ipairs(n:get_nodes()) do
        render_node(c, depth + 1)
      end
    end
  end
  for _, n in ipairs(self.log_tree.nodes) do
    render_node(n, 0)
  end
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function M.ChromeConsole:filter_prompt()
  local input = vim.fn.input("Filter text: ")
  if input == "" then return end
  local filtered = {}
  for _, entry in ipairs(self.logs) do
    local match_text = entry.text or ""
    if match_text:match(input) or vim.inspect(entry.args):match(input) then
      table.insert(filtered, entry)
    end
  end

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
  self.log_tree.nodes = {}
  for _, e in ipairs(filtered) do
    self:add_log(e)
  end
end

function M.ChromeConsole:rerun()
  self:start_stream()
end

function M.ChromeConsole:close()
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
end

return M

