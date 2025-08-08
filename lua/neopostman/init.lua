---@diagnostic disable: undefined-field
local M = {}
local G = require("neopostman.neogithub")
local P = require("neopostman.neopostman")
local M = require("neopostman.neomake")
local NG = require("neopostman.neogrep")

M.setup = function(config)
	G.Neogithub:init()
	P.Neopostman:init()
	M.Neomake:init()
	NG.Neogrep:init()
end

return M
