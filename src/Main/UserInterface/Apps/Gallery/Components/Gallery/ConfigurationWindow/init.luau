local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local ReactRipple = require(pluginRoot.Packages.ReactRipple)
local Semver = require(pluginRoot.Packages.Semver)
local React = require(pluginRoot.Packages.React)

local StudioMode = require(pluginRoot.Utilities.StudioMode)
local Constants = require(pluginRoot.Constants)
local Wally = require(pluginRoot.Wally)

local StateManager = require(pluginRoot.Main.StateManager)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local SettingsPanel = require(script.SettingsPanel)

local IS_TEAM_CREATE = StudioMode.isTeamCreate()

local function useScrollTransparency(initial: number)
	local transparencyBinding, control = ReactRipple.useSpring(initial)
	local transparency = Hooks.useBindingState(transparencyBinding)
	return transparency, React.useCallback(function(value: number)
		control:setGoal(value)
	end, {})
end

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	OnConfirm: () -> (),

	Disabled: boolean?,
}

local function ConfigurationWindow(props: Props)
	local theme = StudioComponents.useTheme()
	local latestVersion = Hooks.useLatestVersion()
	local isLocalPlugin = Hooks.useIsLocalPlugin()

	local scrollTransparency, setScrollTransparency = useScrollTransparency(1)

	local isExperimentalMode = StateManager.temporary:useSpecific()(function(state)
		return state.isExperimentalMode
	end)

	local experimentalModeEnabled = StateManager.saved:useSpecific()(function(state)
		return state.experimentalModeEnabled
	end)

	local versionText = `v{Wally.package.version}-{if isLocalPlugin then "local" else "cloud"}`
	local needsRestart = isExperimentalMode ~= experimentalModeEnabled
	if needsRestart and Constants.AllowExperimentalMode and not IS_TEAM_CREATE then
		versionText = "requires restart*\n" .. versionText
	elseif Semver.validateVersion(Wally.package.version) and Semver.cmp(latestVersion, ">", Wally.package.version) then
		versionText = "update available*\n" .. versionText
	end

	return React.createElement("Frame", {
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,

		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		UISizeConstraint = React.createElement("UISizeConstraint", {
			MinSize = Vector2.new(Constants.ConfigWindowSize.X - 20, Constants.ConfigWindowSize.Y - 20),
			MaxSize = Vector2.new((Constants.ConfigWindowSize.X - 20) * 2, (Constants.ConfigWindowSize.Y - 20) * 2),
		}),
		AspectConstraint = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = Constants.ConfigWindowSize.X / Constants.ConfigWindowSize.Y,
		}),
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
		Title = React.createElement(StudioComponents.Label, {
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 20),
			Text = "Settings",
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 0),
				PaddingTop = UDim.new(0, 0),
				PaddingBottom = UDim.new(0, 0),
			}),
		}),
		Inner = React.createElement("Frame", {
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 1, -56 - 2),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

			[React.Event.MouseEnter] = function()
				setScrollTransparency(0.6)
			end,
			[React.Event.MouseLeave] = function()
				setScrollTransparency(1)
			end,
		}, {
			Scroll = React.createElement(StudioProperties.VerticalScroll, {
				AnchorPoint = Vector2.zero,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),

				ScrollBarThickness = 2,
				ScrollBarTransparency = scrollTransparency,

				GradientColor = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				GradientHeight = 8,

				Disabled = props.Disabled,
			}, {
				UILayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4 + 8),
				}),

				Panel = React.createElement(SettingsPanel, {}),
			}),
		}),
		Version = React.createElement(StudioComponents.Label, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(80, 28),
			Text = versionText,
			TextSize = 6,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Disabled = true,
			ZIndex = -1,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 0),
				PaddingTop = UDim.new(0, 0),
				PaddingBottom = UDim.new(0, 0),
			}),
		}),
		Close = React.createElement(StudioComponents.MainButton, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(80, 28),
			Text = "Confirm",
			OnActivated = props.OnConfirm,
			Disabled = props.Disabled,
		}),
	})
end

return ConfigurationWindow
