local RunService = game:GetService("RunService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioMode = require(pluginRoot.Utilities.StudioMode)
local Constants = require(pluginRoot.Constants)

local StateManager = require(pluginRoot.Main.StateManager)

local Plugin = {}

local DISPLAY_SCALE_WARNING = false

-- Private

local function waitForViewportSettled(minTime: number)
	local timestamp = os.clock()
	local viewportSize = workspace.CurrentCamera.ViewportSize

	while os.clock() - timestamp < minTime do
		local newViewportSize = workspace.CurrentCamera.ViewportSize
		if newViewportSize ~= viewportSize then
			viewportSize = newViewportSize
			timestamp = os.clock()
		end
		RunService.Heartbeat:Wait()
	end
end

local function updateScaleOS()
	local Screenshot = require(pluginRoot.Main.Photo.Captures.Screenshot)
	local SceneControl = require(pluginRoot.Main.Photo.SceneControl)

	local _isEmulator, undoEmulator = SceneControl.emulatorEnforcement()
	local scale = Screenshot.calculateScaleOS()
	undoEmulator()

	StateManager.temporary:update()(function(state)
		state.scaleOS = scale
		return state
	end)

	if DISPLAY_SCALE_WARNING and not (scale.X == 1 and scale.Y == 1) then
		warn(table.concat({
			"",
			"Photobooth - OS scaling detected!",
			`The plugin will attempt to adjust for the following scale factor: ({scale.X}, {scale.Y})`,
			"For optimal results please use a resolution that matches your display and restart studio.",
		}, "\n"))
	end
end

local function updateExperimentalMode()
	local experimentalModeEnabled = StateManager.settings:get().experimentalModeEnabled
	if not Constants.AllowExperimentalMode then
		experimentalModeEnabled = false
	end

	StateManager.settings:update()(function(state)
		state.experimentalModeEnabled = experimentalModeEnabled
		return state
	end)

	StateManager.temporary:update()(function(state)
		if Constants.AllowExperimentalMode then
			-- we set this one time at session start so that it remains constant for the entire session
			-- you can toggle this value in the settings, but then need to restart photobooth for changes to occur
			if StudioMode.isTeamCreate() then
				state.isExperimentalMode = false
			else
				state.isExperimentalMode = experimentalModeEnabled
			end
		else
			state.isExperimentalMode = false
		end
		return state
	end)
end

-- Public

function Plugin.build(plugin: Plugin)
	if not (RunService:IsStudio() and RunService:IsEdit()) then
		return
	end

	StateManager.initPluginSaving(plugin)
	updateExperimentalMode()

	-- load the modules after the state has been setup
	local UserInterface = require(pluginRoot.Main.UserInterface)
	local Bindings = require(pluginRoot.Main.Bindings)

	task.spawn(function()
		-- the viewport size must remain unchanged for X seconds
		waitForViewportSettled(1)
		updateScaleOS()
	end)

	local toolbar = plugin:CreateToolbar("Photobooth")
	UserInterface.mountApps(plugin, toolbar)
	Bindings.setup(plugin)

	-- addons
	for _, addonModel in pluginRoot.Addons:GetChildren() do
		local addonRoot = addonModel:FindFirstChild("PluginRoot")
		local builds = addonRoot and addonRoot:FindFirstChild("Builds")
		local addonBuild = builds and builds:FindFirstChild("Addon")

		if addonBuild and addonBuild:IsA("ModuleScript") then
			local addon = require(addonBuild) :: any
			addon.build(plugin, toolbar)
		end
	end
end

return Plugin
