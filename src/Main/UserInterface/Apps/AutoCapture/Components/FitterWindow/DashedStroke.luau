local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

export type Props = {
	Thickness: number?,
	Color: Color3?,
	Transparency: number?,

	DashLength: number?,
	GapLength: number?,

	BorderStrokePosition: Enum.BorderStrokePosition?,
	ZIndex: number?,
}

local function getSegments(length: number, dashLength: number, gapLength: number)
	if length <= dashLength then
		return { { 0, length } }
	end

	local count = math.max(2, math.round((length + gapLength) / (dashLength + gapLength)))
	local step = (length - dashLength) / (count - 1)

	local segments = {}
	for i = 0, count - 1 do
		local start = math.round(i * step)
		local finish = math.round(i * step + dashLength)
		table.insert(segments, { start, finish - start })
	end

	return segments
end

local function DashedStroke(props: Props)
	local thickness = props.Thickness or 1
	local dashLength = props.DashLength or 6
	local gapLength = props.GapLength or 4
	local strokePosition = props.BorderStrokePosition or Enum.BorderStrokePosition.Center

	local outset = if strokePosition == Enum.BorderStrokePosition.Outer
		then thickness
		elseif strokePosition == Enum.BorderStrokePosition.Center then thickness / 2
		else 0

	local rootRef = React.useRef(nil)
	local absSize = Hooks.useRefProperty(rootRef, "AbsoluteSize", Vector2.zero)
	local width = math.round(absSize.X)
	local height = math.round(absSize.Y)

	local children: { [string]: React.Node } = {}

	local function createDash(key: string, position: UDim2, size: UDim2)
		children[key] = React.createElement("Frame", {
			Position = position,
			Size = size,
			BackgroundColor3 = props.Color or Color3.new(0, 0, 0),
			BackgroundTransparency = props.Transparency or 0,
			BorderSizePixel = 0,
		})
	end

	for i, segment in getSegments(width, dashLength, gapLength) do
		local start, length = segment[1], segment[2]
		createDash(`Top{i}`, UDim2.fromOffset(start, 0), UDim2.fromOffset(length, thickness))
		createDash(`Bottom{i}`, UDim2.fromOffset(start, height - thickness), UDim2.fromOffset(length, thickness))
	end

	for i, segment in getSegments(height, dashLength, gapLength) do
		local start = math.max(segment[1], thickness)
		local finish = math.min(segment[1] + segment[2], height - thickness)
		if finish > start then
			createDash(`Left{i}`, UDim2.fromOffset(0, start), UDim2.fromOffset(thickness, finish - start))
			createDash(
				`Right{i}`,
				UDim2.fromOffset(width - thickness, start),
				UDim2.fromOffset(thickness, finish - start)
			)
		end
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-outset, -outset),
		Size = UDim2.new(1, outset * 2, 1, outset * 2),
		ZIndex = props.ZIndex,
		ref = rootRef,
	}, children)
end

return DashedStroke
