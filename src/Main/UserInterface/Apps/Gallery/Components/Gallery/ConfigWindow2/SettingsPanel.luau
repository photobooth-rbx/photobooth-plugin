local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local Screenshot = require(pluginRoot.Main.Photo.Captures.Screenshot)
local Captures = require(pluginRoot.Main.Photo.Captures)

local StateManager = require(pluginRoot.Main.StateManager)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local FORCE_EXPANDED_GROUPS = true

local function useDropdown(arr: { string })
	local dropdownItems = Hooks.useConstant(function()
		local items = {}
		for i, captureType in arr do
			table.insert(items, {
				Id = tostring(i),
				Text = captureType,
			})
		end
		return items
	end)

	return dropdownItems
end

local function ScaleOSComponent(props: { Disabled: boolean?, LayoutOrder: number? })
	return React.createElement(StudioProperties.InputBox, {
		Disabled = props.Disabled,
		LayoutOrder = props.LayoutOrder,
	})
end

export type Props = {
	Disabled: boolean?,
}

local function SettingsPanel(props: Props)
	local theme = StudioComponents.useTheme()
	local savedState, updateSavedState = StateManager.saved:use()
	local temporaryState, updateTemporaryState = StateManager.temporary:use()

	local viewportCaptureTypes = useDropdown(Captures.Viewport.Order)
	local uiCaptureTypes = useDropdown(Captures.UserInterface.Order)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		UILayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		General = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "General",
			ForceExpanded = FORCE_EXPANDED_GROUPS,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}, {
			UILayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			-- ScaleOS = React.createElement(ScaleOSComponent, {
			-- 	Disabled = props.Disabled,
			-- 	LayoutOrder = 1,
			-- }),

			AlphaBleed = React.createElement(StudioProperties.Boolean, {
				FieldName = "Alpha Bleed",

				Value = savedState.alphaBleedingEnabled,
				OnValueSubmitted = function(newValue)
					updateSavedState(function(state)
						state.alphaBleedingEnabled = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),
			Bindings = React.createElement(StudioProperties.Boolean, {
				FieldName = "Bindings",

				Value = savedState.bindingsEnabled,
				OnValueSubmitted = function(newValue)
					updateSavedState(function(state)
						state.bindingsEnabled = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),
		}),

		Viewport = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Viewport",
			ForceExpanded = FORCE_EXPANDED_GROUPS,

			Disabled = props.Disabled,
			LayoutOrder = 2,
		}, {
			UILayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			BlackoutMode = React.createElement(StudioProperties.Boolean, {
				FieldName = "Blackout Mode",

				Value = temporaryState.isBlackoutMode,
				OnValueSubmitted = function(newValue)
					updateTemporaryState(function(state)
						state.isBlackoutMode = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),
			Fullscreen = React.createElement(StudioProperties.Boolean, {
				FieldName = "Fullscreen",

				Value = temporaryState.isFullscreen,
				OnValueSubmitted = function(newValue)
					updateTemporaryState(function(state)
						state.isFullscreen = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),
			CaptureType = React.createElement(StudioProperties.Dropdown, {
				FieldName = "Capture Type",

				List = viewportCaptureTypes :: any,
				Value = viewportCaptureTypes[temporaryState.viewportCaptureTypeIndex].Id,
				OnValueSubmitted = function(newValue)
					local index = tonumber(newValue)
					if index then
						updateTemporaryState(function(state)
							state.viewportCaptureTypeIndex = index
							return state
						end)
					end
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),
		}),

		UserInterface = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "User Interface",
			ForceExpanded = FORCE_EXPANDED_GROUPS,

			Disabled = props.Disabled,
			LayoutOrder = 3,
		}, {
			UILayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			CaptureType = React.createElement(StudioProperties.Dropdown, {
				FieldName = "Capture Type",

				List = uiCaptureTypes :: any,
				Value = uiCaptureTypes[temporaryState.uiCaptureTypeIndex].Id,
				OnValueSubmitted = function(newValue)
					local index = tonumber(newValue)
					if index then
						updateTemporaryState(function(state)
							state.uiCaptureTypeIndex = index
							return state
						end)
					end
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),
		}),

		Developer = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Developer",
			ForceExpanded = FORCE_EXPANDED_GROUPS,

			Disabled = props.Disabled,
			LayoutOrder = 4,
		}, {
			UILayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			ExperimentalMode = React.createElement(StudioProperties.Boolean, {
				FieldName = if temporaryState.isExperimentalMode == savedState.experimentalModeEnabled
					then "Experimental"
					else "Experimental*",

				Value = savedState.experimentalModeEnabled,
				OnValueSubmitted = function(newValue)
					updateSavedState(function(state)
						state.experimentalModeEnabled = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),
		}),
	})
end

return SettingsPanel
