local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local MAX_ATTEMPTS = 3
local RETRY_DELAY = 2

export type Creator = {
	Id: number,
	Type: Enum.AssetCreatorType,
}

export type Output = { { Name: string, AssetId: number } }

export type UploadStatus = "Waiting" | "Queued" | "InProgress" | "Complete" | "Fail" | "Cancel"

export type Phase = "Idle" | "Validating" | "Uploading" | "Complete"

export type TryUpload = (number, string, EditableImage, Creator) -> number?
export type TestCreator = (Creator) -> boolean

export type Params = {
	UploadInfos: { Hooks.EditableImageInfo },
	TryUpload: TryUpload,
	TestCreator: TestCreator,
}

export type Controller = {
	phase: Phase,
	statuses: { UploadStatus },
	assetIds: { [number]: number },
	output: Output,
	groupError: string?,

	start: (creator: Creator) -> (),
	cancel: (index: number) -> (),
	reset: () -> (),
}

local function useUpload(params: Params): Controller
	local infos = params.UploadInfos

	local phase, setPhase = React.useState("Idle" :: Phase)

	local clearThreadRef = React.useRef(nil :: thread?)
	local groupError, setGroupErrorRaw = React.useState(nil :: string?)
	local setGroupError = React.useCallback(function(msg: string?, clearDelay: number?)
		if clearThreadRef.current then
			task.cancel(clearThreadRef.current)
			clearThreadRef.current = nil
		end

		setGroupErrorRaw(msg)
		if clearDelay then
			clearThreadRef.current = task.delay(clearDelay, function()
				setGroupErrorRaw(nil)
			end)
		end
	end, {})

	local statusesBinding, setStatuses = React.useBinding(table.create(#infos, "Waiting" :: UploadStatus))
	local statuses = Hooks.useBindingState(statusesBinding) :: { UploadStatus }

	local assetIdRef = React.useRef({} :: { [number]: number })
	local outputRef = React.useRef({} :: Output)

	-- The orchestrator and per-image worker threads are tracked so a cancel can
	-- abort an in-flight upload, and so closing the window tears everything down.
	local workersRef = React.useRef({} :: { [number]: thread })
	local resultsRef = React.useRef({} :: { [number]: Future.Future<number?> })

	local closeTrove = Hooks.useConstant(function()
		return Trove.new()
	end)

	React.useEffect(function()
		return closeTrove:WrapClean()
	end, {})

	-- Bindings update synchronously, so the orchestrator can read the latest
	-- status mid-run via getValue() without stale-closure issues.
	local function getStatus(index: number): UploadStatus
		return statusesBinding:getValue()[index]
	end

	local function setStatus(index: number, status: UploadStatus)
		local current = statusesBinding:getValue()
		current[index] = status
		setStatuses(table.clone(current))
	end

	local function uploadOne(runTrove: Trove.Trove, index: number, info: Hooks.EditableImageInfo, creator: Creator)
		setStatus(index, "InProgress")

		local result = Future.new() :: Future.Future<number?>
		resultsRef.current[index] = result

		local worker = task.spawn(function()
			local assetId: number? = nil
			for attempt = 1, MAX_ATTEMPTS do
				local success, value = pcall(params.TryUpload, index, info.Name, info.EditableImage, creator)
				if success then
					assetId = value
				else
					warn(value)
				end

				if assetId then
					break
				end

				if attempt < MAX_ATTEMPTS then
					task.wait(RETRY_DELAY * attempt)
				end
			end

			if not result:isCompleted() then
				result:complete(assetId)
			end
		end)
		workersRef.current[index] = worker
		runTrove:Add(worker)

		-- Yields until the worker finishes all attempts or a cancel completes the future.
		local assetId = result:expect()

		workersRef.current[index] = nil
		resultsRef.current[index] = nil

		if getStatus(index) == "Cancel" then
			return
		end

		if assetId then
			assetIdRef.current[index] = assetId
			table.insert(outputRef.current, {
				Name = info.Name,
				AssetId = assetId,
			})
			setStatus(index, "Complete")
		else
			setStatus(index, "Fail")
		end
	end

	local function start(creator: Creator)
		setGroupError(nil)

		closeTrove:Add(task.spawn(function()
			if creator.Type == Enum.AssetCreatorType.Group then
				setPhase("Validating")
				if not params.TestCreator(creator) then
					setGroupError("Could not upload to this group.", 3)
					setPhase("Idle")
					return
				end
			end

			setPhase("Uploading")

			assetIdRef.current = {}
			outputRef.current = {}

			local queued = table.clone(statusesBinding:getValue())
			for index in infos do
				queued[index] = "Queued"
			end
			setStatuses(queued)

			local runTrove = closeTrove:Extend()
			for index, info in infos do
				if getStatus(index) ~= "Cancel" then
					uploadOne(runTrove, index, info, creator)
				end
			end
			runTrove:Destroy()

			setPhase("Complete")
		end))
	end

	local function cancel(index: number)
		local status = getStatus(index)
		if status ~= "Queued" and status ~= "InProgress" then
			return
		end

		setStatus(index, "Cancel")

		local worker = workersRef.current[index]
		if worker and coroutine.status(worker) == "suspended" then
			task.cancel(worker)
		end

		local result = resultsRef.current[index]
		if result and not result:isCompleted() then
			result:complete(nil)
		end
	end

	local function reset()
		closeTrove:Clean()
	end

	return {
		phase = phase :: Phase,
		statuses = statuses,
		assetIds = assetIdRef.current,
		output = outputRef.current,
		groupError = groupError,

		start = start,
		cancel = cancel,
		reset = reset,
	}
end

return useUpload
