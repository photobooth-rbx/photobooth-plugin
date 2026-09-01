local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)

local StateManager = require(pluginRoot.Main.StateManager)
local SignedVectorField = require(pluginRoot.Main.Photo.Tools.SignedVectorField)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Effects = require(postProcessingRoot.Effects)

local Presets = require(script.Presets)
local LayerComposer = require(script.LayerComposer)

-- Types

-- A composited render output, one per visible layer (its effects + base image
-- flattened and color-graded into a single image), consumed by the ImageViewer and
-- LayerComposer.
export type RenderLayer = LayerComposer.Layer

-- A parsed 3D `.cube` LUT applied to a layer's composited result. Held live-only: it is
-- never serialized into presets or the plugin save (see `copyLayers`).
export type Lut = LayerComposer.Lut

export type Effect<Properties> = {
	kind: string,
	name: string,
	index: number,
	renderTicket: number,
	properties: Properties,
}

export type LayerEffect = {
	id: string,
	isVisible: boolean,
	effect: Effect<any>,
}

-- The editable model: a layer is an image source (carrying its own offset/tint/
-- transparency, plus a color grade applied to its whole composited output) that owns
-- an ordered list of sub-effects.
export type Layer = {
	id: string,
	name: string,
	isVisible: boolean,
	isExpanded: boolean,
	showBaseImage: boolean,
	offset: Vector2,
	tintColor: Color3,
	transparency: number,
	brightness: number,
	contrast: number,
	saturation: number,
	hue: number,
	lut: Lut?,
	effects: { LayerEffect },
}

-- A saved snapshot of a whole layer stack. Built-in presets are flagged `isDefault` and
-- cannot be deleted.
export type Preset = {
	id: string,
	name: string,
	isDefault: boolean,
	layers: { Layer },
}

-- Helpers

local idCounter = 0
local function nextId(): string
	idCounter += 1
	return tostring(idCounter)
end

local function indexOf<T>(list: { T }, predicate: (T) -> boolean): number?
	for i, value in list do
		if predicate(value) then
			return i
		end
	end
	return nil
end

local function cloneLayer(layer: Layer): Layer
	local clone = table.clone(layer)
	clone.effects = table.clone(layer.effects)
	return clone
end

local function makeLayer(name: string): Layer
	return {
		id = nextId(),
		name = name,
		isVisible = true,
		isExpanded = true,
		showBaseImage = true,
		offset = Vector2.zero,
		tintColor = Color3.new(1, 1, 1),
		transparency = 0,
		brightness = 0,
		contrast = 0,
		saturation = 0,
		hue = 0,
		effects = {},
	}
end

local function makeLayerEffect(kind: string, name: string): LayerEffect
	local entry = assert(Effects.getByKind(kind))
	return {
		id = nextId(),
		isVisible = true,
		effect = {
			kind = kind,
			name = name,
			index = 0,
			renderTicket = 0,
			properties = entry.create(),
		},
	}
end

-- Deep copies a layer stack with fresh ids, so snapshots and applied presets are
-- fully independent of (and from) the live model.
local function copyLayerEffect(item: LayerEffect): LayerEffect
	local effect = table.clone(item.effect)
	effect.properties = table.clone(item.effect.properties)
	return {
		id = nextId(),
		isVisible = item.isVisible,
		effect = effect,
	}
end

local function copyLayers(layers: { Layer }): { Layer }
	local out: { Layer } = {}
	for _, layer in layers do
		local clone = table.clone(layer)
		clone.id = nextId()
		-- LUTs are live-only: drop them from snapshots so presets (and the Bufferized plugin
		-- save built from them) never carry the large LUT buffer. Re-import to reapply.
		clone.lut = nil
		clone.effects = {}
		for _, item in layer.effects do
			table.insert(clone.effects, copyLayerEffect(item))
		end
		table.insert(out, clone)
	end
	return out
end

