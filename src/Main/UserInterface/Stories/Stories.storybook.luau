local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")

return {
	name = "Photobooth",
	storyRoots = {
		uiRoot.Apps,
		uiRoot.Stories.Debug,
	},
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
