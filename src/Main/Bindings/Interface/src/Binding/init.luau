local Binding = {}
local bindable = assert(script:FindFirstChild("Bindable") :: BindableFunction?)

-- Private

local function isConnected()
	local pcallSuccess, invokeSuccess, result
	local thread = task.spawn(function()
		pcallSuccess = pcall(function()
			invokeSuccess, result = bindable:Invoke("isConnected")
		end)
	end)

	local value = false
	if coroutine.status(thread) == "dead" then
		local closeSuccess, _errorMessage = coroutine.close(thread)
		if closeSuccess and pcallSuccess and invokeSuccess then
			value = (result == true)
		end
	end

	return value
end

local function tryConnecting()
	if not isConnected() then
		local camera = game:GetService("CaptureService"):FindFirstChild("Photobooth") :: Camera?
		local connectBinding = camera and camera:FindFirstChild("ConnectBinding") :: BindableFunction?

		if connectBinding then
			pcall(function()
				connectBinding:Invoke(script.Parent)
			end)
		end
	end
end

-- Public

function Binding.isConnected()
	tryConnecting()
	return isConnected()
end

function Binding.invoke<T..., U...>(identifier: string, ...: T...): U...
	tryConnecting()

	local invokeResults = table.pack(pcall(bindable.Invoke, bindable, identifier, ...))

	local invokeSuccess = invokeResults[1]
	if not invokeSuccess then
		error(invokeResults[2], 2)
	end

	local success = invokeResults[2]
	if not success then
		error(invokeResults[3], 2)
	end

	return table.unpack(invokeResults, 3, invokeResults.n)
end

return Binding
