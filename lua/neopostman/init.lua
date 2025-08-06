---@diagnostic disable: undefined-field
local M = {}
local U = require("neopostman.utils")
local L = require("neopostman.layout")
local T = require("neopostman.table")

M.setup = function(config)
	vim.api.nvim_create_user_command("Neopostman", M.run, {})

	L.Layout:init()

  -- local json = U.run("nu -c 'ls | to json'")
  -- T.TableView:init(vim.json.decode(json))
end

M.run = function()
	L.Layout:get_scripts()
	L.Layout:toggle()
end

return M
