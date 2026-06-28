local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

return {
	name = "Photobooth",
	storyRoots = {
		script.Parent.Parent,
	},
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
