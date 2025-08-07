---@diagnostic disable: undefined-field
local M = {}
local L = require("neopostman.neogithub")

M.setup = function(config)
	L.Neogithub:init()
end

return M
