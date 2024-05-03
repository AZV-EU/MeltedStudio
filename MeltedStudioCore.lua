repeat task.wait() until game:IsLoaded()

if not _G.SafeGetService then
	--if not cloneref and getgenv then
	--	loadstring(game:HttpGet("https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/CloneRef.lua", true))()
	--end
	--if cloneref then
	--	_G.SafeGetService = function(service)
	--		return cloneref(game:GetService(service))
	--	end
	--else
	_G.SafeGetService = function(service)
		return game:GetService(service)
	end
	--end
end

local Players: Players = _G.SafeGetService("Players")
local UserInputService: UserInputService = _G.SafeGetService("UserInputService")
local TweenService: TweenService = _G.SafeGetService("TweenService")
local TextService: TextService = _G.SafeGetService("TextService")

script.Parent.DisplayOrder = 99999
script.Parent.ResetOnSpawn = false
script.Parent.IgnoreGuiInset = true
script.Parent.Name = "MeltedStudio"

local explorer = script.Parent:WaitForChild("Explorer")
explorer.Visible = false
local loader = script.Parent:WaitForChild("Loader")
loader.Visible = false

if _G.MeltedStudio ~= nil and _G.MeltedStudio.Remove then
	local f, err = pcall(_G.MeltedStudio.Remove)
	if not f then
		warn("Failed to remove MeltedStudio:", err)
	end
end

local api = require(script:WaitForChild("MeltedStudioAPI"))

do -- loading process
	loader.LoadingBar.Progress.Size = UDim2.fromScale(0, 1)
	local sl = loader.StatusContainer.StatusLabel:Clone()
	loader.StatusContainer.StatusLabel:Destroy()
	local function pushStatus(text)
		local slNew = sl:Clone()
		slNew.Text = text
		slNew.Parent = loader.StatusContainer
		local tween = TweenService:Create(slNew, TweenInfo.new(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			MaxVisibleGraphemes = utf8.len(slNew.Text)
		})
		tween.Completed:Once(function()
			slNew.MaxVisibleGraphemes = -1
		end)
		tween:Play()
		task.wait(.1)
	end
	pushStatus("Initializing")
	api.Loading.LoadFunc = function(progress, status)
		pushStatus(status)
		loader.LoadingBar.Progress.Size = UDim2.fromScale(progress, 1)
	end
	loader.Visible = true
	api.Loading.LoadApi()
	task.wait(.25)
	loader.Visible = false
end

local Colors = {
	Properties = {
		ReadOnly = Color3.new(0.5, 0.5, 0.5),
		Focused = Color3.new(37/255, 37/255, 37/255)
	}
}

local SelectionChangedBindable = Instance.new("BindableEvent") 
local MeltedStudio = {
	API = api,
	GUI = script.Parent,
	Selection = {} :: {Instance: boolean},
	Clipboard = {},
	SelectionChanged = SelectionChangedBindable.Event,
	UpdateRate = 3 -- in seconds, how often to update non-selected objects
}

local selection = {
	cleared = true,
	first = nil,
	count = 0
}

function MeltedStudio:GetFirstSelected()
	return selection.first
end

function MeltedStudio:AddToSelection(instances)
	if not instances then return end
	if type(instances) == "userdata" then instances = {instances} end
	local changed = false
	for _,instance in pairs(instances) do
		if not MeltedStudio.Selection[instances] then
			changed = true
			MeltedStudio.Selection[instance] = true
			if selection.cleared then
				selection.cleared = false
			end
			if not selection.first then
				selection.first = instance
			end
		end
	end
	if changed then
		SelectionChangedBindable:Fire()
	end
end

function MeltedStudio:RemoveFromSelection(instances)
	if not instances then return end
	if type(instances) == "userdata" then instances = {instances} end
	local changed = false
	if not selection.cleared then
		for _,instance in pairs(instances) do
			if instance == selection.first then
				selection.first = nil
			end
			if MeltedStudio.Selection[instance] then
				changed = true
				MeltedStudio.Selection[instance] = nil
			end
			for _,desc in pairs(instance:GetDescendants()) do
				if MeltedStudio.Selection[desc] then
					MeltedStudio.Selection[desc] = nil
					changed = true
				end
			end
		end

		local empty = true
		for inst,selected in pairs(MeltedStudio.Selection) do
			if inst and inst.Parent and selected then
				empty = false
				if not selection.first then
					selection.first = inst
					break
				end
			end
		end
		if empty then
			changed = true
			selection.first = nil
		end
		selection.cleared = empty
	end
	if changed then
		SelectionChangedBindable:Fire()
	end
end

function MeltedStudio:ClearSelection()
	if not selection.cleared then
		MeltedStudio.Selection = {}
		selection.cleared = true
		selection.first = nil
		SelectionChangedBindable:Fire()
	end
end

