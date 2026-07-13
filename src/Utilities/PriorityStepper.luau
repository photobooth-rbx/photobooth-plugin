local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Signal = require(pluginRoot.Packages.Signal)

local PriorityStepperStatic = {}

local PriorityStepperClass = {}
PriorityStepperClass.__index = PriorityStepperClass
PriorityStepperClass.ClassName = "PriorityStepper"

type CallbackInfo = {
	ticket: number,
	priority: number,
	callback: (number) -> (),
}

export type PriorityStepper = typeof(setmetatable(
	{} :: {
		ticket: number,
		callbackInfos: { CallbackInfo },

		isConnected: boolean,
		signal: Signal.Signal<number>,

		priority: number,
		guid: string,
	},
	PriorityStepperClass
))

function PriorityStepperStatic.new(priority: number)
	local self = setmetatable({}, PriorityStepperClass) :: PriorityStepper

	self.ticket = 0
	self.callbackInfos = {}

	self.isConnected = false
	self.signal = Signal.new()

	self.priority = priority
	self.guid = HttpService:GenerateGUID(false)

	return self
end

function PriorityStepperClass._refreshConnection(self: PriorityStepper)
	local nCallbacks = #self.callbackInfos
	if nCallbacks > 0 and not self.isConnected then
		self.isConnected = true
		RunService:BindToRenderStep(self.guid, self.priority, function(dt)
			for _, info in self.callbackInfos do
				info.callback(dt)
			end
			self.signal:Fire(dt)
		end)
	elseif nCallbacks == 0 and self.isConnected then
		self.isConnected = false
		RunService:UnbindFromRenderStep(self.guid)
	end
end

function PriorityStepperClass.connect(self: PriorityStepper, priority: number, callback: (dt: number) -> ())
	self.ticket = self.ticket + 1

	local info: CallbackInfo = {
		ticket = self.ticket,
		priority = -math.abs(priority),
		callback = callback,
	}

	table.insert(self.callbackInfos, info)
	table.sort(self.callbackInfos, function(a, b)
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		return a.ticket > b.ticket
	end)

	self:_refreshConnection()

	return function()
		local index = table.find(self.callbackInfos, info)
		if index then
			table.remove(self.callbackInfos, index)
			self:_refreshConnection()
		end
	end
end

function PriorityStepperClass.wait(self: PriorityStepper)
	return self.signal:Wait()
end

function PriorityStepperClass.Destroy(self: PriorityStepper)
	table.clear(self.callbackInfos)
	self:_refreshConnection()
	self.signal:Destroy()
end

return {
	render = PriorityStepperStatic.new(Enum.RenderPriority.Camera.Value + 1),
}
