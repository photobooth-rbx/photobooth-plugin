local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")

local storyRoots = {}
for _, moduleScript in uiRoot.Apps:QueryDescendants("ModuleScript") do
	if moduleScript.Name:match("%.story$") then
		table.insert(storyRoots, moduleScript.Parent)
	end
end

table.insert(storyRoots, uiRoot.Stories.Debug)

return {
	name = "Photobooth",
	storyRoots = storyRoots,
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
