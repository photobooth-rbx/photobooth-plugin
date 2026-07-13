local ScriptEditorService = game:GetService("ScriptEditorService")
local StudioService = game:GetService("StudioService")
local SelectionService = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local hooksRoot = script.Parent.Parent.Parent.Hooks
local useUpload = require(hooksRoot.useUpload)

local UploadLineItem = require(script.UploadLineItem)
local CreatorSelect = require(script.CreatorSelect)

type EditableImageInfo = Hooks.EditableImageInfo

export type Creator = useUpload.Creator
export type Output = useUpload.Output
export type TryUpload = useUpload.TryUpload
export type TestCreator = useUpload.TestCreator

local function onUploadComplete(completed: Output)
	local module = Instance.new("ModuleScript")
	module.Name = `{DateTime.now():ToIsoDate()} - Photobooth Upload`

	ScriptEditorService:UpdateSourceAsync(module, function()
		local output = "return {\n"
		for _, entry in completed do
			output = output .. `\t["{entry.Name}"] = "rbxassetid://{entry.AssetId}",\n`
		end
		return output .. "}"
	end)
	module.Parent = StarterGui

	ScriptEditorService:OpenScriptDocumentAsync(module)
	SelectionService:Set({ module })
end

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	UploadInfos: { EditableImageInfo },

	TryUpload: TryUpload,
	TestCreator: TestCreator,

	OnClose: () -> (),

	Disabled: boolean?,
}

local function Uploader(props: Props)
	local theme = StudioComponents.useTheme()

	local creator, setCreator = React.useState("Me")
	local groupId, setGroupId = React.useState(0)

	local upload = useUpload({
		UploadInfos = props.UploadInfos,
		TryUpload = props.TryUpload,
		TestCreator = props.TestCreator,
	})

	local isComplete = upload.phase == "Complete"
	local isBusy = upload.phase == "Validating" or upload.phase == "Uploading"

	if #upload.infos == 0 then
		return React.createElement("Frame", {
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			Size = props.Size,
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		}, {
			Placeholder = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -32, 1, -32),
				Text = "Select MeshPart(s) with an EditableImage texture to upload.",
				TextWrapped = true,
				TextColor3 = theme:GetColor(
					Enum.StudioStyleGuideColor.MainText,
					Enum.StudioStyleGuideModifier.Disabled
				),
				Font = StudioComponents.Constants.DefaultFont,
				TextSize = StudioComponents.Constants.DefaultTextSize,
			}),
		})
	end

	local lines: { [string]: React.Node } = {}
	for i, info in upload.infos do
		local status = upload.statuses[i]

		lines[`Line{i}`] = React.createElement(UploadLineItem, {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.new(1, 0, 0, 64),

			Name = info.Name,
			EditableImage = info.EditableImage,

			AssetId = upload.assetIds[i],
			Progress = if status == "Complete" then 1 elseif status == "InProgress" then 0.05 else 0,
			StatusText = if status == "Waiting"
				then "Waiting"
				elseif status == "Fail" then "Failed"
				elseif status == "Cancel" then "Canceled"
				else nil,

			OnCancel = function()
				upload.cancel(i)
			end,

			LayoutOrder = i,
			Disabled = not (status == "Queued" or status == "InProgress" or status == "Complete"),
		})
	end

	return React.createElement("Frame", {
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),

		FileList = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, -6 - 32),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			LayoutOrder = 2,
		}, {
			Scroll = React.createElement(StudioProperties.VerticalScroll, {
				AnchorPoint = Vector2.zero,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),

				GradientColor = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
				GradientHeight = 8,

				Disabled = props.Disabled,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
			}, lines),
		}),

		BottomRow = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = 3,
		}, {
			Buttons = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, {
				Layout = React.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 4),
				}),

				Confirm = React.createElement(StudioComponents.MainButton, {
					LayoutOrder = -1,
					Size = UDim2.new(0, 70, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = if isComplete then "Open" else "Upload",
					Disabled = props.Disabled or isBusy,
					OnActivated = function()
						if isComplete then
							onUploadComplete(upload.output)
						else
							local isGroup = creator == "Group"
							upload.start({
								Id = if isGroup then groupId else StudioService:GetUserId(),
								Type = if isGroup then Enum.AssetCreatorType.Group else Enum.AssetCreatorType.User,
							})
						end
					end,
				}),
				Cancel = React.createElement(StudioComponents.Button, {
					LayoutOrder = -2,
					Size = UDim2.new(0, 70, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = if upload.phase ~= "Uploading" then "Close" else "Cancel",
					Disabled = props.Disabled,
					OnActivated = function()
						local phase = upload.phase
						upload.reset()
						if phase ~= "Uploading" then
							props.OnClose()
						end
					end,
				}),
			}),

			Creator = React.createElement(CreatorSelect, {
				Creator = creator,
				SetCreator = setCreator,

				GroupId = groupId,
				SetGroupId = setGroupId,

				GroupError = upload.groupError,

				Disabled = props.Disabled or isBusy,
			}),
		}),
	})
end

return Uploader