function MeltedStudio:Select(instances)
	if not instances then MeltedStudio:ClearSelection() return end
	if type(instances) == "userdata" then instances = {instances} end
	local changed = false
	local newSelection = {}

	for _,instance in pairs(instances) do
		newSelection[instance] = true
	end
	for instance,selected in pairs(MeltedStudio.Selection) do
		if not newSelection[instance] and selected then
			changed = true
			MeltedStudio.Selection[instance] = nil
			if selection.first == instance then
				selection.first = nil
			end
		else
			selection.cleared = false
		end
	end
	for instance,selected in pairs(newSelection) do
		if not MeltedStudio.Selection[instance] then
			changed = true
			selection.cleared = false
			MeltedStudio.Selection[instance] = true
		end
	end

	if not selection.cleared then
		for inst,selected in pairs(MeltedStudio.Selection) do
			if inst and inst.Parent and selected then
				selection.cleared = false
				changed = true
				break
			end
		end
	end

	if not selection.cleared and not selection.first then
		for inst,selected in pairs(MeltedStudio.Selection) do
			if inst and inst.Parent and selected then
				selection.first = inst
				break
			end
		end
		if selection.first then
			changed = true
		end
	end

	if changed then
		SelectionChangedBindable:Fire()
	end
end

function MeltedStudio:GetSelectedInstances()
	local instances = {}
	for instance,_ in pairs(MeltedStudio.Selection) do
		table.insert(instances, instance)
	end
	return instances
end

local studioIcons = {
	ArrowCollapsed = "rbxasset://textures/StudioToolbox/ArrowCollapsed.png",
	ArrowExpanded = "rbxasset://textures/StudioToolbox/ArrowExpanded.png"
}
do -- preload
	local toPreload = {api.ClassIcons.Source, api.ClassIcons.SourceLegacy}
	for _,src in pairs(studioIcons) do
		table.insert(toPreload, src)
	end
	_G.SafeGetService("ContentProvider"):PreloadAsync(toPreload)
end

local temp = {
	running = true,
	uiInstanceContainers = {} :: {Frame},
	uiPropertyContainers = {} :: {Frame},
	uiPropertyConnections = {} :: {RBXScriptConnection},
	connections = {},
	internal = {
		instanceView = {
			recursiveScan = function() end,
			fullScan = function() end,
			rename = function() end
		}
	}
}

local function getInstanceIndex(instance: Instance)
	if temp.uiInstanceContainers[instance] then
		return temp.uiInstanceContainers[instance]:GetAttribute("InstanceIndex") or 0
	end
	return 0
end

local function getInstancesBetweenIndices(first: number, last: number)
	if first > last then
		local f = first
		first = last
		last = f
	end
	local results = {}
	for inst,instContainer in pairs(temp.uiInstanceContainers) do
		local index = getInstanceIndex(inst)
		if index >= first and index <= last then
			table.insert(results, inst)
		end
	end
	return results
end

