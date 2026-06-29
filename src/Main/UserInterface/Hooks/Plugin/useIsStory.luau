local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local IsStoryContext = require(uiRoot.Stories.CreateStory.IsStoryContext)

local function useIsStory()
	return React.useContext(IsStoryContext)
end

return useIsStory
