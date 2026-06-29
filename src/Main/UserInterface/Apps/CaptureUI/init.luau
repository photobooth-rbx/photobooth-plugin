local StarterGui = game:GetService("StarterGui")
local SelectionService = game:GetService("Selection")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StateManager = require(pluginRoot.Main.StateManager)
local Captures = require(pluginRoot.Main.Photo.Captures)
local Photo = require(pluginRoot.Main.Photo)

local uiRoot = script:FindFirstAncestor("UserInterface")
local ToolbarButton = require(uiRoot.Helpers.ToolbarButton)

local CaptureUIApp = {}

function CaptureUIApp.mount(plugin: Plugin, toolbar: PluginToolbar)
	-- stylua: ignore
	local captureButton = toolbar:CreateButton(
		"egomoose_photobooth_capture_ui_button",
		"Capture UI images",
		"", "UI"
	)

	ToolbarButton.listen(captureButton, "ui-plugin-button")

	local function getSelectedGuiObject()
		local selection = SelectionService:Get()
		local singleSelection = if #selection == 1 then selection[1] else nil
		return if singleSelection and singleSelection:IsA("GuiObject") then singleSelection else nil
	end

	local selection: GuiObject?
	local function refreshSelection()
		selection = getSelectedGuiObject()
		captureButton.Enabled = not not selection
	end

	refreshSelection()
	local selectionChangedConnection = SelectionService.SelectionChanged:Connect(function()
		refreshSelection()
	end)

	local clickConnection = captureButton.Click:Connect(function()
		if selection and not StateManager.temporary:get().isCapturing then
			local captureTypeIndex = StateManager.temporary:get().uiCaptureTypeIndex
			local captureType = assert(Captures.UserInterface.Order[captureTypeIndex], "No capture type found")

			local captures = Photo.captureUI({
				subject = selection,
				type = captureType :: Captures.UICaptureTypes,
			})

			local exported = Photo.export(captures, StarterGui)
			SelectionService:Set(exported :: any)
		end
	end)

	plugin.Unloading:Connect(function()
		selectionChangedConnection:Disconnect()
		clickConnection:Disconnect()
	end)
end

return CaptureUIApp
