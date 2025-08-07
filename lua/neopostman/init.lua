---@diagnostic disable: undefined-field
local M = {}
local L = require("neopostman.neopostman")

M.setup = function(config)
	L.Neopostman:init()
end

return M
