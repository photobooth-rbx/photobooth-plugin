local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityStepper = require(pluginRoot.Utilities.PriorityStepper)
local Signal = require(pluginRoot.Packages.Signal)
local Trove = require(pluginRoot.Packages.Trove)

local appRoot = script:FindFirstAncestor("AutoCapture")
local RenderPriorities = require(appRoot.RenderPriorities)

local AnimationManagerStatic = {}

local AnimationManagerClass = {}
AnimationManagerClass.__index = AnimationManagerClass
AnimationManagerClass.ClassName = "AnimationManager"

export type AnimationManager = typeof(setmetatable(
	{} :: {
		trove: Trove.Trove,
		trackChanged: Signal.Signal<()>,

		instance: Instance,
		track: AnimationTrack?,
		animation: Animation,
	},
	AnimationManagerClass
))

function AnimationManagerStatic.new(instance: Instance)
	local self = setmetatable({}, AnimationManagerClass) :: AnimationManager

	self.trove = Trove.new()
	self.trackChanged = Signal.new()

	self.instance = instance
	self.track = nil

	self.animation = Instance.new("Animation")
	self.animation.AnimationId = ""

	local animator = self.instance:FindFirstChildWhichIsA("Animator", true)
	if animator then
		self:_initAnimator(animator)
	end

	return self
end

function AnimationManagerClass._resetTransforms(self: AnimationManager)
	for _, animated in self.instance:QueryDescendants("Motor6D, Bone, AnimationConstraint") do
		local casted = animated :: any
		casted.Transform = CFrame.identity
	end
end

function AnimationManagerClass._initAnimator(self: AnimationManager, animator: Animator)
	self.trove:Add(PriorityStepper.render:connect(RenderPriorities.ANIMATOR, function()
		-- force our dt to zero b/c we manually step the position elsewhere
		animator:StepAnimations(0)
	end))

	local trackTrove = Trove.new()
	self.trove:Add(trackTrove)
	self.trove:Add(self.animation:GetPropertyChangedSignal("AnimationId"):Connect(function()
		trackTrove:Clean()

		local content = Content.fromUri(self.animation.AnimationId)
		if content ~= Content.none then
			local track = animator:LoadAnimation(self.animation)

			trackTrove:Add(function()
				track:Stop(0)
				track:Destroy()

				self:_resetTransforms()
				animator:StepAnimations(0)

				if self.track == track then
					self.track = nil
					self.trackChanged:Fire()
				end
			end)

			trackTrove:Add(task.spawn(function()
				while track.Length == 0 do
					PriorityStepper.render:wait()
				end

				track:Play(0, nil, 0)
				animator:StepAnimations(0)

				self.track = track
				self.trackChanged:Fire()
			end))
		end
	end))
end

function AnimationManagerClass.onTransform(self: AnimationManager, callback: () -> ())
	local cleanupTrove = Trove.new()
	local threadTrove = Trove.new()
	local timePosition = if self.track then self.track.TimePosition else -1

	cleanupTrove:Add(self.trackChanged:Connect(function()
		timePosition = if self.track then self.track.TimePosition else -1

		threadTrove:Clean()
		threadTrove:Add(task.spawn(function()
			PriorityStepper.render:wait() -- must wait for the render to finish for transforms are applied
			callback()
		end))
	end))

	cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.TRACK, function()
		local newTimePosition = if self.track then self.track.TimePosition else -1
		if newTimePosition > 0 and newTimePosition ~= timePosition then
			threadTrove:Clean()
			timePosition = newTimePosition
			callback()
		end
	end))

	return function()
		threadTrove:Destroy()
		cleanupTrove:Destroy()
	end
end

function AnimationManagerClass.hookTrack(self: AnimationManager, callback: (AnimationTrack?) -> ())
	local cleanupTrove = Trove.new()

	cleanupTrove:Add(task.spawn(function()
		callback(self.track)
	end))

	cleanupTrove:Add(self.trackChanged:Connect(function()
		callback(self.track)
	end))

	self.animation.Parent = self.instance.Parent

	return function()
		if self.track then
			self.track:AdjustSpeed(0)
		end
		self.animation.Parent = nil
		cleanupTrove:Destroy()
	end
end

function AnimationManagerClass.Destroy(self: AnimationManager)
	self.trove:Destroy()
	self.trackChanged:Destroy()
end

return AnimationManagerStatic
