local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local NoImage = require(script.NoImage)
local DisplayImage = require(script.DisplayImage)

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Title: string,
	Layers: { Controller.RenderLayer },
	IsLoading: boolean,
}

local function ImageViewer(props: Props)
	local nLayers = #props.Layers

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
	}, {
		NoImage = nLayers <= 0 and React.createElement(NoImage, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -44, 1, -44),
		}),

		DisplayImage = nLayers > 0 and React.createElement(DisplayImage, {
			Size = UDim2.new(1, -44, 1, -44),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),

			Title = props.Title,
			Layers = props.Layers,
			IsLoading = props.IsLoading,
		}),
	})
end

return ImageViewer
