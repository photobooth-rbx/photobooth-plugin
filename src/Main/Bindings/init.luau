local CaptureService = game:GetService("CaptureService") :: CaptureService
local ServerStorage = game:GetService("ServerStorage") :: ServerStorage

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)

local StateManager = require(pluginRoot.Main.StateManager)

local Bindings = {}
local trove = Trove.new()

-- Private

type Invocation = {
	identifier: string,
	callback: (...any) -> ...any,
}

local invocationByIdentifier = {}
for _, invocationModule in script.Invocations:GetDescendants() do
	if invocationModule:IsA("ModuleScript") then
		local invocation = require(invocationModule) :: Invocation
		assert(
			not invocationByIdentifier[invocation.identifier],
			`Duplicate invocation identifier: {invocation.identifier}`
		)
		invocationByIdentifier[invocation.identifier] = invocation
	end
end

local function connectBindings(plugin: Plugin, interface: Instance)
	local binding = interface:FindFirstChild("Binding") :: ModuleScript?
	local bindable = binding and binding:FindFirstChild("Bindable") :: BindableFunction?

	if bindable then
		bindable.OnInvoke = function(identifier: string, ...: any)
			local resultFuture = Future.new() :: Future.Future<boolean, string?, boolean, { any }>
			local connection = plugin.Unloading:Connect(function()
				if not resultFuture:isCompleted() then
					resultFuture:complete(false, "Plugin unloaded.", true, {})
				end
			end)

			local packedArgs = table.pack(...)
			local thread = task.spawn(function()
				local results = {}
				local success, err = pcall(function()
					local invocation =
						assert(invocationByIdentifier[identifier], `No invocation found for: {identifier}`)
					results = table.pack(invocation.callback(table.unpack(packedArgs)))
				end)

				if not resultFuture:isCompleted() then
					resultFuture:complete(success, err, false, results)
				end
			end)

			local success, err, unloaded, results = resultFuture:expect()
			connection:Disconnect()
			if unloaded then
				task.cancel(thread)
			end

			if success then
				return true, table.unpack(results)
			end

			return false, err
		end

		plugin.Unloading:Connect(function()
			bindable.OnInvoke = function() end
		end)
	end
end

local function createBindings(plugin: Plugin)
	local interface = script.Interface:Clone()
	interface.Name = "Bindings"

	local descendants = interface:GetDescendants()
	table.insert(descendants, interface)

	for _, descendant in descendants do
		trove:Add(descendant)
	end

	connectBindings(plugin, interface)

	local camera = Instance.new("Camera")
	camera.Name = "Photobooth"
	camera.Archivable = false
	trove:Add(camera)

	interface.Parent = camera :: any
	return camera
end

local isEnabled = false
local function setEnabled(plugin: Plugin, enabled: boolean)
	if isEnabled ~= enabled then
		isEnabled = enabled
		trove:Clean()

		if isEnabled then
			local interface = createBindings(plugin)
			interface.Parent = ServerStorage
		end
	end
end

-- Public

function Bindings.setup(plugin: Plugin)
	setEnabled(plugin, StateManager.settings:get().bindingsEnabled)
	local connection = StateManager.settings:onChanged(function()
		setEnabled(plugin, StateManager.settings:get().bindingsEnabled)
	end)

	local camera = Instance.new("Camera")
	camera.Name = "Photobooth"
	camera.Archivable = false
	camera.Parent = CaptureService

	local connectBinding = Instance.new("BindableFunction")
	connectBinding.Archivable = false
	connectBinding.Name = "ConnectBinding"
	connectBinding.OnInvoke = function(instance: Instance)
		if instance:HasTag("Photobooth_Bindings") then
			connectBindings(plugin, instance)
		end
	end
	connectBinding.Parent = camera

	plugin.Unloading:Connect(function()
		connectBinding:Destroy()
		camera:Destroy()
		connection:Disconnect()
		setEnabled(plugin, false)
	end)
end

--

return Bindings
