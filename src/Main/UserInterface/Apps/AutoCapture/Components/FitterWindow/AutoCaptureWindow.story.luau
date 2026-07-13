local Players = game:GetService("Players")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityStepper = require(pluginRoot.Utilities.PriorityStepper)
local React = require(pluginRoot.Packages.React)
local Trove = require(pluginRoot.Packages.Trove)

local appRoot = script:FindFirstAncestor("AutoCapture")
local RenderPriorities = require(appRoot.RenderPriorities)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local FitterWindow = require(script.Parent)

local function useAnimationTrack()
	local animTrack, setAnimTrack = React.useState(nil :: AnimationTrack?)

	React.useEffect(function()
		local trove = Trove.new()
		trove:Add(task.spawn(function()
			local character = trove:Add(Players:CreateHumanoidModelFromUserIdAsync(2155311))
			local animator = assert(character:FindFirstChildWhichIsA("Animator", true), "No animator")

			character.Name = "Rig"
			character.Parent = workspace

			local animation = trove:Add(Instance.new("Animation"))
			animation.AnimationId = "rbxassetid://507770239"
			animation.Parent = animator

			local track = trove:Add(animator:LoadAnimation(animation))
			track:Play(0, nil, 0)

			trove:Add(PriorityStepper.render:connect(RenderPriorities.ANIMATOR, function(_dt)
				animator:StepAnimations(0)
			end))

			setAnimTrack(track)
		end))

		return function()
			trove:Destroy()
		end
	end, {})

	return animTrack
end

local function Component(props: { Size: UDim2, Disabled: boolean? })
	local padding = 5
	local animationTrack = useAnimationTrack()

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
	}, {
		Core = React.createElement(FitterWindow, {
			ScaleOS = Vector2.one,
			Resolution = Vector2.new(256, 256),
			IsFullScreen = false,

			PaddingTop = padding,
			PaddingBottom = padding,
			PaddingLeft = padding,
			PaddingRight = padding,
			PaddingVisible = true,

			AnimationTrack = animationTrack,

			OnCaptureRectChanged = function(_rect) end,

			Disabled = props.Disabled,
		}),
	})
end

return CreateStory.theme(function(props)
	return React.createElement(Component, {
		Size = UDim2.fromScale(1, 1),
		Disabled = props.Disabled,
	})
end)
