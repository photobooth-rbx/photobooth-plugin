<!-- Links -->

[links/roblox]: https://create.roblox.com/store/asset/82716202460157
[links/itch]: https://egomoose.itch.io/rbx-photobooth-plugin
[links/discord]: https://discord.gg/VgxVYZHV3N
[links/devforum]: https://devforum.roblox.com/t/3401720
[links/community]: https://www.roblox.com/communities/944974637
[links/gltf-site]: https://photobooth-rbx.github.io/photobooth-plugin-site/
[links/gltf-beta]: https://devforum.roblox.com/t/gltf-export-beta-available-now/3905928

<!-- Badges -->

[badges/roblox]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/roblox_dev.svg
[badges/itch]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/itch.svg
[badges/discord]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/discord.svg
[badges/download]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/download.svg

## Developer Request

This project is AGPL-3.0. If you modify this plugin and use it in a public-facing project, you are obligated to make your modified source code available. While I can't stop you from using modifications privately I strongly encourage you to contribute improvements back. If you've optimized something or added a feature that helps you or your team, please consider a PR so everyone benefits.

This plugin is still being sold for money as a pre-built rbxm on the Creator Store and itch.io, offering convenience for those unfamiliar with building Roblox projects and auto-updates for Creator Store users. I strongly request that you do not publicly distribute any builds as this is my primary way of earning money off the project.

While the source is open, building and maintaining this tool takes significant time. The best way to ensure this plugin remains updated and compatible with the latest Roblox engine changes is to purchase the pre-built version on the Creator Store or Itch. Thanks!

# Photobooth Plugin

![](docs/assets/readme/general/header.png)

Photobooth is a plugin that allows you to capture images of the workspace or UI elements entirely in Roblox Studio. It features the ability to remove skyboxes/backgrounds from images, tools to batch capture many images at once, post-processing effects, and bindings that let developers write their own capture workflows.

Results are output as editable images stored on a mesh part's texture.

[![Get it on Roblox][badges/roblox]][links/roblox] [![Get it on Itch.io][badges/itch]][links/itch] [![Join us on Discord][badges/discord]][links/discord]

[Devforum post][links/devforum] · [Community][links/community]




<details>
<summary>Examples</summary>

![](docs/assets/readme/examples/RedDress.png)
![](docs/assets/readme/examples/Candle.png)
![](docs/assets/readme/examples/NeoVeg.png)
![](docs/assets/readme/examples/Spaceship.png)
![](docs/assets/readme/examples/Tree.png)
</details>
</br>

<video src="docs/assets/readme/creator%20store/trailer.mp4" controls></video>

## Table of Contents

