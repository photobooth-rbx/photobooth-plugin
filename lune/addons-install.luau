local fs = require("@lune/fs")
local net = require("@lune/net")
local roblox = require("@lune/roblox")

local RBXMS: { [string]: string } = {
	["auto_capture+post_processing"] = "https://github.com/photobooth-rbx/photobooth-plugin-addons/releases/download/v0.1.0-pre.16/photobooth-addons-v0.1.0-pre.16.rbxm",
}

if fs.isDir("Addons") then
	fs.removeDir("Addons")
end

fs.writeDir("Addons")

for name, link in RBXMS do
	local result = net.request(link)
	if result.ok then
		local addonRoot = roblox.deserializeModel(result.body)[1]
		local runner = addonRoot:FindFirstChild("Runner")
		if runner then
			runner:Destroy()
		end

		local model = roblox.Instance.new("Model")
		model.Name = name
		addonRoot.Parent = model

		fs.writeFile(`Addons/{name}.rbxm`, roblox.serializeModel({ model }))
	end
end
