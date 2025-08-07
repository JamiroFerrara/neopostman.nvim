---@diagnostic disable: undefined-field
local M = {}
local G = require("neopostman.neogithub")
local P = require("neopostman.neopostman")
local M = require("neopostman.neomake")

M.setup = function(config)
	G.Neogithub:init()
	P.Neopostman:init()
	M.Neomake:init()
end

return M
