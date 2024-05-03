print("Loading Melted Studio")

local baseUrls = {
	[1] = "http://azv.ddns.net/MeltedStudio/",
	[2] = "https://raw.githubusercontent.com/AZV-EU/MeltedStudio/main/"
}

local baseUrl = baseUrls[2]

if _G.MeltedStudio then
	local f, err = pcall(_G.MeltedStudio.Remove)
	if not f then
		print("Failed to cleanup MeltedStudio:", err)
	end
end

if game.CoreGui:FindFirstChild("MeltedStudio") then
	game.CoreGui.MeltedStudio:Destroy()
end

print("Importing MeltedStudio")
local gui = _G.GetObjects(17086197884)[1]
gui.Parent = game.CoreGui

for _,v in pairs(gui:GetChildren()) do
	if v:IsA("LocalScript") or v:IsA("ModuleScript") then
		v:Destroy()
	end
end

print("Setting up MeltedStudio")
local core = _G.GetModuleScript()
core.Parent = gui
core.Name = "MeltedStudioCore"
_G.SetRemoteSource(core, baseUrl .. "MeltedStudioCore.lua")

local api = _G.GetModuleScript()
api.Parent = core
api.Name = "MeltedStudioAPI"
_G.SetRemoteSource(api, baseUrl .. "MeltedStudioAPI.lua")

print("Running MeltedStudio")
local f, err = pcall(require, gui.MeltedStudioCore)
if not f then
	print("Failed to run MeltedStudioCore:", err)
end

if script:IsA("ModuleScript") then return {} end