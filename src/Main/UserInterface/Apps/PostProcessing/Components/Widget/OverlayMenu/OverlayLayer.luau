local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local OverlayContext = React.createContext(nil :: Frame?)

export type ProviderProps = {
	children: React.ReactNode,
}

local function Provider(props: ProviderProps)
	local layer, setLayer = React.useState(nil :: Frame?)

	local setLayerRef = React.useCallback(function(instance: Frame?)
		setLayer(instance)
	end, {})

	return React.createElement(React.Fragment, nil, {
		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			OverlayContent = React.createElement(OverlayContext.Provider, {
				value = layer,
			}, props.children),
		}),

		OverlayLayer = React.createElement("Frame", {
			Active = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			ref = setLayerRef,
		}),
	})
end

local function useTarget()
	return React.useContext(OverlayContext) :: Frame
end

return {
	provider = Provider,
	useTarget = useTarget,
}
