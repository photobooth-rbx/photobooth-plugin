local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Sift = require(pluginRoot.Packages.Sift)

local StateManager = require(pluginRoot.Main.StateManager)
local Types = require(pluginRoot.Main.Bindings.Interface.Types)

local OPEN_GL_WARN =
	"WARN: 'Studio Settings > Rendering > Graphics Mode = OpenGL' is unsupported by Photobooth due to a Roblox bug."

-- Private

local ticket = 0
local ticketLookup = {}

local function wrap<T...>(callback: (T...) -> ...EditableImage)
	ticket = ticket + 1
	local myTicket = ticket

	local function wrapped(...: T...)
		if settings().Rendering.GraphicsMode == Enum.GraphicsMode.OpenGL then
			error(OPEN_GL_WARN, 0)
		end

		return { callback(...) }
	end

	ticketLookup[wrapped] = myTicket
	return wrapped
end

local function getOrder<T...>(exported: { [string]: (T...) -> { EditableImage } })
	local order = Sift.Dictionary.keys(exported)
	table.sort(order, function(a, b)
		return ticketLookup[exported[a]] < ticketLookup[exported[b]]
	end)
	return order
end

-- Public

export type UICaptureTypes = Types.UICaptureTypes
export type ViewportCaptureTypes = Types.ViewportCaptureTypes

local captureTypes = {
	UserInterface = {
		NoBackground = wrap(require(script.CaptureTypes.UserInterface.NoBackground)),
		AlphaMask = wrap(require(script.CaptureTypes.UserInterface.AlphaMask)),
	},
	Viewport = {
		NoSkybox = wrap(require(script.CaptureTypes.Viewport.NoSkybox)),
		Unmodified = wrap(require(script.CaptureTypes.Viewport.Unmodified)),
	},
}

-- selene: allow(empty_if)
if StateManager.temporary:get().isExperimentalMode then
	captureTypes.Viewport.Atmosphere_2026_07_10 = wrap(require(script.CaptureTypes.Viewport.Atmosphere))
end

return {
	UserInterface = {
		Order = getOrder(captureTypes.UserInterface),
		Processors = captureTypes.UserInterface,
	},
	Viewport = {
		Order = getOrder(captureTypes.Viewport),
		Processors = captureTypes.Viewport,
	},
}
