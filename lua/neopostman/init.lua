---@diagnostic disable: undefined-field
local M = {}
local G = require("neopostman.neogithub")
local P = require("neopostman.neopostman")
local M = require("neopostman.neomake")
local NG = require("neopostman.neogrep")
local NM = require("neopostman.neomessage")
local CN = require("neopostman.neonetwork")
local NC = require("neopostman.neoconsole")
local TW = require("neopostman.neotaskwarrior")

M.setup = function(config)
	NM.NeoMessage:init()
	G.Neogithub:init()
	P.Neopostman:init()
	M.Neomake:init()
	NG.Neogrep:init()
	CN.ChromeNetwork:init()
	NC.ChromeConsole:init()
	NC.ChromeConsole:init()
	-- TW.Neotaskwarrior:init()
end

return M
