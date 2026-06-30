local pluginRoot = script:FindFirstAncestor("PluginRoot")
local gt = require(pluginRoot.Packages.GreenTea)

local UserInterface = require(pluginRoot.Main.UserInterface)

local gtOptions = gt.table({
	rect = gt.opt(gt.Rect()),
	scale = gt.opt(gt.Vector2()),
})

-- stylua: ignore
local typechecker = gt.fn(
	gt.args(gtOptions),
	gt.returns(gt.opt(gt.Rect()))
)

local function callback(options: typeof(gtOptions))
	local request = UserInterface.rectRequest(options.rect, options.scale)
	return request.expect()
end

return {
	identifier = "requestRect",
	callback = gt.wrapFn(typechecker, callback),
}
