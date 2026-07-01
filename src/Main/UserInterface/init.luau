local ViewportApp = require(script.Apps.Viewport)
local CaptureUIApp = require(script.Apps.CaptureUI)
local GalleryApp = require(script.Apps.Gallery)

local UserInterface = {}

function UserInterface.mountApps(plugin: Plugin, toolbar: PluginToolbar)
	ViewportApp.mount(plugin, toolbar)
	CaptureUIApp.mount(plugin, toolbar)
	GalleryApp.mount(plugin, toolbar)
end

UserInterface.rectRequest = ViewportApp.requestRect
UserInterface.getRectRequestByGuid = ViewportApp.getRectRequestByGuid

return UserInterface
