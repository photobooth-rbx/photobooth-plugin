local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local Captures = require(pluginRoot.Main.Photo.Captures)
local StateManager = require(pluginRoot.Main.StateManager)

local AutoCaptureRoot = script:FindFirstAncestor("AutoCapture")
local Controller = require(AutoCaptureRoot.Controller)

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,

	Controller: Controller.AutoCaptureController,
	CaptureRect: Rect,

	LayoutOrder: number?,
	Disabled: boolean?,
}

local function Properties(props: Props, ref: any)
	local static = props.Controller.staticObservableState:use()
	local dynamic = props.Controller.dynamicObservableState:use()

	local origin = StateManager.settings:useSpecific()(function(state)
		return state.autoCaptureOrigin
	end)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		ref = ref,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Photobooth = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Photobooth",
			Disabled = props.Disabled,
			LayoutOrder = 1,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			AlphaBleed = React.createElement(StudioProperties.Boolean, {
				FieldName = "Alpha Bleed",

				Value = dynamic.alphaBleed,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.alphaBleed = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			CaptureType = React.createElement(StudioProperties.Dropdown, {
				FieldName = "Capture Type",

				List = Captures.Viewport.Order,
				Value = dynamic.captureType,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.captureType = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),
		}),

		Capture = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Capture",
			Disabled = props.Disabled,
			LayoutOrder = 2,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			IsSynced = React.createElement(StudioProperties.Boolean, {
				FieldName = "Synchronized",

				Value = static.isSynced,
				OnValueSubmitted = function(newValue)
					props.Controller.staticObservableState:update()(function(state)
						state.isSynced = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			IsFullScreen = React.createElement(StudioProperties.Boolean, {
				FieldName = "Fullscreen",

				Value = dynamic.isFullScreen,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.isFullScreen = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),

			CaptureDelay = React.createElement(StudioProperties.Number, {
				FieldName = "Capture Delay",

				Min = 0,

				Value = dynamic.captureDelay,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.captureDelay = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),

			CaptureSize = React.createElement(StudioProperties.Vector2, {
				FieldName = "Capture Size",

				Value = if dynamic.isFullScreen
					then Vector2.new(props.CaptureRect.Width, props.CaptureRect.Height)
					else dynamic.captureSize,
				OnValueSubmitted = function(newValue)
					if not dynamic.isFullScreen then
						props.Controller.dynamicObservableState:update()(function(state)
							state.captureSize = newValue
							return state
						end)
					end
				end,

				Disabled = if dynamic.isFullScreen then true else props.Disabled,
				LayoutOrder = 4,
			}),
		}),

		Camera = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Camera",
			Disabled = props.Disabled,
			LayoutOrder = 3,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Origin = React.createElement(StudioProperties.Vector3, {
				FieldName = "Origin",

				Value = origin,
				OnValueSubmitted = function(newValue)
					StateManager.settings:update()(function(state)
						state.autoCaptureOrigin = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			FOV = React.createElement(StudioProperties.Number, {
				FieldName = "FOV",

				Min = 1,
				Max = 120,
				Slider = true,
				Step = 0.001,

				Value = dynamic.fov,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.fov = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),

			FitType = React.createElement(StudioProperties.Dropdown, {
				FieldName = "Fit Type",

				List = { "Orbital", "Point Cloud", "Free" },
				Value = dynamic.fitType,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.fitType = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),

			FitTypeSettings = dynamic.fitType ~= "Free" and React.createElement(React.Fragment, nil, {
				TryUseMeshVertices = dynamic.fitType == "Point Cloud"
					and React.createElement(StudioProperties.Boolean, {
						FieldName = "Use Mesh Vertices",

						Value = dynamic.tryUseMeshVertices,
						OnValueSubmitted = function(newValue)
							props.Controller.dynamicObservableState:update()(function(state)
								state.tryUseMeshVertices = newValue
								return state
							end)
						end,

						Disabled = props.Disabled,
						LayoutOrder = 4,
					}),

				DistanceScale = React.createElement(StudioProperties.Number, {
					FieldName = "Distance Scale",

					Min = 0,
					Value = dynamic.distanceScale,
					OnValueSubmitted = function(newValue)
						props.Controller.dynamicObservableState:update()(function(state)
							state.distanceScale = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 5,
				}),
			}),
		}),

		Padding = dynamic.fitType ~= "Free" and React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Padding",
			Disabled = props.Disabled,
			LayoutOrder = 4,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Visible = React.createElement(StudioProperties.Boolean, {
				FieldName = "Visible",

				Value = dynamic.paddingVisible,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.paddingVisible = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			Uniform = React.createElement(StudioProperties.Boolean, {
				FieldName = "Uniform",

				Value = dynamic.paddingUniform,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.paddingUniform = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),

			UniformAmount = dynamic.paddingUniform and React.createElement(StudioProperties.Number, {
				FieldName = "Uniform Padding",

				Step = 1,
				Min = 0,

				Value = dynamic.padding,
				OnValueSubmitted = function(newValue)
					props.Controller.dynamicObservableState:update()(function(state)
						state.padding = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),

			NonUniformAmounts = not dynamic.paddingUniform and React.createElement(React.Fragment, {}, {
				Top = React.createElement(StudioProperties.Number, {
					FieldName = "Top Padding",

					Step = 1,
					Min = 0,

					Value = dynamic.paddingTop,
					OnValueSubmitted = function(newValue)
						props.Controller.dynamicObservableState:update()(function(state)
							state.paddingTop = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 4,
				}),
				Right = React.createElement(StudioProperties.Number, {
					FieldName = "Right Padding",

					Step = 1,
					Min = 0,

					Value = dynamic.paddingRight,
					OnValueSubmitted = function(newValue)
						props.Controller.dynamicObservableState:update()(function(state)
							state.paddingRight = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 5,
				}),
				Bottom = React.createElement(StudioProperties.Number, {
					FieldName = "Bottom Padding",

					Step = 1,
					Min = 0,

					Value = dynamic.paddingBottom,
					OnValueSubmitted = function(newValue)
						props.Controller.dynamicObservableState:update()(function(state)
							state.paddingBottom = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 6,
				}),
				Left = React.createElement(StudioProperties.Number, {
					FieldName = "Left Padding",

					Step = 1,
					Min = 0,

					Value = dynamic.paddingLeft,
					OnValueSubmitted = function(newValue)
						props.Controller.dynamicObservableState:update()(function(state)
							state.paddingLeft = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 7,
				}),
			}),
		}),
	})
end

return React.forwardRef(Properties)
