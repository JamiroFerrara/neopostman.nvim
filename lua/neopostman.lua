local M = {}
local U = require("./utils")
local L = require("./layout")

M.setup = function(config)
	L.Layout:init()
	L.Layout:get_scripts()
end

M.run = function()
	L.Layout:toggle()
end

return M
