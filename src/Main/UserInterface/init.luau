local AutoCapture = require(script.Apps.AutoCapture)
local ViewportApp = require(script.Apps.Viewport)
local CaptureUIApp = require(script.Apps.CaptureUI)
local GalleryApp = require(script.Apps.Gallery)
local PostProcessing = require(script.Apps.PostProcessing)

local UserInterface = {}

function UserInterface.mountApps(plugin: Plugin, toolbar: PluginToolbar)
	ViewportApp.mount(plugin, toolbar)
	CaptureUIApp.mount(plugin, toolbar)
	GalleryApp.mount(plugin, toolbar)
	AutoCapture.mount(plugin, toolbar)
	PostProcessing.mount(plugin, toolbar)
end

UserInterface.requestRect = ViewportApp.requestRect
UserInterface.getRectRequestByGuid = ViewportApp.getRectRequestByGuid

return UserInterface