do -- studio logic
	MeltedStudio.Actions = {}

	do -- outside click for cancelling actions
		temp.internal.outsideClickConn = nil
		function temp.internal.outsideClick(func, outside)
			temp.internal.outsideClickConn = game.UserInputService.InputBegan:Connect(function(input, gpe)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or
					input.UserInputType == Enum.UserInputType.MouseButton2 or
					input.UserInputType == Enum.UserInputType.MouseButton3 or
					(input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape) then
					if not outside or input.UserInputType == Enum.UserInputType.Keyboard or
						(input.Position.X < script.Parent.AbsolutePosition.X and
							input.Position.X > script.Parent.AbsolutePosition.X + script.Parent.AbsoluteSize.X and
							input.Position.Y < script.Parent.AbsolutePosition.Y and
							input.Position.Y > script.Parent.AbsolutePosition.Y + script.Parent.AbsoluteSize.Y) then
						temp.internal.outsideClickConn:Disconnect()
						pcall(func)
					end
				end
			end)
		end
	end

	do -- context menu
		local contextMenu = script.Parent:WaitForChild("ContextMenu")
		contextMenu.Visible = false
		local actionContainer = contextMenu:WaitForChild("ActionContainer"):Clone()
		contextMenu.ActionContainer:Destroy()

		-- action structure:
		-- [className] = {name, image, condition, function}
		MeltedStudio.ContextActions = {
			["Instance"] = {
				{"Cut", "rbxasset://studio_svg_textures/Shared/Clipboard/Dark/Large/Cut.png",
					function(instances)
						for _,inst in pairs(instances) do
							if inst.Parent == game then
								return false
							end
						end
						return true
					end,
					function(instances)
						if not instances then return end
						MeltedStudio.Clipboard = instances
						for _,inst in pairs(instances) do
							inst.Parent = nil
						end
						temp.internal.instanceView.fullScan()
						MeltedStudio:ClearSelection()
					end
				},
				{"Copy", "rbxasset://studio_svg_textures/Shared/Clipboard/Dark/Large/Copy.png",
					function(instances)
						for _,inst in pairs(instances) do
							if inst.Parent == game then
								return false
							end
						end
						return true
					end,
					function(instances)
						if not instances then return end
						local copies = {}
						for _,inst in pairs(instances) do
							table.insert(copies, inst:Clone())
						end
						MeltedStudio.Clipboard = copies
						MeltedStudio:ClearSelection()
					end
				},
				{"Paste Into", "rbxasset://studio_svg_textures/Shared/Clipboard/Dark/Large/Paste.png",
					function(instances) return #instances == 1 and #MeltedStudio.Clipboard > 0 end,
					function(instances)
						if not instances or #MeltedStudio.Clipboard == 0 then return end
						local target = instances[1]
						if not target then return end

						for _,inst in pairs(MeltedStudio.Clipboard) do
							inst.Parent = target
						end
						if not temp.uiInstanceContainers[target] and target.Parent ~= nil then
							temp.internal.instanceView.recursiveScan(target.Parent)
						end
						if temp.uiInstanceContainers[target] then
							temp.uiInstanceContainers[target]:SetAttribute("Expanded", true)
						end
						temp.internal.instanceView.fullScan()
						MeltedStudio:Select(MeltedStudio.Clipboard)
						MeltedStudio.Clipboard = {}
					end
				},
				{"Duplicate", "rbxasset://studio_svg_textures/Shared/Clipboard/Dark/Large/Duplicate.png",
					function(instances)
						for _,inst in pairs(instances) do
							if inst.Parent == game or inst.Parent == nil then
								return false
							end
						end
						return true
					end,
					function(instances)
						if not instances then return end
						local duplicates = {}
						for _,inst in pairs(instances) do
							if inst.Parent ~= nil then
								local duplicate = inst:Clone()
								duplicate.Parent = inst.Parent
								table.insert(duplicates, duplicate)
							end
						end
						MeltedStudio:Select(duplicates)
						temp.internal.instanceView.fullScan()
					end
				},
				{"Delete", "rbxasset://studio_svg_textures/Lua/Terrain/Dark/Large/Terrain_Delete.png",
					function(instances)
						for _,inst in pairs(instances) do
							if inst.Parent == game then
								return false
							end
						end
						return true
					end,
					function(instances)
						if not instances or #instances == 0 then return end
						for _,inst in pairs(instances) do
							inst:Destroy()
						end
						temp.internal.instanceView.fullScan()
					end
				},
				{"Rename", nil,
					function(instances)
						for _,inst in pairs(instances) do
							if inst.Parent == game then
								return false
							end
						end
						return true
					end,
					function(instances)
						if not instances or #instances == 0 then return end
						local instance = instances[1]
						local newName = temp.internal.instanceView.rename(instance)
						if newName then
							for k,inst in ipairs(instances) do
								if k > 1 then
									inst.Name = newName
								end
							end
							temp.internal.instanceView.fullScan()
						end
					end
				},
				{"Copy Path", nil,
					function(instances)
						return true
					end,
					function(instances)
						if not instances then return end
						local f, err = pcall(function()
							_G.SetClipboard(_G.Stringify(instances[1]))
						end)
						if not f then
							print("Failed to copy to clipboard:\n", err)
						end
					end
				},
			}
		}

		function MeltedStudio.Actions.CloseContextMenu()
			contextMenu.Visible = false
			for _,v in pairs(contextMenu:GetChildren()) do
				if v.Name == "ActionContainer" then
					v:Destroy()
				end
			end
			if temp.internal.outsideClickConn then
				pcall(temp.internal.outsideClickConn.Disconnect, temp.internal.outsideClickConn)
				temp.internal.outsideClickConn = nil
			end
		end

		local function constructConextMenu(instances)
			MeltedStudio.Actions.CloseContextMenu()

			local createdAny = false

			for _,action in pairs(MeltedStudio.ContextActions["Instance"]) do
				local name, image, cond, func = table.unpack(action)
				if not name or (cond and not cond(instances)) then continue end
				local ac = actionContainer:Clone()
				ac.ActionLabel.Text = name
				ac.ActionIcon.Image = image and image or ""
				if func then
					local done = false
					ac.MouseButton1Down:Once(function()
						if done then return end
						done = true
						local f, err = pcall(func, instances)
						if not f then
							warn(err)
						end
					end)
				end
				ac.Parent = contextMenu
				createdAny = true
			end

			return createdAny
		end

		function MeltedStudio.Actions.OpenContextMenu()
			local instances = MeltedStudio:GetSelectedInstances()
			if not instances or #instances == 0 then return end
			if constructConextMenu(instances) then
				local location = UserInputService:GetMouseLocation()
				contextMenu.Position = UDim2.fromOffset(
					math.min(location.X, script.Parent.AbsoluteSize.X - contextMenu.AbsoluteSize.X),
					math.min(location.Y, script.Parent.AbsoluteSize.Y - contextMenu.AbsoluteSize.Y)
				)
				contextMenu.Visible = true
				task.delay(0.1, temp.internal.outsideClick, MeltedStudio.Actions.CloseContextMenu)
			end
		end
	end

	do -- decompiler
		function MeltedStudio.Actions.OpenScript(instance)
			if not instance then return end
			local decompile = decompile or _G.Decompile
			if not decompile then
				--warn("No decompile function found. Cannot open instance", instance)
				return
			end
			if instance.ClassName == "LocalScript" or instance.ClassName == "ModuleScript" then

			end
		end
	end

	MeltedStudio.DefaultActions = {
		["LocalScript"] = MeltedStudio.Actions.OpenScript,
		["ModuleScript"] = MeltedStudio.Actions.OpenScript
	}
	function MeltedStudio:ExecuteDefaultAction(instance)
		if not instance then return end
		if MeltedStudio.DefaultActions[instance.ClassName] then
			local f, err = pcall(MeltedStudio.DefaultActions[instance.ClassName], instance)
			if not f then
				warn("Default Action failed:", err)
			end
		end
	end
