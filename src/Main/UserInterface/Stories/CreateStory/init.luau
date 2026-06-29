local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local Studio = settings().Studio
local themes = Studio:GetAvailableThemes()

local UILabs = require(game.ReplicatedStorage.DevPackages.UILabs)

local IsStoryContext = require(script.IsStoryContext)
local useStoryPlugin = require(script.useStoryPlugin)

export type Props = {
	Disabled: boolean?,
}

local CreateStory = {}

function CreateStory.theme(component: React.FC<Props>)
	return {
		react = React,
		reactRoblox = ReactRoblox,
		controls = {
			Disabled = false,
			Theme = UILabs.Choose({ "Default", "Dark", "Light" }),
		},
		story = function(props)
			local storyPlugin = useStoryPlugin()

			local rootTheme = nil
			if props.controls.Theme == "Dark" then
				rootTheme = themes[2]
			elseif props.controls.Theme == "Light" then
				rootTheme = themes[1]
			end

			return React.createElement(IsStoryContext.Provider, {
				value = true,
			}, {
				Plugin = React.createElement(StudioComponents.PluginProvider, {
					Plugin = storyPlugin,
				}, {
					Theme = React.createElement(StudioComponents.ThemeContext.Provider, {
						value = rootTheme,
					}, {
						Component = React.createElement(component, {
							Disabled = props.controls.Disabled,
						}),
					}),
				}),
			})
		end,
	}
end

function CreateStory.raw(component: React.FC<Props>)
	return {
		react = React,
		reactRoblox = ReactRoblox,
		story = function(props)
			local storyPlugin = useStoryPlugin()

			return React.createElement(IsStoryContext.Provider, {
				value = true,
			}, {
				Plugin = React.createElement(StudioComponents.PluginProvider, {
					Plugin = storyPlugin,
				}, {
					Component = React.createElement(component, {
						Disabled = false,
					}),
				}),
			})
		end,
	}
end

return CreateStory