local function buildDefaultPreset(spec: Presets.PresetSpec)
	local layers: { Layer } = {}
	for _, layerSpec in spec.layers do
		local layer = makeLayer(layerSpec.name or "Image")
		-- `or` is safe here because the optional numeric fields default to non-falsy values
		-- (0 is truthy in Luau), so an explicit 0/negative override is still honoured.
		layer.tintColor = layerSpec.tintColor or layer.tintColor
		layer.transparency = layerSpec.transparency or layer.transparency
		layer.brightness = layerSpec.brightness or layer.brightness
		layer.contrast = layerSpec.contrast or layer.contrast
		layer.saturation = layerSpec.saturation or layer.saturation
		layer.hue = layerSpec.hue or layer.hue

		local effectSpecs: { Presets.EffectSpec } = layerSpec.effects or {}
		for _, effectSpec in effectSpecs do
			local item = makeLayerEffect(effectSpec.kind, effectSpec.name or effectSpec.kind)
			local overrides: { [string]: any } = effectSpec.properties or {}
			for key, value in overrides do
				item.effect.properties[key] = value
			end
			table.insert(layer.effects, item)
		end

		table.insert(layers, layer)
	end

	return {
		id = nextId(),
		name = spec.name,
		isDefault = true,
		layers = layers,
	} :: Preset
end

local function buildDefaultPresets()
	local presets: { Preset } = {}
	for _, presetEntry in Presets.get() do
		table.insert(presets, buildDefaultPreset(presetEntry.spec))
	end
	return presets
end

-- Returns a new layers array with `fn` applied to the layer matching `layerId`.
local function mapLayer(layers: { Layer }, layerId: string, fn: (Layer) -> Layer): { Layer }
	local out = table.clone(layers)
	for i, layer in out do
		if layer.id == layerId then
			out[i] = fn(layer)
			break
		end
	end
	return out
end

-- Returns a new layers array with `fn` applied to the effect matching the ids.
local function mapEffect(
	layers: { Layer },
	layerId: string,
	effectId: string,
	fn: (LayerEffect) -> LayerEffect
): { Layer }
	return mapLayer(layers, layerId, function(layer)
		local clone = cloneLayer(layer)
		local i = indexOf(clone.effects, function(item)
			return item.id == effectId
		end)
		if i then
			clone.effects[i] = fn(clone.effects[i])
		end
		return clone
	end)
end

-- Class

local PostProcessingControllerStatic = {}

local PostProcessingControllerClass = {}
PostProcessingControllerClass.__index = PostProcessingControllerClass
PostProcessingControllerClass.ClassName = "PostProcessingController"

export type PostProcessingController = typeof(setmetatable(
	{} :: {
		editImage: EditableImage?,
		imageTrove: Trove.Trove,

		observableThumbnails: ObservableValue.ObservableValue<{ [string]: { RenderLayer } }>,
		observableLayers: ObservableValue.ObservableValue<{ Layer }>,
		observableComposited: ObservableValue.ObservableValue<{ RenderLayer }>,
		observablePresets: ObservableValue.ObservableValue<{ Preset }>,
	},
	PostProcessingControllerClass
))

function PostProcessingControllerStatic.new()
	local self = setmetatable({}, PostProcessingControllerClass) :: PostProcessingController

	self.editImage = nil
	self.imageTrove = Trove.new()

	self.observableThumbnails = ObservableValue.new({} :: { [string]: { RenderLayer } })
	self.observableLayers = ObservableValue.new({ makeLayer("Image") })
	self.observableComposited = ObservableValue.new({})

	local presets = buildDefaultPresets()
	for _, savedPreset in StateManager.postProcessingPresets:get() do
		table.insert(presets, savedPreset)
	end

	self.observablePresets = ObservableValue.new(presets)

	return self
end

function PostProcessingControllerStatic.loadingLayer(editImage: EditableImage)
	local layer: RenderLayer = {
		name = "Image",
		editImage = editImage,
		offset = Vector2.zero,
		tintColor = Color3.new(1, 1, 1),
		transparency = 0,
	}

	return layer
end

-- Editable model

function PostProcessingControllerClass.useLayers(self: PostProcessingController)
	return self.observableLayers:use()
end

function PostProcessingControllerClass.addLayer(self: PostProcessingController, name: string?): string
	local layer = makeLayer(name or "Layer")
	self.observableLayers:update()(function(layers)
		local out = table.clone(layers)
		table.insert(out, layer)
		return out
	end)
	return layer.id
end

function PostProcessingControllerClass.addEffect(
	self: PostProcessingController,
	layerId: string,
	kind: string,
	name: string
): string
	local item = makeLayerEffect(kind, name)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.isExpanded = true
			table.insert(clone.effects, item)
			return clone
		end)
	end)
	return item.id
end

function PostProcessingControllerClass.removeLayer(self: PostProcessingController, layerId: string)
	self.observableLayers:update()(function(layers)
		local out = table.clone(layers)
		local i = indexOf(out, function(layer)
			return layer.id == layerId
		end)
		if i then
			table.remove(out, i)
		end
		return out
	end)
