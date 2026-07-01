local HttpService = game:GetService("HttpService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local gt = require(pluginRoot.Packages.GreenTea)

local UserInterface = require(pluginRoot.Main.UserInterface)

local strLimited = gt.string({ bytes = 200 })

local requestOptions = gt.table({
	type = gt.literal("request"),
	rect = gt.opt(gt.Rect()),
	scale = gt.opt(gt.Vector2()),
})

local expectOptions = gt.table({
	type = gt.literal("expect"),
	guid = strLimited,
})

local cancelOptions = gt.table({
	type = gt.literal("cancel"),
	guid = strLimited,
})

local gtOptions = gt.union(requestOptions, expectOptions, cancelOptions)

-- stylua: ignore
local typechecker = gt.fn(
	gt.args(gtOptions),
	gt.returns(gt.opt(gt.union(strLimited, gt.Rect())))
)

local function callback(options: typeof(gtOptions))
	if options.type == "request" then
		local castedOptions = options :: typeof(requestOptions)
		local guid = HttpService:GenerateGUID(false)
		UserInterface.rectRequest(guid, castedOptions.rect, castedOptions.scale)
		return guid
	end

	local castedOptions = options :: typeof(expectOptions) | typeof(cancelOptions)
	local control = UserInterface.getRectRequestByGuid(castedOptions.guid)
	if control then
		if options.type == "expect" then
			return control.expect()
		elseif options.type == "cancel" then
			return control.cancel()
		end
	end

	return nil
end

return {
	identifier = "requestRect",
	callback = gt.wrapFn(typechecker, callback),
}
