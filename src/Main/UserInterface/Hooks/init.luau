-- Generic
local useUpdate = require(script.Generic.useUpdate)
local useConstant = require(script.Generic.useConstant)
local useMouseDrag = require(script.Generic.useMouseDrag)
local useSelection = require(script.Generic.useSelection)
local useRefProperty = require(script.Generic.useRefProperty)
local useBindingState = require(script.Generic.useBindingState)

-- Animation
local useShake = require(script.Animation.useShake)

-- Plugin
local usePlugin = require(script.Plugin.usePlugin)
local useIsStory = require(script.Plugin.useIsStory)
local usePluginMenu = require(script.Plugin.usePluginMenu)
local useDockButton = require(script.Plugin.useDockButton)
local useIsLocalPlugin = require(script.Plugin.useIsLocalPlugin)
local useHasCreateAssetPermission = require(script.Plugin.useHasCreateAssetPermission)

-- Photobooth specific
local useLatestVersion = require(script.Photobooth.useLatestVersion)
local useEditableImageInfos = require(script.Photobooth.useEditableImageInfos)

export type EditableImageInfo = useEditableImageInfos.EditableImageInfo

-- Exported

return {
	useUpdate = useUpdate,
	useConstant = useConstant,
	useMouseDrag = useMouseDrag,
	useSelection = useSelection,
	useRefProperty = useRefProperty,
	useBindingState = useBindingState,

	useShake = useShake,

	usePlugin = usePlugin,
	useIsStory = useIsStory,
	usePluginMenu = usePluginMenu,
	useDockButton = useDockButton,
	useIsLocalPlugin = useIsLocalPlugin,
	useHasCreateAssetPermission = useHasCreateAssetPermission,

	useLatestVersion = useLatestVersion,
	useEditableImageInfos = useEditableImageInfos,
}
