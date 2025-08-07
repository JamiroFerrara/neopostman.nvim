---@diagnostic disable: undefined-field
local M = {}
local G = require("neopostman.neogithub")
local P = require("neopostman.neopostman")

M.setup = function(config)
	G.Neogithub:init()
	P.Neopostman:init()
end

return M