end

do -- explorer logic
	MeltedStudio.Explorer = {}
	local instancesView = explorer:WaitForChild("InstancesView")
	local instancesList = instancesView:WaitForChild("InstancesList")
	local tInstanceContainer = instancesList:WaitForChild("InstanceContainer")
	tInstanceContainer.Parent = nil

	local defaultBgCol, selectedBgCol = Color3.fromRGB(46, 46, 46), Color3.fromRGB(11, 90, 175)

	do -- instances view
		local filterBox = instancesView:WaitForChild("FilterBoxContainer"):WaitForChild("FilterBox")
		local searchStatus = instancesView:WaitForChild("FilterBoxContainer"):WaitForChild("SearchStatus")
		searchStatus.Visible = false

		local getnilinstances = getnilinstances or _G.GetNilInstances
		do
			local a = Instance.new("Part")
			a.Name = "Super Secret Part Test"
			local nils = {a}
			if not getnilinstances then
				getnilinstances = function()
					return nils
				end
			end
		end

		local virtualViews = Instance.new("Folder")
		local nilInstancesView = Instance.new("Folder", virtualViews)
		nilInstancesView.Name = "Nil Instances"

		local bannedInstances = {
			[MeltedStudio.GUI] = true,
			[virtualViews] = true
		}

		local function getVirtualChildren(instance)
			if instance == nilInstancesView then
				return getnilinstances()
			end
			return {}
		end

		local customOrder = {
			[_G.SafeGetService("Workspace")] = 1,
			[_G.SafeGetService("Players")] = 2,
			[_G.SafeGetService("CoreGui")] = 3,
			[_G.SafeGetService("Lighting")] = 4,
			[_G.SafeGetService("ReplicatedFirst")] = 5,
			[_G.SafeGetService("ReplicatedStorage")] = 6,
			[_G.SafeGetService("StarterGui")] = 7,
			[_G.SafeGetService("StarterPack")] = 8,
			[_G.SafeGetService("StarterPlayer")] = 9,
			[_G.SafeGetService("Teams")] = 10
		}

		for k,view in ipairs(virtualViews:GetChildren()) do
			customOrder[view] = 10 + k
		end

		local sortedServices = {} -- to iterate in order
		local orderedServices = {} -- to get a service's index
		do -- create custom services order for easier displaying
			for service,index in pairs(customOrder) do
				sortedServices[index] = service
			end
			for _,service in pairs(game:GetChildren()) do
				if not customOrder[service] then
					table.insert(sortedServices, service)
				end
			end
			for index,service in ipairs(sortedServices) do
				orderedServices[service] = index
			end
		end

		local function updateSelected()
			for instance,instContainer in pairs(temp.uiInstanceContainers) do
				instContainer.Header.SelectionPlate.BackgroundColor3 = MeltedStudio.Selection[instance] and selectedBgCol or defaultBgCol
				instContainer.Header.SelectionPlate.AutoButtonColor = not MeltedStudio.Selection[instance]
			end
		end
		table.insert(temp.connections, MeltedStudio.SelectionChanged:Connect(updateSelected))

		local function clearHangingInstances()
			for instance,instContainer in pairs(temp.uiInstanceContainers) do
				if instance.Parent == nil then
					temp.uiInstanceContainers[instance] = nil
					instContainer:Destroy()
				end
			end
		end

		local searchInstances = {}
		local filterEnabled = false

		local function fixInstanceIndices()
			local index = 0
			local function recursiveIndexer(instance)
				local instanceContainer = temp.uiInstanceContainers[instance]
				if instanceContainer and instanceContainer.Visible then
					index += 1
					instanceContainer:SetAttribute("InstanceIndex", index)
					local children = instance:GetChildren()
					if (filterEnabled and searchInstances[instance]) or (#children > 0 and instanceContainer:GetAttribute("Expanded")) then
						for _,child in pairs(children) do
							recursiveIndexer(child)
						end
					end
				end
			end
			for _,service in ipairs(sortedServices) do
				recursiveIndexer(service)
			end
		end

		local function instantiateContainer(instance: Instance)
			local instContainer = temp.uiInstanceContainers[instance]
			if not instContainer then
				instContainer = tInstanceContainer:Clone()
				instContainer:SetAttribute("Expanded", false)
				instContainer.Header.ChildrenViewToggle.ToggleIcon.Image = studioIcons.ArrowCollapsed

				local function toggleExpand()
					if filterEnabled then return end
					instContainer:SetAttribute("Expanded", not instContainer:GetAttribute("Expanded"))
					instContainer.Header.ChildrenViewToggle.ToggleIcon.Image = instContainer:GetAttribute("Expanded") and studioIcons.ArrowExpanded or studioIcons.ArrowCollapsed

					if not instContainer:GetAttribute("Expanded") then
						for _,desc in pairs(instance:GetDescendants()) do
							if temp.uiInstanceContainers[desc] then
								temp.uiInstanceContainers[desc]:Destroy()
								temp.uiInstanceContainers[desc] = nil
							end
						end
					end

					temp.internal.instanceView.recursiveScan(instance.Parent)
					updateSelected()
				end
				instContainer.Header.ChildrenViewToggle.MouseButton1Down:Connect(toggleExpand)

				local lastClicked = 0
				instContainer.Header.SelectionPlate.MouseButton1Down:Connect(function()
					if tick() - lastClicked < .25 then
						if MeltedStudio.DefaultActions[instance.ClassName] then
							MeltedStudio:ExecuteDefaultAction(instance)
						else
							toggleExpand()
						end
					end
					lastClicked = tick()
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
						if MeltedStudio.Selection[instance] then
							MeltedStudio:RemoveFromSelection(instance)
						else
							MeltedStudio:AddToSelection(instance)
						end
					elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						if not selection.first then
							MeltedStudio:Select(instance)
						else
							local firstIndex, instIndex = getInstanceIndex(selection.first), getInstanceIndex(instance)
							MeltedStudio:Select(getInstancesBetweenIndices(firstIndex, instIndex))
						end
					else
						MeltedStudio:Select(instance)
					end
				end)

				instContainer.Header.SelectionPlate.MouseButton2Down:Connect(function()
					if #MeltedStudio:GetSelectedInstances() <= 1 then
						MeltedStudio:Select(instance)
					else
						MeltedStudio:AddToSelection(instance)
					end
					MeltedStudio.Actions.OpenContextMenu()
				end)

				local classIcon = api:GetClassIcon(instance.ClassName)
				--instContainer.Header.ClassIcon.Image = classIcon
				instContainer.Header.ClassIcon.Image = classIcon.Image
				instContainer.Header.ClassIcon.ImageRectOffset = classIcon.ImageRectOffset
				--instContainer.Header.SelectionPlate.BackgroundColor3 = MeltedStudio.Selection[instance] and selectedBgCol or defaultBgCol

				temp.uiInstanceContainers[instance] = instContainer
			end
			return temp.uiInstanceContainers[instance]
		end

		local toShow = nil
		temp.internal.instanceView.recursiveScan = function(parentInstance)
			local isVirtual = parentInstance.Parent == virtualViews
			local parentContainer = temp.uiInstanceContainers[parentInstance]
			for index,instance in ipairs(isVirtual and getVirtualChildren(parentInstance) or parentInstance:GetChildren()) do
				if isVirtual then print(instance, "is virtual") end
				if not bannedInstances[instance] then
					local instContainer = instantiateContainer(instance)
					local hasChildren = isVirtual and #getVirtualChildren(instance) > 0 or #instance:GetChildren() > 0

					instContainer.LayoutOrder = orderedServices[instance] or index
					instContainer.Visible = (filterEnabled and searchInstances[instance]) or (not filterEnabled)

					instContainer.Header.ChildrenViewToggle.ToggleIcon.Image = (filterEnabled or instContainer:GetAttribute("Expanded")) and studioIcons.ArrowExpanded or studioIcons.ArrowCollapsed
					instContainer.Header.ChildrenViewToggle.Visible = #instance:GetChildren() > 0
					instContainer.Header.InstanceName.Text = instance.Name
					local bounds = TextService:GetTextSize(
						instance.Name,
						instContainer.Header.InstanceName.TextSize,
						instContainer.Header.InstanceName.Font,
						Vector2.zero
					)
					instContainer.Header.InstanceName.Size = UDim2.new(0, bounds.X, 1, 0)

					if parentContainer then
						instContainer.Parent = parentContainer.Children
					else -- top-level services
						instContainer.Parent = instancesList
					end

					instContainer.Name = instance.Name
					if (not filterEnabled and hasChildren and instContainer:GetAttribute("Expanded")) or (toShow and toShow:IsDescendantOf(instance)) or (filterEnabled and searchInstances[instance]) then
						--instContainer.Children.Visible = true
						temp.internal.instanceView.recursiveScan(instance)
					end
					fixInstanceIndices()
				end
			end
			clearHangingInstances()
		end

		temp.internal.instanceView.fullScan = function()
			temp.internal.instanceView.recursiveScan(game)
			temp.internal.instanceView.recursiveScan(virtualViews)
		end

		local searching, searchTask: thread = false, nil
		local processingSearch = false
		local function processSearch()
			processingSearch = true
			if searching then
				searchStatus.Visible = false
				searching = false
				searchInstances = {}
				if searchTask then
					repeat
						task.wait()
					until coroutine.status(searchTask) == "dead"
					searchTask = nil
				end
			end
			local keyword = filterBox.Text:lower()
			searching = keyword ~= ""
			if searching then
				searchStatus.Text = "Searching..."
				searchStatus.Visible = true
				local propertySearch = false
				local _, _, propertyName, propertyValue = filterBox.Text:find("(%a+)%s*=%s*(%w+)")
				if propertyName and propertyValue then
					print(propertyName, "=", propertyValue)
					propertySearch = true
				end
				searchTask = task.spawn(function()
					searchInstances = {}
					local descendants = {}
					local function recursive_desc(par)
						for _,inst in ipairs(par:GetChildren()) do
							if not bannedInstances[inst] then
								table.insert(descendants, inst)
								recursive_desc(inst)
							end
						end
					end
					recursive_desc(game)
					for _,inst in ipairs(getnilinstances()) do
						if not bannedInstances[inst] then
							table.insert(descendants, inst)
							recursive_desc(inst)
						end
					end
					local count = 0
					local i, iMax = 0, #descendants
					filterEnabled = false
					local f, err
					for _,instance in pairs(descendants) do
						if not searching or not temp or not temp.running then break end
						i += 1
						searchStatus.Text = string.format("Searching... (%.01f%%)", i/iMax*100)
						f, err = pcall(function()
							if not propertySearch and instance.Name:lower():find(keyword, nil, true) then
								searchInstances[instance] = true
								filterEnabled = true
							elseif propertySearch and api.RBXApi.Classes[instance.ClassName] and
								api.RBXApi.Classes[instance.ClassName].Properties[propertyName] and
								tostring(instance[propertyName]):lower():find(propertyValue, nil, true) then
								searchInstances[instance] = true
								filterEnabled = true
							end
							if searchInstances[instance] then
								count += 1
								local parentInstance = instance.Parent or nilInstancesView
								while parentInstance ~= game and parentInstance ~= nil and searching and temp and temp.running do
									searchInstances[parentInstance] = true
									parentInstance = parentInstance.Parent
								end
								temp.internal.instanceView.fullScan()
								task.wait()
							end
						end)
						if not f then
							warn(err)
							break
						end
					end
					if searching then
						searching = false
						searchStatus.Text = string.format("Found %d matches", count)
						searchStatus.Visible = true
						temp.internal.instanceView.fullScan()
					end
				end)
			elseif filterEnabled then
				searchStatus.Visible = false
				filterEnabled = false
				for inst,instContainer in pairs(temp.uiInstanceContainers) do
					local selected = false
					for sInst,_ in pairs(MeltedStudio.Selection) do
						if sInst and sInst.Parent then
							if sInst:IsDescendantOf(inst) then
								selected = true
								instContainer:SetAttribute("Expanded", true)
								break
							elseif sInst == inst then
								selected = true
								break
							end
						end
					end
					if not selected then
						instContainer:Destroy()
						temp.uiInstanceContainers[inst] = nil
					end
				end
				temp.internal.instanceView.fullScan()
			end
			processingSearch = false
		end

		table.insert(temp.connections, filterBox:GetPropertyChangedSignal("Text"):Connect(function()
			repeat task.wait() until not processingSearch
			processSearch()
		end))

		--function MeltedStudio.Explorer:ShowInstance(instance)
		--	if not instance then return end
		--	if searching or filterEnabled then return end
		--	toShow = instance
		--	recursiveScan(game)
		--	toShow = nil
		--	local instContainer = instantiateContainer(instance)
		--	instancesList.CanvasPosition = Vector2.new(0, instContainer.AbsolutePosition.Y + instancesList.CanvasPosition.Y - instancesList.AbsolutePosition.Y)
		--end

		temp.internal.instanceView.rename = function(instance)
			if not instance then return end
			local instContainer = temp.uiInstanceContainers[instance]
			if instContainer then
				instContainer.Header.InstanceName.Visible = false
				local rnbox: TextBox = instContainer.Header.RenameBox
				rnbox.Text = instContainer.Header.InstanceName.Text
				rnbox.Size = instContainer.Header.InstanceName.Size
				local minSize = rnbox.AbsoluteSize.X
				local resizeConn = rnbox:GetPropertyChangedSignal("Text"):Connect(function()
					local bounds = TextService:GetTextSize(
						rnbox.Text,
						rnbox.TextSize,
						rnbox.Font,
						Vector2.zero
					)
					rnbox.Size = UDim2.new(0, math.max(minSize, bounds.X), 1, 0)
				end)
				table.insert(temp.connections, resizeConn)
				rnbox.Visible = true
				rnbox:CaptureFocus()

				local enterPressed, input = rnbox.FocusLost:Wait()

				resizeConn:Disconnect()
				rnbox.Visible = false
				instContainer.Header.InstanceName.Visible = true
				local oldName = instance.Name
				if (enterPressed or not (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape)) and oldName ~= rnbox.Text then
					instance.Name = rnbox.Text
					instContainer.Header.InstanceName.Text = rnbox.Text
					return rnbox.Text
				end
			end
		end

		task.spawn(function()
			while temp and temp.running do
				if not searching and not processingSearch then
					temp.internal.instanceView.fullScan()
					updateSelected()
				end
				task.wait(MeltedStudio.UpdateRate)
			end
		end)
	end

	local propertiesView = explorer:WaitForChild("PropertiesView")
	local propertiesList = propertiesView:WaitForChild("PropertiesList")
	local tCategoryContainer = propertiesList:WaitForChild("CategoryContainer")
	tCategoryContainer.Parent = nil
	local tPropertiesContainer = tCategoryContainer:WaitForChild("PropertiesContainer")
	tPropertiesContainer.Visible = false
	tPropertiesContainer:WaitForChild("BaseProperty"):Destroy() -- used for building then UI
	local tBoolProperty = tPropertiesContainer:WaitForChild("BoolProperty")
	tBoolProperty.Parent = nil
	local tStringProperty = tPropertiesContainer:WaitForChild("StringProperty")
	tStringProperty.Parent = nil
	local tNumberProperty = tPropertiesContainer:WaitForChild("NumberProperty")
	tNumberProperty.Parent = nil

	do -- properties view
		local templates = { -- templates LUT
			Class = false,
			["Enum"] = false,
			DataType = {
				["Vector2"] = false,
				["Vector3"] = false,
				["CFrame"] = false,
				["UDim"] = false,
				["UDim2"] = false
			},
			Primitive = {
				["bool"] = tBoolProperty,
				["double"] = tNumberProperty,
				["float"] = tNumberProperty,
				["int"] = tNumberProperty,
				["int64"] = tNumberProperty,
				["string"] = tStringProperty
			}
		}

		-- category setup

		local function SetupCategory(memberData)
			if not memberData.Category then return end
			if temp.uiPropertyContainers[memberData.Category] then return end

			local container = tCategoryContainer:Clone()
			container:SetAttribute("Expanded", true)
			container.Header.CategoryName.Text = memberData.Category
			container.Header.ToggleIcon.Image = studioIcons.ArrowExpanded
			container.PropertiesContainer.Visible = true

			container.Header.Activated:Connect(function()
				local expanded = not container:GetAttribute("Expanded")
				container:SetAttribute("Expanded", expanded)
				container.PropertiesContainer.Visible = expanded
				container.Header.ToggleIcon.Image = expanded and studioIcons.ArrowExpanded or studioIcons.ArrowCollapsed
			end)

			container.Name = memberData.Category .. "_Category"
			container.Parent = propertiesList

			temp.uiPropertyContainers[memberData.Category] = container
		end

		-- templates setup

		local function SetInstancesProperty(propertyName, propertyValue)
			local class = nil
			for inst,_ in pairs(MeltedStudio.Selection) do
				class = api.RBXApi.Classes[inst.ClassName]
				if class and class.Properties[propertyName] and inst[propertyName] ~= propertyValue then
					xpcall(function() inst[propertyName] = propertyValue end, function(err)
						print("MeltedStudio boolean set error: failed to set value", propertyName, "of", inst, ":", err)
					end)
				end
			end
		end

		local function BuildProperty(property, memberData)
			if memberData.Tags["ReadOnly"] then
				property.PropertyName.TextColor3 = Colors.Properties.ReadOnly
			end
			if memberData.ValueType.Name == "bool" then -- BoolProperty
				if memberData.Tags["ReadOnly"] then
					property.Interactable = false
					property.PropertyData.PropertyValue.ImageColor3 = Colors.Properties.ReadOnly
				else
					property.PropertyData.PropertyValue.Activated:Connect(function()
						property.CommonValue.Value = not property.CommonValue.Value
						SetInstancesProperty(memberData.Name, property.CommonValue.Value)
					end)
				end
			elseif memberData.ValueType.Name == "string" then
				property:SetAttribute("Focused", false)
				if memberData.Tags["ReadOnly"] then
					property.PropertyData.PropertyValue.TextEditable = false
					property.PropertyData.PropertyValue.TextColor3 = Colors.Properties.ReadOnly
				else
					property.PropertyData.PropertyValue.Focused:Connect(function()
						property:SetAttribute("Focused", true)
						property.PropertyData.BackgroundColor3 = Colors.Properties.Focused
					end)
					property.PropertyData.PropertyValue.FocusLost:Connect(function(enterPressed, input)
						property:SetAttribute("Focused", false)
						property.PropertyData.BackgroundColor3 = defaultBgCol
						if enterPressed then
							property.CommonValue.Value = property.PropertyData.PropertyValue.Text
							SetInstancesProperty(memberData.Name, property.CommonValue.Value)
						else
							property.PropertyData.PropertyValue.Text = property.CommonValue.Value
						end
					end)
				end
			elseif memberData.ValueType.Category == "Primitive" then -- other primitives: numbers
				property:SetAttribute("Focused", false)
				if memberData.Tags["ReadOnly"] then
					property.PropertyData.PropertyValue.TextEditable = false
					property.PropertyData.PropertyValue.TextColor3 = Colors.Properties.ReadOnly
				else
					property.PropertyData.PropertyValue.Focused:Connect(function()
						property:SetAttribute("Focused", true)
						property.PropertyData.BackgroundColor3 = Colors.Properties.Focused
					end)
					property.PropertyData.PropertyValue.FocusLost:Connect(function(enterPressed, input)
						property:SetAttribute("Focused", false)
						property.PropertyData.BackgroundColor3 = defaultBgCol
						local newValue = tonumber(property.PropertyData.PropertyValue.Text)
						if enterPressed and newValue then
							property.CommonValue.Value = newValue
							SetInstancesProperty(memberData.Name, newValue)
						else
							property.PropertyData.PropertyValue.Text = property.CommonValue.Value
						end
					end)
				end
			end
		end

		local function UpdateProperty(property, memberData)
			local class = nil
			local commonValue = nil
			local commonValueSet = false
			local valueIsCommon = true
			for inst,_ in pairs(MeltedStudio.Selection) do
				class = api.RBXApi.Classes[inst.ClassName]
				if class and class.Properties[memberData.Name] then
					if not commonValueSet then
						commonValue = inst[memberData.Name]
						commonValueSet = true
					elseif inst[memberData.Name] ~= commonValue then
						valueIsCommon = false
						break
					end
				end
			end

			if memberData.ValueType.Name == "bool" then -- BoolProperty
				property.PropertyData.PropertyValue.Image = valueIsCommon and
					(commonValue and
						"rbxasset://textures/DeveloperFramework/checkbox_checked_light.png" or
						"rbxasset://textures/DeveloperFramework/checkbox_unchecked_dark.png"
					) or "rbxasset://textures/DeveloperFramework/checkbox_indeterminate_dark.png"
			elseif memberData.ValueType.Name == "string" then
				if not property:GetAttribute("Focused") then
					property.PropertyData.PropertyValue.Text = valueIsCommon and commonValue or ""
				end
			elseif memberData.ValueType.Category == "Primitive" then
				commonValue = math.floor(commonValue * 100 + .5) * 0.01
				if not property:GetAttribute("Focused") then
					property.PropertyData.PropertyValue.Text = valueIsCommon and tostring(commonValue) or ""
				else
					print("Property", memberData.Name, "is focused")
				end
			end
			property.CommonValue.Value = commonValue
		end

		local function SetupProperty(memberData)
			local vt = memberData.ValueType
			if not templates[vt.Category] then return end

			local propName = "Property_" .. memberData.Name
			if temp.uiPropertyContainers[memberData.Category] and temp.uiPropertyContainers[memberData.Category].PropertiesContainer:FindFirstChild(propName) then return end

			local property = nil

			if vt.Category == "Class" and templates.Class then
			elseif vt.Category == "Enum" and templates.Enum then
			elseif vt.Category == "DataType" and templates.DataType[vt.Name] then
			elseif vt.Category == "Primitive" and templates.Primitive[vt.Name] then
				property = templates.Primitive[vt.Name]:Clone()
			end

			if property then -- template found
				if not temp.uiPropertyContainers[memberData.Category] then
					SetupCategory(memberData)
				end
				property.PropertyName.Text = memberData.Name

				property.Name = propName
				BuildProperty(property, memberData)
				UpdateProperty(property, memberData)

				local class = nil
				for inst,_ in pairs(MeltedStudio.Selection) do
					class = api.RBXApi.Classes[inst.ClassName]
					if class and class.Properties[memberData.Name] then
						table.insert(temp.uiPropertyConnections, inst:GetPropertyChangedSignal(memberData.Name):Connect(function()
							UpdateProperty(property, memberData)
						end))
					end
				end

				property.Parent = temp.uiPropertyContainers[memberData.Category].PropertiesContainer
			end
			return property
		end

		local function ClearProperties()
			for _,category in pairs(temp.uiPropertyContainers) do
				pcall(category.Destroy, category)
			end
			temp.uiPropertyContainers = {}
			for _,conn in pairs(temp.uiPropertyConnections) do
				pcall(conn.Disconnect, conn)
			end
			temp.uiPropertyConnections = {}
		end

		local function UpdatePropertiesView()
			ClearProperties()
			task.wait()
			for inst,_ in pairs(MeltedStudio.Selection) do
				for _, propertyData in pairs(api:GetClassProperties(inst.ClassName,
					{Hidden = false, Deprecated = false, NotScriptable = false},
					api.SecurityLevels.None
					)) do
					local property = SetupProperty(propertyData)
					if property then
						local conn
						conn = inst:GetPropertyChangedSignal(propertyData.Name):Connect(function()
							if not property then
								conn:Disconnect()
								return
							end
							UpdateProperty(property, propertyData)
						end)
						table.insert(temp.uiPropertyConnections, conn)
					end
				end
			end
		end
		table.insert(temp.connections, MeltedStudio.SelectionChanged:Connect(UpdatePropertiesView))
	end
end

explorer.Visible = true

function MeltedStudio.Remove()
	_G.MeltedStudio.Remove = nil
	temp.running = false
	script.Parent:Destroy()
	task.wait()
	for _,conn in pairs(temp.connections) do
		pcall(conn.Disconnect, conn)
	end
	for _,conn in pairs(temp.uiPropertyConnections) do
		pcall(conn.Disconnect, conn)
	end
	temp = nil
	_G.MeltedStudio = nil
end

_G.MeltedStudio = MeltedStudio

if script:IsA("ModuleScript") then return {} end