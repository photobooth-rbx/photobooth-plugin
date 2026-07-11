local AssetService = game:GetService("AssetService") :: AssetService
local CaptureService = game:GetService("CaptureService") :: CaptureService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Future = require(pluginRoot.Packages.Future)
local Constants = require(pluginRoot.Constants)
local StateManager = require(pluginRoot.Main.StateManager)

local OS_MISMATCH = "OS Scale mismatch. You may need to go into photobooth settings and refresh the OS scale value."

local Screenshot = {}

-- Private

local function captureEditableImage()
	local contentUriFuture = Future.new() :: Future.Future<string>
	CaptureService:CaptureScreenshot(function(contentUri: string)
		-- this is a significant bottleneck for speed
		-- it can take roughly 0.3 seconds to complete
		contentUriFuture:complete(contentUri)
	end)

	local contentUri = contentUriFuture:expect()
	local editImage = AssetService:CreateEditableImageAsync(Content.fromUri(contentUri)) :: EditableImage

	return editImage
end

local function screenshot(rect: Rect?, skipScaleValidation: boolean?)
	local editImage = captureEditableImage()

	local result
	local success, err: string? = pcall(function()
		local viewportSize = workspace.CurrentCamera.ViewportSize :: Vector2
		local scale = editImage.Size / viewportSize

		if not skipScaleValidation and scale ~= StateManager.temporary:get().scaleOS then
			error("WARN: " .. OS_MISMATCH, 0)
		end

		if rect then
			local rectSize = rect.Max - rect.Min
			local croppedBuffer = editImage:ReadPixelsBuffer(rect.Min, rectSize)
			local cropped = AssetService:CreateEditableImage({ Size = rectSize })
			cropped:WritePixelsBuffer(Vector2.zero, rectSize, croppedBuffer)
			editImage:Destroy()
			result = cropped
		else
			result = editImage
		end
	end)

	if not success and err then
		editImage:Destroy()
		error(err, 0)
	end

	return result
end

-- Public

function Screenshot.calculateScaleOS()
	local editImage = captureEditableImage()
	local viewportSize = workspace.CurrentCamera.ViewportSize :: Vector2
	local scale = editImage.Size / viewportSize
	editImage:Destroy()
	return scale
end

function Screenshot.isUnitScaleOS(scaleOS: Vector2)
	return scaleOS.X == 1 and scaleOS.Y == 1
end

function Screenshot.isFullscreenRect(rect: Rect)
	local scaleOS = StateManager.temporary:get().scaleOS
	local viewportSize = workspace.CurrentCamera.ViewportSize :: Vector2

	-- stylua: ignore
	local scaledViewportSize = Vector2.new(
		math.round(viewportSize.X * scaleOS.X),
		math.round(viewportSize.Y * scaleOS.Y)
	)

	return rect.Min == Vector2.zero and rect.Max == scaledViewportSize
end

function Screenshot.rect(rect: Rect, isFullscreen: boolean?, skipScaleValidation: boolean?)
	if isFullscreen == nil then
		isFullscreen = Screenshot.isFullscreenRect(rect)
	end

	if isFullscreen then
		return screenshot(nil, skipScaleValidation)
	else
		assert(
			not (rect.Width > Constants.MaxCaptureRectSize.X or rect.Height > Constants.MaxCaptureRectSize.Y),
			`Capture target is larger than {Constants.MaxCaptureRectSize.X} x {Constants.MaxCaptureRectSize.Y}.`
		)

		return screenshot(rect, skipScaleValidation)
	end
end

--

return Screenshot
