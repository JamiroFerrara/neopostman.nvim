local M = {}

local Split = require("nui.split")
local U = require("neopostman.utils.utils")
local S = require("neopostman.components.spinner")

---@diagnostic disable: undefined-field
local toggleable = require("neopostman.traits.toggleable")
local debuggable = require("neopostman.traits.debuggable")
local completable = require("neopostman.traits.completable")
local highlightable = require("neopostman.traits.highlightable")
local help = require("neopostman.traits.help")

---@class Layout
M.ChromeNetwork = {}

function M.ChromeNetwork:init()
  vim.api.nvim_create_user_command("ChromeNetwork", function() self:run() end, {})

  self.is_open = false
  self.split1 = Split({ position = "right", size = "50%", enter = false })
  self.split2 = Split({ position = "right", size = "50%", enter = false })
  self.jqsplit = Split({ position = "bottom", size = "10%", enter = false })

  vim.api.nvim_buf_set_option(self.split2.bufnr, "filetype", "json")

  toggleable(self, { self.split1, self.split2, self.jqsplit }, true)
  debuggable(self, { self.split1, self.split2, self.jqsplit })

  highlightable(self, self.split1, "Character")
  highlightable(self, self.split2, "Error")

  completable(self.split2, self.jqsplit)

  -- Store last fetched response content
  self.content = {}
  self.request_cache = {}
  self.view_mode = "response"

  self:init_mappings()
end

function M.ChromeNetwork:init_mappings()
  help(self, self.split1, {
    { "n", "<cr>",  function() self:show_response() end, "Show response body" },
    { "n", "r",     function() self:rerun() end,         "Rerun interceptor" },
    { "n", "<C-r>", function() self:toggle_view_mode() end, "Toggle request/response view" },
    { "n", "y",     function() self:show_url() end,      "Show full request URL" },
  })

  help(self, self.split2, {
    { "n", "<cr>",  function() self:show_response() end, "Show response body" },
    { "n", "r",     function() self:rerun() end,         "Rerun interceptor" },
    { "n", "<C-r>", function() self:toggle_view_mode() end, "Toggle request/response view" },
    { "n", "y",     function() self:show_url() end,      "Show full request URL" },
  })

  help(self, self.jqsplit, {
    { "n", "<cr>", function() self:jq_exec() end, "Run jq command" },
    { "i", "<cr>", function() self:jq_exec() end, "Run jq command" },
    { "n", "<C-u>", function() self:jq_reset() end, "Reset jq output to original JSON" },
  })
end

function M.ChromeNetwork:run()
  self:start_interceptor()
  self:toggle()
end

function M.ChromeNetwork:start_interceptor()
  self.request_cache = {}
  self.content_str = ""
  self.original_content_str = nil
  local bufnr = self.split1.bufnr
  local spinner_hidden = false

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {}) -- clear buffer

  local ns = vim.api.nvim_create_namespace("neopostman_chromenetwork")
  local cmd = "chrome-network-stream.exe"

  vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    on_stdout = function(_, data, _)
      if not spinner_hidden then
        S.Spinner:hide_loading()
        spinner_hidden = true
      end

      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            local ok, decoded = pcall(vim.fn.json_decode, line)
            if ok and decoded then
              local method = decoded.method or "?"
              if method == "OPTIONS" then
                goto continue -- skip OPTIONS requests
              end

              local url = decoded.url or "?"
              local last_segment = url:match("^.*/(.-)$") or url
              local time = os.date("%H:%M:%S")
              local summary = string.format("[%s] %s %s", method, last_segment, time)

              local line_count = vim.api.nvim_buf_line_count(bufnr)
              if line_count == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == "" then
                vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { summary })
              else
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { summary })
              end

              local marker_id = vim.fn.sha256(vim.inspect(decoded)):sub(1, 8)
              decoded.__np_marker = marker_id
              table.insert(self.request_cache, decoded)

              local line_idx = vim.api.nvim_buf_line_count(bufnr) - 1
              vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
                virt_text = { { "" .. marker_id, "Conceal" } },
                virt_text_hide = true,
                hl_mode = "combine",
              })
            end
            ::continue::
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.notify(line, vim.log.levels.WARN)
          end
        end
      end
    end,
  })
end

function M.ChromeNetwork:get_selected_json()
  local bufnr = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("neopostman_chromenetwork")
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-index

  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, 0 }, { row, -1 }, { details = true })
  if #marks == 0 then
    return nil
  end

  local vt = marks[1][4].virt_text
  if not vt or #vt == 0 then
    return nil
  end

  local marker = vt[1][1]:match("(%w+)")
  if not marker then
    return nil
  end

  for _, req in ipairs(self.request_cache) do
    if req.__np_marker == marker then
      return req
    end
  end

  return nil
end

function M.ChromeNetwork:show_response()
  local decoded = self:get_selected_json()
  if not decoded then
    vim.notify("No request selected", vim.log.levels.WARN)
    return
  end

  self.decoded = decoded
  self.view_mode = "response"
  self:refresh_side_panel()
end

function M.ChromeNetwork:refresh_side_panel()
  local decoded = self:get_selected_json()
  if not decoded then
    vim.notify("No request selected", vim.log.levels.WARN)
    return
  end

  local text = ""

  if self.view_mode == "request" then
    text = vim.inspect(decoded)
  else
    if decoded.body then
      local ok, parsed = pcall(vim.fn.json_decode, decoded.body)
      if ok and parsed then
        U.with_tempfile(vim.fn.json_encode(parsed), function(tmpfile)
          local jq_out = vim.fn.system(string.format("jq . %s", tmpfile))
          if vim.v.shell_error == 0 then
            text = jq_out
          else
            text = vim.fn.json_encode(parsed)
          end
        end)
      else
        text = decoded.body
      end
    else
      text = '{"error": "No response body"}'
    end
  end

  self.content_str = text
  self.original_content_str = text -- ✅ always refresh for new request
  U.put_text(self.split2.bufnr, vim.split(text, "\n"))
end

function M.ChromeNetwork:toggle_view_mode()
  if not self.view_mode or self.view_mode == "response" then
    self.view_mode = "request"
  else
    self.view_mode = "response"
  end
  self:refresh_side_panel()
end

function M.ChromeNetwork:show_url()
  local decoded = self:get_selected_json()
  if decoded and decoded.url then
    vim.fn.setreg("+", decoded.url)
    vim.notify("Copied URL to clipboard:\n" .. decoded.url, vim.log.levels.INFO)
  else
    vim.notify("No URL available for selected request", vim.log.levels.WARN)
  end
end

function M.ChromeNetwork:jq_exec(command)
  command = command or vim.api.nvim_get_current_line()
  if command == nil or command == "" then
    command = "." -- fallback to identity filter
  end

  -- Always base jq execution on the original JSON
  local source = self.original_content_str or self.content_str

  U.with_tempfile(source, function(tmpfile)
    local cmd = string.format("jq '%s' %s", command, tmpfile)
    local res = vim.fn.system(cmd)
    self.content_str = res
    U.put_text(self.split2.bufnr, vim.split(res, "\n"))
  end)
end

function M.ChromeNetwork:jq_reset()
  if not self.original_content_str then
    vim.notify("No cached original JSON", vim.log.levels.WARN)
    return
  end

  self.content_str = self.original_content_str
  U.put_text(self.split2.bufnr, vim.split(self.original_content_str, "\n"))
  vim.notify("Reset jq output to original JSON", vim.log.levels.INFO)
end

function M.ChromeNetwork:rerun()
  self:start_interceptor()
end

return M
