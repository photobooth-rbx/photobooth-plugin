local RunService = game:GetService("RunService") :: RunService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Trove = require(pluginRoot.Packages.Trove)

local MeshPartFogBackground = require(script.Parent.Background.MeshPartFogBackground)

local Blackout = {}

local isDisabled = true
local disabledByKey = {}
local blackoutTrove = Trove.new()

-- Private

local function refresh()
	local newIsDisabled = not not next(disabledByKey)

	if newIsDisabled ~= isDisabled then
		isDisabled = newIsDisabled
		blackoutTrove:Clean()

		if not isDisabled then
			local background = MeshPartFogBackground.new(workspace.CurrentCamera)
			background:setColor(Color3.new(0, 0, 0))
			background:setEnabled(true)

			blackoutTrove:Add(function()
				background:Destroy()
			end)

			blackoutTrove:Add(RunService.RenderStepped:Connect(function()
				background:render()
			end))
		end
	end
end

-- Public

function Blackout.isEnabled()
	return not isDisabled
end

function Blackout.setDisabled(key: string, disabled: boolean)
	disabledByKey[key] = if disabled then true else nil
	refresh()
end

--

Blackout.setDisabled("default", true)

return Blackout
