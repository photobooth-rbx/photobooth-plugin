local pluginRoot = script:FindFirstAncestor("PluginRoot")
local gt = require(pluginRoot.Packages.GreenTea)

local StateManager = require(pluginRoot.Main.StateManager)

-- stylua: ignore
local typechecker = gt.fn(
	gt.args(),
	gt.returns(gt.Vector2())
)

local function callback()
	return StateManager.temporary:get().scaleOS
end

return {
	identifier = "getOSScale",
	callback = gt.wrapFn(typechecker, callback),
}
