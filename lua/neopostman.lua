local M = {}
local U = require("./utils")
local L = require("./layout")

M.setup = function(config)
	vim.api.nvim_create_user_command("Neopostman", M.run, {})

	L.Layout:init()
end

M.run = function()
	L.Layout:get_scripts()
	L.Layout:toggle()
end

return M