- [Limitations](#limitations)
- [OS Scaling](#os-scaling)
- [Capturing](#capturing)
  - [Cropped Viewport Captures](#cropped-viewport-captures)
  - [Full Viewport Captures](#full-viewport-captures)
  - [UI Captures](#ui-captures)
- [Auto Capture](#auto-capture)
- [Post-Processing Effects](#post-processing-effects)
- [Saving Captures as PNGs](#saving-captures-as-pngs)
  - [glTF Exports](#gltf-exports)
- [Uploading](#uploading)
- [Advanced](#advanced)
  - [Experimental Mode](#experimental-mode)
  - [Bindings](#bindings)
- [Support & Community](#support--community)
- [License](#license)



## Limitations

Photobooth has a couple of limitations that are worth noting. For most users these will likely not be of significant impact, but they're listed here so people can see them before getting the plugin.

- Photobooth can only be used during **edit mode** in Studio. It cannot capture anything during a Studio play session.
- The viewport must be **visible** when capturing. You cannot tab out of Studio or switch to the script editor while a capture is in progress.
- `Studio Settings > Rendering > Graphics Mode = OpenGL` is **unsupported** (this is a Roblox bug). The plugin will warn you if you attempt to capture in this mode.
- `Studio Settings > Rendering > Graphics Mode = Vulkan` is supported, but some users experience a bug where emulators that match their display resolution force them into fullscreen and won't allow them to take captures.
- **Atmosphere** is supported. **Fog is not** — if you attempt to capture with fog it will hide itself.
- Anything that cannot be frozen in place on screen is not supported. For example:
  - Terrain grass.
  - Force-field material with a moving texture.
- Retro color grading is highly recommended for best results, but not mandatory.

> **Warning:** This plugin will cause the screen to flash when removing skyboxes. Those with photosensitive epilepsy are advised caution when using this plugin.

## OS Scaling

With the advent of high resolution monitors many computers use scaling options built into their operating system to ensure that applications rendered on screen are not too small. Roblox, however, always captures in full resolution, leading to a number of UX problems.

Photobooth will attempt to function with your device's os scale in mind, but for the highest quality image it is strongly recommended to use your monitor's true resolution — i.e. scale 100% and the display resolution that matches your monitor.

![](docs/assets/readme/general/scale150.png)

<details>
<summary>Or on Mac</summary>
![](docs/assets/readme/general/scale_mac.png)
</details>

## Capturing

### Cropped Viewport Captures

In cropped capture mode you can draw a rectangle over the viewport to capture a specific region. This mode has a `2048 x 2048` limit. For anything larger, use full viewport captures.

While in cropped capture mode you can hold the shift key to drag your capture rectangle around the viewport and resize non-symmetrically. You can also hold the control / command key to maintain aspect ratio when sizing from the corners.

### Full Viewport Captures

It is possible to circumvent the cropped-mode limit of `2048 x 2048 by capturing the entire viewport window. You can toggle to full viewport capture mode from the action bar or in the settings menu.

To set an arbitrary resolution you can either resize your viewport (not recommended) or take advantage of custom device resolutions in the emulator.

![](docs/assets/readme/general/emulator.jpg)

When photobooth captures in the emulator it requires you use the "actual resolution" mode in the emulator. If you attempt a capture while not in this mode photobooth will briefly switch to it and back for the duration of the capture.

> **Note:** Full viewport captures will result in images with their dimensions as `viewportSize * osScale`. It is highly recommended to adjust your display settings such that OS scale is `(1, 1)` when using full viewport captures.

### UI Captures

In addition to the workspace, Photobooth can capture UI elements. This is useful for flattening complex GUIs into a single image. Select a `GuiObject` in the explorer and then select the UI button on the plugin toolbar and the capture will commence.

## Auto Capture

Auto Capture lets you batch capture many targets in sequence rather than framing each one by hand.

By default the camera frames the bounding box of the target. To capture from a non-centered offset, add an `Attachment` named `PhotoboothAutoCapturePivot` as a child of the target — the capture will pivot around it. A field-of-view slider is also available in the properties list.

## Post-Processing Effects

Photobooth includes post-processing tools that can be applied to your captures after they're taken, letting you tune the final result without re-capturing.

## Saving Captures as PNGs

If you want to save any of the plugin captures to your computer, right-click the exported mesh part and select **"Export as Obj"**. This will prompt you to export the mesh in `.obj` format, which includes the texture as a `.png`. Both the `.obj` and `.mtl` files can be discarded.

To export many images at the same time first select all the mesh parts at you want, and then export that selection.

<img src="docs/assets/readme/general/exportA.png" height=400> <img src="docs/assets/readme/general/exportB.png" height=400>

### glTF Exports

Alternatively, you can export your Photobooth selection in the [glTF format][links/gltf-beta]. This may be preferable, as many users have reported that exporting as an `.obj` can sometimes not work in studio due to Roblox bugs.

To extract the pngs from a glTF file you'll need an additional tool. For convenience I've created a [website][links/gltf-site] where you can drag and drop the export and get the resulting pngs.

## Uploading

Photobooth also offers the ability to upload your captures directly to roblox to either your account or a group you have permission to upload images to.

Currently this feature is disabled by default because it requires that the CreateAssetAsync beta is enabled and the plugin is locally installed. You can read more about that from Roblox [here.](https://devforum.roblox.com/t/3294134)

If you really find yourself needing the uploader feature I've created a standalone uploader plugin that you can install locally.

[![Download Uploader][badges/download]][links/roblox]

<details>
<summary>How to install</summary>

1. Take the rbxm and put it in "Plugins > Plugin Folder".
2. Open "File > Studio Betas" and enable the "CreateAssetAsync Lua API" beta.
3. Restart studio.
</details>
<br/>

You can also write your own code to upload editable images if you don’t want to install the local plugin:

<details>
<summary>Sample Code</summary>

```luau
local ATTRIBUTE_NAME = "UploadResult"

local AssetService = game:GetService("AssetService")
local SelectionService = game:GetService("Selection")

for _, selected in SelectionService:Get() do
	if selected:IsA("MeshPart") and not selected:GetAttribute(ATTRIBUTE_NAME) then
		local content = selected.TextureContent
		local object = content and content.Object

		if object and object:IsA("EditableImage") then
			local result, value = AssetService:CreateAssetAsync(object, Enum.AssetType.Image, {
				Name = selected.Name,
				Description = "",
				IsPackage = false,
			})

			if result == Enum.CreateAssetResult.Success then
				selected:SetAttribute(ATTRIBUTE_NAME, `rbxassetid://{value}`)
			end
		end
	end
end
```
</details>
<br/>

## Advanced

### Experimental Mode

As of v1.2.0, Photobooth supports a setting called **experimental mode**. Enabling it requires restarting Studio and is not available during team create sessions.

Experimental mode is a way to provide speculative features to the public without any guarantee that the behavior will remain supported in the future. If you enable this mode, be aware that any behavior it exposes may be removed and should not be relied on.

### Bindings

This plugin can be used for automation purposes. An example use case might be capturing icons for all the inventory items in your game, thereby allowing you to avoid using viewport frames, which are more expensive than traditional images.

To use this feature, open the viewer and in the settings menu toggle **"Bindings"** to `true`.

![](docs/assets/readme/general/bindings_enabled.png)

Roblox may prompt you for script injection permissions.

![](docs/assets/readme/general/script_injection.png)

This creates a `ModuleScript` underneath `ServerStorage` which provides a typed interface for building automated capture workflows. A couple of common template workflows are included to get you started.

```luau
local Photobooth = require(game.ServerStorage.Photobooth.Bindings)

local capture = Photobooth.captureViewport({
	rect = Rect.new(0, 0, 300, 300),
	type = "NoSkybox",
})
capture.Name = "Example"
capture.Parent = game.StarterGui
```

Fullscreen captures can be made with bindings by passing a rect that represents the viewport:

```luau
local viewportSize = workspace.CurrentCamera.ViewportSize
local capture = Photobooth.captureViewport({
	rect = Rect.new(Vector2.zero, viewportSize),
	type = "NoSkybox",
})
```

Captures should be parented as a descendant of `StarterGui`. This ensures they can be properly exported as pngs.

> **OS scaling note:** For the highest quality image when using bindings, it is strongly recommended to use your monitor's true resolution (scale 100%). See [OS Scaling](#os-scaling).

## Support & Community

- [**Devforum post**][links/devforum] — primary support channel for technical issues.
- [**Discord**][links/discord] — chat with the community.
- [**Roblox Community**][links/community]

## License

This project is licensed under **AGPL-3.0**. See [Developer Request](#developer-request) for what that means in practice.