end

function PostProcessingControllerClass.removeEffect(self: PostProcessingController, layerId: string, effectId: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			local i = indexOf(clone.effects, function(item)
				return item.id == effectId
			end)
			if i then
				table.remove(clone.effects, i)
			end
			return clone
		end)
	end)
end

function PostProcessingControllerClass.moveLayer(self: PostProcessingController, layerId: string, step: number)
	self.observableLayers:update()(function(layers)
		local out = table.clone(layers)
		local i = indexOf(out, function(layer)
			return layer.id == layerId
		end)
		local j = if i then i + step else nil
		if i and j and out[j] then
			out[i], out[j] = out[j], out[i]
		end
		return out
	end)
end

function PostProcessingControllerClass.moveEffect(
	self: PostProcessingController,
	layerId: string,
	effectId: string,
	step: number
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			local i = indexOf(clone.effects, function(item)
				return item.id == effectId
			end)
			local j = if i then i + step else nil
			if i and j and clone.effects[j] then
				clone.effects[i], clone.effects[j] = clone.effects[j], clone.effects[i]
			end
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerName(self: PostProcessingController, layerId: string, name: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.name = name
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerOffset(self: PostProcessingController, layerId: string, offset: Vector2)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.offset = offset
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerTint(self: PostProcessingController, layerId: string, tintColor: Color3)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.tintColor = tintColor
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerTransparency(
	self: PostProcessingController,
	layerId: string,
	transparency: number
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.transparency = transparency
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerBrightness(
	self: PostProcessingController,
	layerId: string,
	brightness: number
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.brightness = brightness
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerContrast(
	self: PostProcessingController,
	layerId: string,
	contrast: number
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.contrast = contrast
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerSaturation(
	self: PostProcessingController,
	layerId: string,
	saturation: number
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.saturation = saturation
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerHue(self: PostProcessingController, layerId: string, hue: number)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.hue = hue
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerLut(self: PostProcessingController, layerId: string, lut: Lut?)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.lut = lut
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerShowBaseImage(
	self: PostProcessingController,
	layerId: string,
	show: boolean
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.showBaseImage = show
			return clone
		end)
	end)
end

function PostProcessingControllerClass.toggleLayerVisibility(self: PostProcessingController, layerId: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.isVisible = not clone.isVisible
			return clone
		end)
	end)
end

function PostProcessingControllerClass.toggleLayerExpanded(self: PostProcessingController, layerId: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.isExpanded = not clone.isExpanded
			return clone
		end)
	end)
end

function PostProcessingControllerClass.toggleEffectVisibility(
	self: PostProcessingController,
	layerId: string,
	effectId: string
)
	self.observableLayers:update()(function(layers)
		return mapEffect(layers, layerId, effectId, function(item)
			local clone = table.clone(item)
			clone.isVisible = not clone.isVisible
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setEffectName(
	self: PostProcessingController,
	layerId: string,
	effectId: string,
	name: string
)
	self.observableLayers:update()(function(layers)
		return mapEffect(layers, layerId, effectId, function(item)
			local clone = table.clone(item)
			local effect = table.clone(item.effect)
			effect.name = name
			clone.effect = effect
			return clone
		end)
	end)
end

-- Applies a Controller-style effect transform (the same contract the registered
-- effect editor Components use) to a single sub-effect.
function PostProcessingControllerClass.updateEffect(
	self: PostProcessingController,
	layerId: string,
	effectId: string,
	transform: (any) -> any
)
	self.observableLayers:update()(function(layers)
		return mapEffect(layers, layerId, effectId, function(item)
			local clone = table.clone(item)
			local effect = table.clone(item.effect)
			effect.properties = table.clone(item.effect.properties)
			clone.effect = transform(effect)
			return clone
		end)
	end)
end

-- Presets

function PostProcessingControllerClass.usePresets(self: PostProcessingController)
	return self.observablePresets:use()
end

function PostProcessingControllerClass.persistUserPresets(self: PostProcessingController)
	local filtered = {}
	for _, preset in self.observablePresets:get() do
		if not preset.isDefault then
			table.insert(filtered, preset)
		end
	end

	StateManager.postProcessingPresets:set(filtered)
end

-- Snapshots the current layer stack into a new preset.
function PostProcessingControllerClass.addPreset(self: PostProcessingController, name: string?): string
	local preset: Preset = {
		id = nextId(),
		name = name or `Preset {#self.observablePresets:get() + 1}`,
		isDefault = false,
		layers = copyLayers(self.observableLayers:get()),
	}

	self.observablePresets:update()(function(presets)
		local out = table.clone(presets)
		table.insert(out, preset)
		return out
	end)

	self:persistUserPresets()

	return preset.id
end

-- Removes a user preset. Default presets are permanent and silently ignored.
function PostProcessingControllerClass.removePreset(self: PostProcessingController, presetId: string)
	self.observablePresets:update()(function(presets)
		local out = table.clone(presets)
		local i = indexOf(out, function(preset)
			return preset.id == presetId
		end)
		if i and not out[i].isDefault then
			table.remove(out, i)
		end
		return out
	end)
	self:persistUserPresets()
end

-- Replaces the current layer stack with a fresh copy of the preset's snapshot.
function PostProcessingControllerClass.applyPreset(self: PostProcessingController, presetId: string)
	local presets = self.observablePresets:get()
	local i = indexOf(presets, function(preset)
		return preset.id == presetId
	end)
	if i then
		self.observableLayers:set(copyLayers(presets[i].layers))
	end
end

-- Rendering

function PostProcessingControllerClass.loadImageAsync(self: PostProcessingController, editImage: EditableImage)
	if self.editImage == editImage then
		return
	end

	self:unloadImage()
	self.editImage = editImage

	local isImageLoaded = Future.new()

	local alive = true
	self.imageTrove:Add(function()
		alive = false
		self.observableComposited:set({})
		self.observableThumbnails:set({})
		if not isImageLoaded:isCompleted() then
			isImageLoaded:complete()
		end
	end)

	task.spawn(function()
		local svfProcess = SignedVectorField.generate(Content.fromObject(editImage))
		self.imageTrove:Add(function()
			svfProcess:cancel()
		end)

		local unpackSvfEdit = svfProcess:expect()
		if not unpackSvfEdit then
			return
		end

		local svfEdit = unpackSvfEdit()
		if not svfEdit then
			return
		end

		if not alive then
			svfEdit:Destroy()
			return
		end
		self.imageTrove:Add(function()
			svfEdit:Destroy()
		end)

		-- A blank, image-sized scratch image, allocated once per loaded image and reused
		-- across renders, that effects use for intermediate passes (e.g. Drop Shadow's
		-- separable blur). Its initial contents don't matter - effects overwrite it.
		local scratchEdit = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
		if not alive then
			scratchEdit:Destroy()
			return
		end
		self.imageTrove:Add(function()
			scratchEdit:Destroy()
		end)

		-- The shared, unmodified base image; each visible layer references it. Only the
		-- layer's effects and color grade are baked into its composite; the layer's
		-- offset/tint/transparency are applied later as display-time properties.
		local baseEdit = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
		if not alive then
			baseEdit:Destroy()
			return
		end
		self.imageTrove:Add(function()
			baseEdit:Destroy()
		end)

		-- Rendered sub-effect outputs, cached by effect id + renderTicket so only
		-- effects whose properties actually changed are re-rendered.
		type CacheEntry = { editImage: EditableImage, ticket: number }
		local cache: { [string]: CacheEntry } = {}
		self.imageTrove:Add(function()
			for _, entry in cache do
				entry.editImage:Destroy()
			end
			table.clear(cache)
		end)

		-- Per-layer composite thumbnails, cached by a signature of everything that
		-- affects the layer's composited appearance.
		type ThumbnailEntry = { image: EditableImage, signature: string }
		local thumbnailCache: { [string]: ThumbnailEntry } = {}
		self.imageTrove:Add(function()
			for _, entry in thumbnailCache do
				entry.image:Destroy()
			end
			table.clear(thumbnailCache)
		end)

		local function buildOnce()
			local composited: { RenderLayer } = {}
			local thumbnails: { [string]: { RenderLayer } } = {}
			local seenEffects: { [string]: boolean } = {}
			local seenLayers: { [string]: boolean } = {}

			for _, layer in self.observableLayers:get() do
				if not layer.isVisible then
					continue
				end

				-- A graded layer is flattened into one color-graded image (a grade can't be a
				-- display property); an ungraded layer skips the flatten and stays a stack of
				-- per-effect images. Either way the layer's tint/transparency/offset are applied
				-- as display-time properties, never baked, so they're absent from the signature.
				local lutToken = if layer.lut then layer.lut.id else "nolut"
				local signatureParts: { string } = {
					`L:{layer.showBaseImage}:{layer.brightness}:{layer.contrast}:{layer.saturation}:{layer.hue}:{lutToken}`,
				}

				-- Effects either sit above the layer's base image (e.g. inner glow) or behind
				-- it (drop shadow, stroke, outer glow). The layer stack is ordered top-first, so
				-- we collect each group separately and assemble them as [above] -> [base] ->
				-- [below] once every effect is rendered.
				local aboveLayers: { RenderLayer } = {}
				local belowLayers: { RenderLayer } = {}

				for _, item in layer.effects do
					if not item.isVisible then
						continue
					end

					local effect = item.effect
					local effectEntry = Effects.getByKind(effect.kind)
					local cached = cache[item.id]

					local entry: CacheEntry
					if cached and cached.ticket == effect.renderTicket then
						entry = cached
					else
						local output = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
						if not alive then
							output:Destroy()
							return
						end

						effectEntry.render(
							{ img = editImage, svf = svfEdit, scratch = scratchEdit, output = output },
							effect.properties
						)

						if not alive then
							output:Destroy()
							return
						end

						if cached then
							cached.editImage:Destroy()
						end
						entry = { editImage = output, ticket = effect.renderTicket }
						cache[item.id] = entry
					end

					-- Bake each sub-effect's own color and transparency into the layer
					-- composite. (The layer-wide tint/transparency are applied later, at display
					-- time, not folded in here.)
					seenEffects[item.id] = true
					local renderLayer: RenderLayer = {
						name = effect.name,
						editImage = entry.editImage,
						offset = effect.properties.offset,
						tintColor = effect.properties.color,
						transparency = effect.properties.transparency,
					}

					if effectEntry.renderAboveBase then
						table.insert(aboveLayers, renderLayer)
					else
						table.insert(belowLayers, renderLayer)
					end

					table.insert(
						signatureParts,
						`{item.id}:{effect.renderTicket}:{effect.properties.offset}:{effect.properties.color}:{effect.properties.transparency}`
					)
				end

				-- Assemble the layer stack top-first: above-base effects, the base image,
				-- then behind-base effects.
				local layerRenderLayers: { RenderLayer } = {}
				for _, e in aboveLayers do
					table.insert(layerRenderLayers, e)
				end
				if layer.showBaseImage then
					table.insert(layerRenderLayers, {
						name = layer.name,
						editImage = baseEdit,
						offset = Vector2.zero,
						tintColor = Color3.new(1, 1, 1),
						transparency = 0,
					})
				end
				for _, e in belowLayers do
					table.insert(layerRenderLayers, e)
				end

				local hasGrade = layer.brightness ~= 0 or layer.contrast ~= 0 or layer.saturation ~= 0 or layer.hue ~= 0
				local hasLut = layer.lut ~= nil

				seenLayers[layer.id] = true

				if #layerRenderLayers == 0 then
					-- Nothing visible in this layer; drop any cached composite and emit nothing.
					if thumbnailCache[layer.id] then
						thumbnailCache[layer.id].image:Destroy()
						thumbnailCache[layer.id] = nil
					end
				elseif hasGrade or hasLut then
					-- Flatten the layer into one image, reusing the cached result whenever nothing
					-- affecting it changed. A grade and/or LUT is baked into the flattened result
					-- (the LUT can't be a display property); effect colors/transparencies are baked
					-- in by the compose too, while the layer-wide tint/transparency stay as display
					-- properties on the single result.
					local adjustment: LayerComposer.Adjustment? = nil
					if hasGrade then
						adjustment = {
							brightness = layer.brightness,
							contrast = layer.contrast,
							saturation = layer.saturation,
							hue = layer.hue,
						}
					end

					local signature = table.concat(signatureParts, "|")
					local cachedThumb = thumbnailCache[layer.id]
					local image: EditableImage
					if cachedThumb and cachedThumb.signature == signature then
						image = cachedThumb.image
					else
						image = LayerComposer.composeAsync(editImage, layerRenderLayers, adjustment, layer.lut)
						if not alive then
							image:Destroy()
							return
						end
						if cachedThumb then
							cachedThumb.image:Destroy()
						end
						thumbnailCache[layer.id] = { image = image, signature = signature }
					end

					local entry: RenderLayer = {
						name = layer.name,
						editImage = image,
						offset = layer.offset,
						tintColor = layer.tintColor,
						transparency = layer.transparency,
					}
					table.insert(composited, entry)
					-- The thumbnail omits the layer's global offset so moving the layer doesn't
					-- push it off-canvas.
					thumbnails[layer.id] = { table.clone(entry) :: RenderLayer }
					thumbnails[layer.id][1].offset = Vector2.zero
				else
					-- No grade and no LUT, so no compose: each effect (and the base) stays a separate
					-- ImageLabel. Fold the layer's tint/transparency into each effect's own and
					-- emit per-effect entries for the preview (with the layer offset) and the
					-- thumbnail (without it). Changing an effect's color/transparency/offset
					-- only rebuilds these lightweight entries - no re-composite.
					if thumbnailCache[layer.id] then
						thumbnailCache[layer.id].image:Destroy()
						thumbnailCache[layer.id] = nil
					end

					local thumbLayers: { RenderLayer } = {}
					for _, renderLayer in layerRenderLayers do
						local lt, et = layer.tintColor, renderLayer.tintColor
						local foldedTint = Color3.new(lt.R * et.R, lt.G * et.G, lt.B * et.B)
						local foldedTransparency = 1 - (1 - layer.transparency) * (1 - renderLayer.transparency)

						table.insert(thumbLayers, {
							name = renderLayer.name,
							editImage = renderLayer.editImage,
							offset = renderLayer.offset,
							tintColor = foldedTint,
							transparency = foldedTransparency,
						})
						table.insert(composited, {
							name = renderLayer.name,
							editImage = renderLayer.editImage,
							offset = layer.offset + renderLayer.offset,
							tintColor = foldedTint,
							transparency = foldedTransparency,
						})
					end
					thumbnails[layer.id] = thumbLayers
				end
			end

			if not alive then
				return
			end

			for id, entry in cache do
				if not seenEffects[id] then
					entry.editImage:Destroy()
					cache[id] = nil
				end
			end

			for id, entry in thumbnailCache do
				if not seenLayers[id] then
					entry.image:Destroy()
					thumbnailCache[id] = nil
				end
			end

			-- An image is loaded but nothing is visible (e.g. base image hidden, no
			-- effects): show a blank canvas at the base resolution rather than letting
			-- the viewer fall back to its "no image" state.
			if #composited == 0 then
				table.insert(composited, {
					name = "Image",
					editImage = baseEdit,
					offset = Vector2.zero,
					tintColor = Color3.new(1, 1, 1),
					transparency = 1,
				})
			end

			self.observableComposited:set(composited)
			self.observableThumbnails:set(thumbnails)
			if not isImageLoaded:isCompleted() then
				isImageLoaded:complete()
			end
		end

		-- Coalesce rapid model changes: only one rebuild runs at a time, and any
		-- change arriving mid-rebuild schedules exactly one more pass.
		local running = false
		local dirty = false
		local function rebuild()
			if running then
				dirty = true
				return
			end
			running = true
			task.spawn(function()
				repeat
					dirty = false
					local ok = pcall(buildOnce)
					if not ok then
						break
					end
				until not dirty or not alive
				running = false
			end)
		end

		rebuild()
		self.imageTrove:Add(self.observableLayers:onChanged(rebuild))
	end)

	return isImageLoaded:expect()
end

function PostProcessingControllerClass.unloadImage(self: PostProcessingController)
	self.imageTrove:Clean()
	self.editImage = nil
end

function PostProcessingControllerClass.isLoadedImage(self: PostProcessingController, editImage: EditableImage)
	return self.editImage == editImage
end

function PostProcessingControllerClass.useThumbnails(self: PostProcessingController)
	return self.observableThumbnails:use()
end

function PostProcessingControllerClass.composeImageAsync(self: PostProcessingController, editImage: EditableImage)
	local wasLoaded = self.editImage == editImage

	self:loadImageAsync(editImage)

	local composited = self.observableComposited:get()
	local composedEdit = LayerComposer.composeAsync(editImage, composited)

	if not wasLoaded then
		self:unloadImage()
	end

	return composedEdit
end

function PostProcessingControllerClass.useComposited(self: PostProcessingController)
	return self.observableComposited:use()
end

function PostProcessingControllerClass.Destroy(self: PostProcessingController)
	self.imageTrove:Destroy()
	self.observableThumbnails:Destroy()
	self.observableLayers:Destroy()
	self.observableComposited:Destroy()
	self.observablePresets:Destroy()
end

--

return PostProcessingControllerStatic
