local api = {
	Loading = {
		Loaded = false,
		LoadFunc = nil
	}
}

if not _G.SafeGetService then
	error("No safe way to get services!")
end

local RunService = _G.SafeGetService("RunService")

api.Loading.LoadApi = function()
	if api.Loading.Loaded then return end
	pcall(api.Loading.LoadFunc, .3, "Downloading Roblox API...")
	
	local apiVersion, rawDump
	if RunService:IsStudio() then
		local remote = _G.SafeGetService("ReplicatedStorage"):WaitForChild("HelperRemote")
		apiVersion = remote:InvokeServer("https://s3.amazonaws.com/setup.roblox.com/versionQTStudio", true)
		rawDump = _G.SafeGetService("HttpService"):JSONDecode(
			remote:InvokeServer(string.format("https://s3.amazonaws.com/setup.roblox.com/%s-Full-API-Dump.json", apiVersion), true)
		)
		print(string.format("Downloaded API from https://s3.amazonaws.com/setup.roblox.com/%s-Full-API-Dump.json", apiVersion))
	else
		apiVersion = _G.HttpGet("https://s3.amazonaws.com/setup.roblox.com/versionQTStudio", true)
		rawDump = _G.SafeGetService("HttpService"):JSONDecode(
			_G.HttpGet(string.format("https://s3.amazonaws.com/setup.roblox.com/%s-Full-API-Dump.json", apiVersion), true)
		)
	end

	pcall(api.Loading.LoadFunc, 0.75, string.format("Parsing Roblox API (version %s)...", tostring(apiVersion)))
	
	api.RBXApi = {
		Classes = {},
		DataTypes = {},
		Enums = {},
		Version = apiVersion
	}

	if RunService:IsStudio() then
		api.RBXApi.Debug = {
			MemberCategories = {},
			MemberTypes = {},
			Classes = {},
			ValueType_Categories = {},
			ValueType_Names = {},
			Tags = {}
		}
		do
			local debug = {
				["MemberTypes"] = {
					["Callback"] = true,
					["Event"] = true,
					["Function"] = true,
					["Property"] = true
				},
				["MemoryCategories"] = {
					["Animation"] = true,
					["GraphicsTexture"] = true,
					["Gui"] = true,
					["Instances"] = true,
					["Internal"] = true,
					["PhysicsParts"] = true,
					["Script"] = true
				},
				["Tags"] = {
					["CanYield"] = true,
					["CustomLuaState"] = true,
					["Deprecated"] = true,
					["Hidden"] = true,
					["NoYield"] = true,
					["NotBrowsable"] = true,
					["NotCreatable"] = true,
					["NotReplicated"] = true,
					["NotScriptable"] = true,
					["PlayerReplicated"] = true,
					["ReadOnly"] = true,
					["Service"] = true,
					["Settings"] = true,
					["UserSettings"] = true,
					["Yields"] = true
				}
			}
		end
		
		local function dbgGetTags(obj)
			if obj.Tags then
				for k,tag in pairs(obj.Tags) do
					if type(tag) == "string" then
						api.RBXApi.Debug.Tags[tag] = true
					else
						api.RBXApi.Debug.Tags[k] = tag
					end
				end
			end
		end
		
		for _,class in pairs(rawDump.Classes) do
			--api.RBXApi.Debug.Classes[class.Name] = class
			dbgGetTags(class)
			for _,member in pairs(class.Members) do
				if member.MemberType == "Property" then
					api.RBXApi.Debug.MemberCategories[member.Category] = true
					api.RBXApi.Debug.ValueType_Categories[member.ValueType.Category] = true
					if not api.RBXApi.Debug.ValueType_Names[member.ValueType.Category] then
						api.RBXApi.Debug.ValueType_Names[member.ValueType.Category] = {}
					end
					api.RBXApi.Debug.ValueType_Names[member.ValueType.Category][member.ValueType.Name] = true
				end
				api.RBXApi.Debug.MemberTypes[member.MemberType] = true
				dbgGetTags(member)
			end
		end
		for _,enum in pairs(rawDump.Enums) do
			dbgGetTags(enum)
			for _,item in pairs(enum.Items) do
				dbgGetTags(item)
			end
		end
		print(api.RBXApi.Debug)
	end
	
	local function fixTags(obj)
		local tags = {}
		if obj.Tags then
			for k,tag in pairs(obj.Tags) do
				if typeof(tag) == "string" then
					tags[tag] = true
				else
					tags[k] = tag
				end
			end
		end
		obj.Tags = tags
	end
	
	pcall(api.Loading.LoadFunc, .8, "Parsing Enums...")
	for _,enum in pairs(rawDump.Enums) do -- enums pass
		api.RBXApi.Enums[enum.Name] = {
			Items = {},
			Tags = enum.Tags
		}
		fixTags(api.RBXApi.Enums[enum.Name])
		for _,item in pairs(enum.Items) do
			api.RBXApi.Enums[enum.Name].Items[item.Name] = {
				Value = item.Value,
				Tags = item.Tags
			}
			fixTags(api.RBXApi.Enums[enum.Name].Items[item.Name])
		end
	end

	pcall(api.Loading.LoadFunc, .85, "Parsing Classes...")
	for _,class in pairs(rawDump.Classes) do -- classes pass
		fixTags(class)
		api.RBXApi.Classes[class.Name] = {}
		for k,v in pairs(class) do
			api.RBXApi.Classes[class.Name][k] = v
		end
	end
	
	for _,class in pairs(api.RBXApi.Classes) do -- superclass reference pass
		if class.Superclass and api.RBXApi.Classes[class.Superclass] then
			class.Superclass = api.RBXApi.Classes[class.Superclass]
		else
			class.Superclass = nil
		end
	end
	
	local function getMembersRecursive(className)
		local members = {}
		local currentClass = api.RBXApi.Classes[className]
		while currentClass do
			if currentClass.Members then
				for _,member in pairs(currentClass.Members) do
					table.insert(members, member)
				end
			end
			currentClass = currentClass.Superclass
		end
		return members
	end 

	pcall(api.Loading.LoadFunc, .9, "Parsing Members...")
	for _,class in pairs(api.RBXApi.Classes) do -- members pass
		local members = getMembersRecursive(class.Name)
		
		class.Callbacks = {}
		class.Events = {}
		class.Functions = {}
		class.Properties = {}
		for _,member in pairs(members) do -- members pass
			fixTags(member)
			if member.MemberType == "Callback" then
				class.Callbacks[member.Name] = member
			elseif member.MemberType == "Event" then
				class.Events[member.Name] = member
			elseif member.MemberType == "Function" then
				class.Functions[member.Name] = member
			elseif member.MemberType == "Property" then
				class.Properties[member.Name] = member
			end
		end
	end

	pcall(api.Loading.LoadFunc, .9, "Excess data cutoff...")
	for _,class in pairs(api.RBXApi.Classes) do -- excess data cutoff after recursive search
		class.Members = nil
	end
	
	for _,class in pairs(api.RBXApi.Classes) do
		for _,property in pairs(class.Properties) do
			if not api.RBXApi.DataTypes[property.ValueType.Category] then
				api.RBXApi.DataTypes[property.ValueType.Category] = {}
			end
			api.RBXApi.DataTypes[property.ValueType.Category][property.ValueType.Name] = true
		end
	end
	
	local function internalHasTags(obj, tags)
		if not obj or not obj.Tags then return false end
		if not tags then return true end
		
		for tag,active in pairs(tags) do
			if (active and not obj.Tags[tag]) or (not active and obj.Tags[tag]) then
				return false
			end
		end
		return true
	end
	
	api.SecurityLevels = {
		None = 0,
		PluginSecurity = 1,
		LocalUserSecurity = 2,
		WritePlayerSecurity = 3,
		RobloxPlaceSecurity = 4,
		RobloxScriptSecurity = 5,
		RobloxSecurity = 6,
		NotAccessibleSecurity = 7
	}
	local function internalHasSecurity(obj, securityLevel)
		if not obj or not obj.Security then return false end
		if not securityLevel then return true end

		if type(securityLevel) == "string" then
			if api.SecurityLevels[securityLevel] then
				securityLevel = api.SecurityLevels[securityLevel]
			else
				return false
			end
		end

		if type(securityLevel) == "number" then
			for rw,security in pairs(obj.Security) do
				if api.SecurityLevels[security] > securityLevel then
					return false
				end
			end
			return true
		elseif type(securityLevel) == "table" then
			for state,security in pairs(securityLevel) do
				if not obj.Security[state] or api.SecurityLevels[ obj.Security[state] ] > security then
					return false
				end 
			end
			return true
		end
		return false
	end
	
	function api:ClassHasTags(className, tags)
		return internalHasTags(api.RBXApi.Classes[className], tags)
	end
	
	function api:GetClasses(tags)
		if not tags then
			return api.RBXApi.Classes
		end
		local results = {}
		for _,class in pairs(api.RBXApi.Classes) do
			if internalHasTags(class, tags) then
				results[class.Name] = class
			end
		end
		return results
	end
	
	function api:GetClassProperties(className, tags, securityLevel)
		if not api.RBXApi.Classes[className] then
			warn(string.format("No classname '%s' in RBXApi, assuming Instance", className))
			className = "Instance"
		end
		if not tags then
			return api.RBXApi.Classes[className].Properties
		end
		local results = {}
		for propertyName,property in pairs(api.RBXApi.Classes[className].Properties) do
			if internalHasTags(property, tags) and internalHasSecurity(property, securityLevel or api.SecurityLevels.None) then
				results[property.Name] = property
			end
		end
		return results
	end
	
	function api:GetClassPropertiesByCategories(className, tags, securityLevel)
		local results = {}
		for _,property in pairs(api:GetClassPropertiesWithTags(className, tags, securityLevel)) do
			if not results[property.Category] then
				results[property.Category] = {}
			end
			results[property.Category][property.Name] = property
		end
		return results
	end

	pcall(api.Loading.LoadFunc, .95, "Memory cleanup...")
	rawDump = nil -- clear memory
	
	pcall(api.Loading.LoadFunc, 1, "Done")
end

do -- Class images
	api.ClassIcons = {
		Source = "rbxassetid://15125399710",
		SourceLegacy = "rbxasset://textures/ClassImages.png",
		OnlyUseNewIcons = false
	}
	
	local ImageRectOffsets = {
		["Accessory"] = Vector2.zero,
		["Accoutrement"] = Vector2.new(16, 0),
		["Actor"] = Vector2.new(32, 0),
		["AdGui"] = Vector2.new(48, 0),
		["AdPortal"] = Vector2.new(64, 0),
		["AdService"] = Vector2.new(80, 0),
		["AdvancedDragger"] = Vector2.new(96, 0),
		["AirController"] = Vector2.new(112, 0),
		["AlignOrientation"] = Vector2.new(128, 0),
		["AlignPosition"] = Vector2.new(144, 0),
		["AnalysticsService"] = Vector2.new(160, 0),
		["AnalysticsSettings"] = Vector2.new(176, 0),
		["AnalyticsService"] = Vector2.new(192, 0),
		["AngularVelocity"] = Vector2.new(208, 0),
		["Animation"] = Vector2.new(224, 0),
		["AnimationClip"] = Vector2.new(240, 0),
		["AnimationClipProvider"] = Vector2.new(256, 0),
		["AnimationController"] = Vector2.new(272, 0),
		["AnimationFromVideoCreatorService"] = Vector2.new(288, 0),
		["AnimationFromVideoCreatorStudioService"] = Vector2.new(304, 0),
		["AnimationRigData"] = Vector2.new(320, 0),
		["AnimationStreamTrack"] = Vector2.new(336, 0),
		["AnimationTrack"] = Vector2.new(352, 0),
		["Animator"] = Vector2.new(368, 0),
		["AppStorageService"] = Vector2.new(384, 0),
		["AppUpdateService"] = Vector2.new(400, 0),
		["ArcHandles"] = Vector2.new(416, 0),
		["AssetCounterService"] = Vector2.new(432, 0),
		["AssetDeliveryProxy"] = Vector2.new(448, 0),
		["AssetImportService"] = Vector2.new(464, 0),
		["AssetImportSession"] = Vector2.new(480, 0),
		["AssetManagerService"] = Vector2.new(496, 0),
		["AssetService"] = Vector2.new(512, 0),
		["AssetSoundEffect"] = Vector2.new(528, 0),
		["Atmosphere"] = Vector2.new(544, 0),
		["Attachment"] = Vector2.new(560, 0),
		["AvatarEditorService"] = Vector2.new(576, 0),
		["AvatarImportService"] = Vector2.new(592, 0),
		["Backpack"] = Vector2.new(608, 0),
		["BackpackItem"] = Vector2.new(624, 0),
		["BadgeService"] = Vector2.new(640, 0),
		["BallSocketConstraint"] = Vector2.new(656, 0),
		["BasePart"] = Vector2.new(672, 0),
		["BasePlayerGui"] = Vector2.new(688, 0),
		["BaseScript"] = Vector2.new(704, 0),
		["BaseWrap"] = Vector2.new(720, 0),
		["Beam"] = Vector2.new(736, 0),
		["BevelMesh"] = Vector2.new(752, 0),
		["BillboardGui"] = Vector2.new(768, 0),
		["BinaryStringValue"] = Vector2.new(784, 0),
		["BindableEvent"] = Vector2.new(800, 0),
		["BindableFunction"] = Vector2.new(816, 0),
		["BlockMesh"] = Vector2.new(832, 0),
		["BloomEffect"] = Vector2.new(848, 0),
		["BlurEffect"] = Vector2.new(864, 0),
		["BodyAngularVelocity"] = Vector2.new(880, 0),
		["BodyColors"] = Vector2.new(896, 0),
		["BodyForce"] = Vector2.new(912, 0),
		["BodyGyro"] = Vector2.new(928, 0),
		["BodyMover"] = Vector2.new(944, 0),
		["BodyPosition"] = Vector2.new(960, 0),
		["BodyThrust"] = Vector2.new(976, 0),
		["BodyVelocity"] = Vector2.new(992, 0),
		["Bone"] = Vector2.new(1008, 0),
		["BoolValue"] = Vector2.new(0, 16),
		["BoxHandleAdornment"] = Vector2.new(16, 16),
		["Breakpoint"] = Vector2.new(32, 16),
		["BreakpointManager"] = Vector2.new(48, 16),
		["BrickColorValue"] = Vector2.new(64, 16),
		["BrowserService"] = Vector2.new(80, 16),
		["BubbleChatConfiguration"] = Vector2.new(96, 16),
		["BulkImportService"] = Vector2.new(112, 16),
		["CFrameValue"] = Vector2.new(128, 16),
		["CSGDictionaryService"] = Vector2.new(144, 16),
		["CacheableContentProvider"] = Vector2.new(160, 16),
		["CalloutService"] = Vector2.new(176, 16),
		["Camera"] = Vector2.new(192, 16),
		["CanvasGroup"] = Vector2.new(208, 16),
		["CatalogPages"] = Vector2.new(224, 16),
		["ChangeHistoryService"] = Vector2.new(240, 16),
		["ChannelSelectorSoundEffect"] = Vector2.new(256, 16),
		["CharacterAppearance"] = Vector2.new(272, 16),
		["CharacterMesh"] = Vector2.new(288, 16),
		["Chat"] = Vector2.new(304, 16),
		["ChatInputBarConfiguration"] = Vector2.new(320, 16),
		["ChatWindowConfiguration"] = Vector2.new(336, 16),
		["ChorusSoundEffect"] = Vector2.new(352, 16),
		["ClickDetector"] = Vector2.new(368, 16),
		["ClientReplicator"] = Vector2.new(384, 16),
		["ClimbController"] = Vector2.new(400, 16),
		["Clothing"] = Vector2.new(416, 16),
		["Clouds"] = Vector2.new(432, 16),
		["ClusterPacketCache"] = Vector2.new(448, 16),
		["CollectionService"] = Vector2.new(464, 16),
		["Color3Value"] = Vector2.new(480, 16),
		["ColorCorrectionEffect"] = Vector2.new(496, 16),
		["CommandInstance"] = Vector2.new(512, 16),
		["CommandService"] = Vector2.new(528, 16),
		["CompressorSoundEffect"] = Vector2.new(544, 16),
		["ConeHandleAdornment"] = Vector2.new(560, 16),
		["Configuration"] = Vector2.new(576, 16),
		["ConfigureServerService"] = Vector2.new(592, 16),
		["Constraint"] = Vector2.new(608, 16),
		["ContentProvider"] = Vector2.new(624, 16),
		["ContextActionService"] = Vector2.new(640, 16),
		["Controller"] = Vector2.new(656, 16),
		["ControllerBase"] = Vector2.new(672, 16),
		["ControllerManager"] = Vector2.new(688, 16),
		["ControllerService"] = Vector2.new(704, 16),
		["CookiesService"] = Vector2.new(720, 16),
		["CoreGui"] = Vector2.new(736, 16),
		["CorePackages"] = Vector2.new(752, 16),
		["CoreScript"] = Vector2.new(768, 16),
		["CoreScriptSyncService"] = Vector2.new(784, 16),
		["CornerWedgePart"] = Vector2.new(800, 16),
		["CrossDMScriptChangeListener"] = Vector2.new(816, 16),
		["CurveAnimation"] = Vector2.new(832, 16),
		["CustomEvent"] = Vector2.new(848, 16),
		["CustomEventReceiver"] = Vector2.new(864, 16),
		["CustomSoundEffect"] = Vector2.new(880, 16),
		["CylinderHandleAdornment"] = Vector2.new(896, 16),
		["CylinderMesh"] = Vector2.new(912, 16),
		["CylindricalConstraint"] = Vector2.new(928, 16),
		["DataModel"] = Vector2.new(944, 16),
		["DataModelMesh"] = Vector2.new(960, 16),
		["DataModelPatchService"] = Vector2.new(976, 16),
		["DataModelSession"] = Vector2.new(992, 16),
		["DataStore"] = Vector2.new(1008, 16),
		["DataStoreIncrementOptions"] = Vector2.new(0, 32),
		["DataStoreInfo"] = Vector2.new(16, 32),
		["DataStoreKey"] = Vector2.new(32, 32),
		["DataStoreKeyInfo"] = Vector2.new(48, 32),
		["DataStoreKeyPages"] = Vector2.new(64, 32),
		["DataStoreListingPages"] = Vector2.new(80, 32),
		["DataStoreObjectVersionInfo"] = Vector2.new(96, 32),
		["DataStoreOptions"] = Vector2.new(112, 32),
		["DataStorePages"] = Vector2.new(128, 32),
		["DataStoreService"] = Vector2.new(144, 32),
		["DataStoreSetOptions"] = Vector2.new(160, 32),
		["DataStoreVersionPages"] = Vector2.new(176, 32),
		["Debris"] = Vector2.new(192, 32),
		["DebugSettings"] = Vector2.new(208, 32),
		["DebuggablePluginWatcher"] = Vector2.new(224, 32),
		["DebuggerBreakpoint"] = Vector2.new(240, 32),
		["DebuggerConnection"] = Vector2.new(256, 32),
		["DebuggerConnectionManager"] = Vector2.new(272, 32),
		["DebuggerLuaResponse"] = Vector2.new(288, 32),
		["DebuggerManager"] = Vector2.new(304, 32),
		["DebuggerUIService"] = Vector2.new(320, 32),
		["DebuggerVariable"] = Vector2.new(336, 32),
		["DebuggerWatch"] = Vector2.new(352, 32),
		["Decal"] = Vector2.new(368, 32),
		["DepthOfFieldEffect"] = Vector2.new(384, 32),
		["DeviceIdService"] = Vector2.new(400, 32),
		["Dialog"] = Vector2.new(416, 32),
		["DialogChoice"] = Vector2.new(432, 32),
		["DistortionSoundEffect"] = Vector2.new(448, 32),
		["DockWidgetPluginGui"] = Vector2.new(464, 32),
		["DoubleConstrainedValue"] = Vector2.new(480, 32),
		["DraftsService"] = Vector2.new(496, 32),
		["Dragger"] = Vector2.new(512, 32),
		["DraggerService"] = Vector2.new(528, 32),
		["DynamicRotate"] = Vector2.new(544, 32),
		["EchoSoundEffect"] = Vector2.new(560, 32),
		["EmotesPages"] = Vector2.new(576, 32),
		["EqualizerSoundEffect"] = Vector2.new(592, 32),
		["EulerRotationCurve"] = Vector2.new(608, 32),
		["EventIngestService"] = Vector2.new(624, 32),
		["Explosion"] = Vector2.new(640, 32),
		["FaceAnimatorService"] = Vector2.new(656, 32),
		["FaceControls"] = Vector2.new(672, 32),
		["FaceInstance"] = Vector2.new(688, 32),
		["FacialAnimationRecordingService"] = Vector2.new(704, 32),
		["FacialAnimationStreamingService"] = Vector2.new(720, 32),
		["Feature"] = Vector2.new(736, 32),
		["File"] = Vector2.new(752, 32),
		["FileMesh"] = Vector2.new(768, 32),
		["Fire"] = Vector2.new(784, 32),
		["Flag"] = Vector2.new(800, 32),
		["FlagStand"] = Vector2.new(816, 32),
		["FlagStandService"] = Vector2.new(832, 32),
		["FlangeSoundEffect"] = Vector2.new(848, 32),
		["FloatCurve"] = Vector2.new(864, 32),
		["FloorWire"] = Vector2.new(880, 32),
		["FlyweightService"] = Vector2.new(896, 32),
		["Folder"] = Vector2.new(912, 32),
		["ForceField"] = Vector2.new(928, 32),
		["FormFactorPart"] = Vector2.new(944, 32),
		["Frame"] = Vector2.new(960, 32),
		["FriendPages"] = Vector2.new(976, 32),
		["FriendService"] = Vector2.new(992, 32),
		["FunctionalTest"] = Vector2.new(1008, 32),
		["GamePassService"] = Vector2.new(0, 48),
		["GameSettings"] = Vector2.new(16, 48),
		["GamepadService"] = Vector2.new(32, 48),
		["GenericSettings"] = Vector2.new(48, 48),
		["Geometry"] = Vector2.new(64, 48),
		["GetTextBoundsParams"] = Vector2.new(80, 48),
		["GlobalDataStore"] = Vector2.new(96, 48),
		["GlobalSettings"] = Vector2.new(112, 48),
		["Glue"] = Vector2.new(128, 48),
		["GoogleAnalyticsConfiguration"] = Vector2.new(144, 48),
		["GroundController"] = Vector2.new(160, 48),
		["GroupService"] = Vector2.new(176, 48),
		["GuiBase"] = Vector2.new(192, 48),
		["GuiBase2d"] = Vector2.new(208, 48),
		["GuiBase3d"] = Vector2.new(224, 48),
		["GuiButton"] = Vector2.new(240, 48),
		["GuiLabel"] = Vector2.new(256, 48),
		["GuiMain"] = Vector2.new(272, 48),
		["GuiObject"] = Vector2.new(288, 48),
		["GuiService"] = Vector2.new(304, 48),
		["GuidRegistryService"] = Vector2.new(320, 48),
		["HSRDataContentProvider"] = Vector2.new(336, 48),
		["HandleAdornment"] = Vector2.new(352, 48),
		["Handles"] = Vector2.new(368, 48),
		["HandlesBase"] = Vector2.new(384, 48),
		["HapticService"] = Vector2.new(400, 48),
		["Hat"] = Vector2.new(416, 48),
		["HeightmapImporterService"] = Vector2.new(432, 48),
		["HiddenSurfaceRemovalAsset"] = Vector2.new(448, 48),
		["Highlight"] = Vector2.new(464, 48),
		["HingeConstraint"] = Vector2.new(480, 48),
		["Hint"] = Vector2.new(496, 48),
		["Hole"] = Vector2.new(512, 48),
		["Hopper"] = Vector2.new(528, 48),
		["HopperBin"] = Vector2.new(544, 48),
		["HttpRbxApiService"] = Vector2.new(560, 48),
		["HttpRequest"] = Vector2.new(576, 48),
		["HttpService"] = Vector2.new(592, 48),
		["Humanoid"] = Vector2.new(608, 48),
		["HumanoidController"] = Vector2.new(624, 48),
		["HumanoidDescription"] = Vector2.new(640, 48),
		["IKControl"] = Vector2.new(656, 48),
		["ILegacyStudioBridge"] = Vector2.new(672, 48),
		["IXPService"] = Vector2.new(688, 48),
		["ImageButton"] = Vector2.new(704, 48),
		["ImageHandleAdornment"] = Vector2.new(720, 48),
		["ImageLabel"] = Vector2.new(736, 48),
		["ImporterAnimationSettings"] = Vector2.new(752, 48),
		["ImporterBaseSettings"] = Vector2.new(768, 48),
		["ImporterFacsSettings"] = Vector2.new(784, 48),
		["ImporterGroupSettings"] = Vector2.new(800, 48),
		["ImporterJointSettings"] = Vector2.new(816, 48),
		["ImporterMaterialSettings"] = Vector2.new(832, 48),
		["ImporterMeshSettings"] = Vector2.new(848, 48),
		["ImporterRootSettings"] = Vector2.new(864, 48),
		["IncrementalPatchBuilder"] = Vector2.new(880, 48),
		["InputObject"] = Vector2.new(896, 48),
		["InsertService"] = Vector2.new(912, 48),
		["Instance"] = Vector2.new(928, 48),
		["InstanceAdornment"] = Vector2.new(944, 48),
		["IntConstrainedValue"] = Vector2.new(960, 48),
		["IntValue"] = Vector2.new(976, 48),
		["InventoryPages"] = Vector2.new(992, 48),
		["JointInstance"] = Vector2.new(1008, 48),
		["JointsService"] = Vector2.new(0, 64),
		["KeyboardService"] = Vector2.new(16, 64),
		["Keyframe"] = Vector2.new(32, 64),
		["KeyframeMarker"] = Vector2.new(48, 64),
		["KeyframeSequence"] = Vector2.new(64, 64),
		["KeyframeSequenceProvider"] = Vector2.new(80, 64),
		["LSPFileSyncService"] = Vector2.new(96, 64),
		["LanguageService"] = Vector2.new(112, 64),
		["LayerCollector"] = Vector2.new(128, 64),
		["LegacyStudioBridge"] = Vector2.new(144, 64),
		["Light"] = Vector2.new(160, 64),
		["Lighting"] = Vector2.new(176, 64),
		["LineForce"] = Vector2.new(192, 64),
		["LineHandleAdornment"] = Vector2.new(208, 64),
		["LinearVelocity"] = Vector2.new(224, 64),
		["LocalDebuggerConnection"] = Vector2.new(240, 64),
		["LocalScript"] = Vector2.new(256, 64),
		["LocalStorageService"] = Vector2.new(272, 64),
		["LocalizationService"] = Vector2.new(288, 64),
		["LocalizationTable"] = Vector2.new(304, 64),
		["LodDataEntity"] = Vector2.new(320, 64),
		["LodDataService"] = Vector2.new(336, 64),
		["LogService"] = Vector2.new(352, 64),
		["LoginService"] = Vector2.new(368, 64),
		["LuaSettings"] = Vector2.new(384, 64),
		["LuaSourceContainer"] = Vector2.new(400, 64),
		["LuaWebService"] = Vector2.new(416, 64),
		["LuauScriptAnalyzerService"] = Vector2.new(432, 64),
		["ManualGlue"] = Vector2.new(448, 64),
		["ManualSurfaceJointInstance"] = Vector2.new(464, 64),
		["ManualWeld"] = Vector2.new(480, 64),
		["MarkerCurve"] = Vector2.new(496, 64),
		["MarketplaceService"] = Vector2.new(512, 64),
		["MaterialService"] = Vector2.new(528, 64),
		["MaterialVariant"] = Vector2.new(544, 64),
		["MemStorageConnection"] = Vector2.new(560, 64),
		["MemStorageService"] = Vector2.new(576, 64),
		["MemoryStoreQueue"] = Vector2.new(592, 64),
		["MemoryStoreService"] = Vector2.new(608, 64),
		["MemoryStoreSortedMap"] = Vector2.new(624, 64),
		["MeshContentProvider"] = Vector2.new(640, 64),
		["MeshPart"] = Vector2.new(656, 64),
		["Message"] = Vector2.new(672, 64),
		["MessageBusConnection"] = Vector2.new(688, 64),
		["MessageBusService"] = Vector2.new(704, 64),
		["MessagingService"] = Vector2.new(720, 64),
		["MetaBreakpoint"] = Vector2.new(736, 64),
		["MetaBreakpointContext"] = Vector2.new(752, 64),
		["MetaBreakpointManager"] = Vector2.new(768, 64),
		["Model"] = Vector2.new(784, 64),
		["ModuleScript"] = Vector2.new(800, 64),
		["Motor"] = Vector2.new(816, 64),
		["Motor6D"] = Vector2.new(832, 64),
		["MotorFeature"] = Vector2.new(848, 64),
		["Mouse"] = Vector2.new(864, 64),
		["MouseService"] = Vector2.new(880, 64),
		["MultipleDocumentInterfaceInstance"] = Vector2.new(896, 64),
		["NegateOperation"] = Vector2.new(912, 64),
		["NetworkClient"] = Vector2.new(928, 64),
		["NetworkMarker"] = Vector2.new(944, 64),
		["NetworkPeer"] = Vector2.new(960, 64),
		["NetworkReplicator"] = Vector2.new(976, 64),
		["NetworkServer"] = Vector2.new(992, 64),
		["NetworkSettings"] = Vector2.new(1008, 64),
		["NoCollisionConstraint"] = Vector2.new(0, 80),
		["NonReplicatedCSGDictionaryService"] = Vector2.new(16, 80),
		["NotificationService"] = Vector2.new(32, 80),
		["NumberPose"] = Vector2.new(48, 80),
		["NumberValue"] = Vector2.new(64, 80),
		["ObjectValue"] = Vector2.new(80, 80),
		["OrderedDataStore"] = Vector2.new(96, 80),
		["OutfitPages"] = Vector2.new(112, 80),
		["PVAdornment"] = Vector2.new(128, 80),
		["PVInstance"] = Vector2.new(144, 80),
		["PackageLink"] = Vector2.new(160, 80),
		["PackageService"] = Vector2.new(176, 80),
		["PackageUIService"] = Vector2.new(192, 80),
		["Pages"] = Vector2.new(208, 80),
		["Pants"] = Vector2.new(224, 80),
		["ParabolaAdornment"] = Vector2.new(240, 80),
		["Part"] = Vector2.new(256, 80),
		["PartAdornment"] = Vector2.new(272, 80),
		["PartOperation"] = Vector2.new(288, 80),
		["PartOperationAsset"] = Vector2.new(304, 80),
		["ParticleEmitter"] = Vector2.new(320, 80),
		["PatchMapping"] = Vector2.new(336, 80),
		["Path"] = Vector2.new(352, 80),
		["PathfindingLink"] = Vector2.new(368, 80),
		["PathfindingModifier"] = Vector2.new(384, 80),
		["PathfindingService"] = Vector2.new(400, 80),
		["PausedState"] = Vector2.new(416, 80),
		["PausedStateBreakpoint"] = Vector2.new(432, 80),
		["PausedStateException"] = Vector2.new(448, 80),
		["PermissionsService"] = Vector2.new(464, 80),
		["PhysicsService"] = Vector2.new(480, 80),
		["PhysicsSettings"] = Vector2.new(496, 80),
		["PitchShiftSoundEffect"] = Vector2.new(512, 80),
		["Plane"] = Vector2.new(528, 80),
		["PlaneConstraint"] = Vector2.new(544, 80),
		["Platform"] = Vector2.new(560, 80),
		["Player"] = Vector2.new(576, 80),
		["PlayerEmulatorService"] = Vector2.new(592, 80),
		["PlayerGui"] = Vector2.new(608, 80),
		["PlayerMouse"] = Vector2.new(624, 80),
		["PlayerScripts"] = Vector2.new(640, 80),
		["Players"] = Vector2.new(656, 80),
		["Plugin"] = Vector2.new(672, 80),
		["PluginAction"] = Vector2.new(688, 80),
		["PluginDebugService"] = Vector2.new(704, 80),
		["PluginDragEvent"] = Vector2.new(720, 80),
		["PluginGui"] = Vector2.new(736, 80),
		["PluginGuiService"] = Vector2.new(752, 80),
		["PluginManagementService"] = Vector2.new(768, 80),
		["PluginManager"] = Vector2.new(784, 80),
		["PluginManagerInterface"] = Vector2.new(800, 80),
		["PluginMenu"] = Vector2.new(816, 80),
		["PluginMouse"] = Vector2.new(832, 80),
		["PluginPolicyService"] = Vector2.new(848, 80),
		["PluginToolbar"] = Vector2.new(864, 80),
		["PluginToolbarButton"] = Vector2.new(880, 80),
		["PointLight"] = Vector2.new(896, 80),
		["PointsService"] = Vector2.new(912, 80),
		["PolicyService"] = Vector2.new(928, 80),
		["Pose"] = Vector2.new(944, 80),
		["PoseBase"] = Vector2.new(960, 80),
		["PostEffect"] = Vector2.new(976, 80),
		["PrismaticConstraint"] = Vector2.new(992, 80),
		["ProcessInstancePhysicsService"] = Vector2.new(1008, 80),
		["ProximityPrompt"] = Vector2.new(0, 96),
		["ProximityPromptService"] = Vector2.new(16, 96),
		["PublishService"] = Vector2.new(32, 96),
		["QWidgetPluginGui"] = Vector2.new(48, 96),
		["RayValue"] = Vector2.new(64, 96),
		["RbxAnalyticsService"] = Vector2.new(80, 96),
		["ReflectionMetadata"] = Vector2.new(96, 96),
		["ReflectionMetadataCallbacks"] = Vector2.new(112, 96),
		["ReflectionMetadataClass"] = Vector2.new(128, 96),
		["ReflectionMetadataClasses"] = Vector2.new(144, 96),
		["ReflectionMetadataEnum"] = Vector2.new(160, 96),
		["ReflectionMetadataEnumItem"] = Vector2.new(176, 96),
		["ReflectionMetadataEnums"] = Vector2.new(192, 96),
		["ReflectionMetadataEvents"] = Vector2.new(208, 96),
		["ReflectionMetadataFunctions"] = Vector2.new(224, 96),
		["ReflectionMetadataItem"] = Vector2.new(240, 96),
		["ReflectionMetadataMember"] = Vector2.new(256, 96),
		["ReflectionMetadataProperties"] = Vector2.new(272, 96),
		["ReflectionMetadataYieldFunctions"] = Vector2.new(288, 96),
		["RemoteDebuggerServer"] = Vector2.new(304, 96),
		["RemoteEvent"] = Vector2.new(320, 96),
		["RemoteFunction"] = Vector2.new(336, 96),
		["RenderSettings"] = Vector2.new(352, 96),
		["RenderingTest"] = Vector2.new(368, 96),
		["ReplicatedFirst"] = Vector2.new(384, 96),
		["ReplicatedStorage"] = Vector2.new(400, 96),
		["ReverbSoundEffect"] = Vector2.new(416, 96),
		["RigidConstraint"] = Vector2.new(432, 96),
		["RobloxPluginGuiService"] = Vector2.new(448, 96),
		["RobloxReplicatedStorage"] = Vector2.new(464, 96),
		["RocketPropulsion"] = Vector2.new(480, 96),
		["RodConstraint"] = Vector2.new(496, 96),
		["RopeConstraint"] = Vector2.new(512, 96),
		["Rotate"] = Vector2.new(528, 96),
		["RotateP"] = Vector2.new(544, 96),
		["RotateV"] = Vector2.new(560, 96),
		["RotationCurve"] = Vector2.new(576, 96),
		["RtMessagingService"] = Vector2.new(592, 96),
		["RunService"] = Vector2.new(608, 96),
		["RunningAverageItemDouble"] = Vector2.new(624, 96),
		["RunningAverageItemInt"] = Vector2.new(640, 96),
		["RunningAverageTimeIntervalItem"] = Vector2.new(656, 96),
		["RuntimeScriptService"] = Vector2.new(672, 96),
		["ScreenGui"] = Vector2.new(688, 96),
		["ScreenshotHud"] = Vector2.new(704, 96),
		["Script"] = Vector2.new(720, 96),
		["ScriptChangeService"] = Vector2.new(736, 96),
		["ScriptCloneWatcher"] = Vector2.new(752, 96),
		["ScriptCloneWatcherHelper"] = Vector2.new(768, 96),
		["ScriptContext"] = Vector2.new(784, 96),
		["ScriptDebugger"] = Vector2.new(800, 96),
		["ScriptDocument"] = Vector2.new(816, 96),
		["ScriptEditorService"] = Vector2.new(832, 96),
		["ScriptRegistrationService"] = Vector2.new(848, 96),
		["ScriptService"] = Vector2.new(864, 96),
		["ScrollingFrame"] = Vector2.new(880, 96),
		["Seat"] = Vector2.new(896, 96),
		["Selection"] = Vector2.new(912, 96),
		["SelectionBox"] = Vector2.new(928, 96),
		["SelectionLasso"] = Vector2.new(944, 96),
		["SelectionPartLasso"] = Vector2.new(960, 96),
		["SelectionPointLasso"] = Vector2.new(976, 96),
		["SelectionSphere"] = Vector2.new(992, 96),
		["ServerReplicator"] = Vector2.new(1008, 96),
		["ServerScriptService"] = Vector2.new(0, 112),
		["ServerStorage"] = Vector2.new(16, 112),
		["ServiceProvider"] = Vector2.new(32, 112),
		["SessionService"] = Vector2.new(48, 112),
		["Shirt"] = Vector2.new(64, 112),
		["ShirtGraphic"] = Vector2.new(80, 112),
		["SkateboardController"] = Vector2.new(96, 112),
		["SkateboardPlatform"] = Vector2.new(112, 112),
		["Skin"] = Vector2.new(128, 112),
		["Sky"] = Vector2.new(144, 112),
		["SlidingBallConstraint"] = Vector2.new(160, 112),
		["Smoke"] = Vector2.new(176, 112),
		["Snap"] = Vector2.new(192, 112),
		["SnippetService"] = Vector2.new(208, 112),
		["SocialService"] = Vector2.new(224, 112),
		["SolidModelContentProvider"] = Vector2.new(240, 112),
		["Sound"] = Vector2.new(256, 112),
		["SoundEffect"] = Vector2.new(272, 112),
		["SoundGroup"] = Vector2.new(288, 112),
		["SoundService"] = Vector2.new(304, 112),
		["Sparkles"] = Vector2.new(320, 112),
		["SpawnLocation"] = Vector2.new(336, 112),
		["SpawnerService"] = Vector2.new(352, 112),
		["Speaker"] = Vector2.new(368, 112),
		["SpecialMesh"] = Vector2.new(384, 112),
		["SphereHandleAdornment"] = Vector2.new(400, 112),
		["SpotLight"] = Vector2.new(416, 112),
		["SpringConstraint"] = Vector2.new(432, 112),
		["StackFrame"] = Vector2.new(448, 112),
		["StandalonePluginScripts"] = Vector2.new(464, 112),
		["StandardPages"] = Vector2.new(480, 112),
		["StarterCharacterScripts"] = Vector2.new(496, 112),
		["StarterGear"] = Vector2.new(512, 112),
		["StarterGui"] = Vector2.new(528, 112),
		["StarterPack"] = Vector2.new(544, 112),
		["StarterPlayer"] = Vector2.new(560, 112),
		["StarterPlayerScripts"] = Vector2.new(576, 112),
		["Stats"] = Vector2.new(592, 112),
		["StatsItem"] = Vector2.new(608, 112),
		["Status"] = Vector2.new(624, 112),
		["StopWatchReporter"] = Vector2.new(640, 112),
		["StringValue"] = Vector2.new(656, 112),
		["Studio"] = Vector2.new(672, 112),
		["StudioAssetService"] = Vector2.new(688, 112),
		["StudioData"] = Vector2.new(704, 112),
		["StudioDeviceEmulatorService"] = Vector2.new(720, 112),
		["StudioHighDpiService"] = Vector2.new(736, 112),
		["StudioPublishService"] = Vector2.new(752, 112),
		["StudioScriptDebugEventListener"] = Vector2.new(768, 112),
		["StudioService"] = Vector2.new(784, 112),
		["StudioTheme"] = Vector2.new(800, 112),
		["SunRaysEffect"] = Vector2.new(816, 112),
		["SurfaceAppearance"] = Vector2.new(832, 112),
		["SurfaceGui"] = Vector2.new(848, 112),
		["SurfaceGuiBase"] = Vector2.new(864, 112),
		["SurfaceLight"] = Vector2.new(880, 112),
		["SurfaceSelection"] = Vector2.new(896, 112),
		["SwimController"] = Vector2.new(912, 112),
		["TaskScheduler"] = Vector2.new(928, 112),
		["Team"] = Vector2.new(944, 112),
		["TeamCreateService"] = Vector2.new(960, 112),
		["Teams"] = Vector2.new(976, 112),
		["TeleportAsyncResult"] = Vector2.new(992, 112),
		["TeleportOptions"] = Vector2.new(1008, 112),
		["TeleportService"] = Vector2.new(0, 128),
		["TemporaryCageMeshProvider"] = Vector2.new(16, 128),
		["TemporaryScriptService"] = Vector2.new(32, 128),
		["Terrain"] = Vector2.new(48, 128),
		["TerrainDetail"] = Vector2.new(64, 128),
		["TerrainRegion"] = Vector2.new(80, 128),
		["TestService"] = Vector2.new(96, 128),
		["TextBox"] = Vector2.new(112, 128),
		["TextBoxService"] = Vector2.new(128, 128),
		["TextButton"] = Vector2.new(144, 128),
		["TextChannel"] = Vector2.new(160, 128),
		["TextChatCommand"] = Vector2.new(176, 128),
		["TextChatConfigurations"] = Vector2.new(192, 128),
		["TextChatMessage"] = Vector2.new(208, 128),
		["TextChatMessageProperties"] = Vector2.new(224, 128),
		["TextChatService"] = Vector2.new(240, 128),
		["TextFilterResult"] = Vector2.new(256, 128),
		["TextLabel"] = Vector2.new(272, 128),
		["TextService"] = Vector2.new(288, 128),
		["TextSource"] = Vector2.new(304, 128),
		["Texture"] = Vector2.new(320, 128),
		["ThirdPartyUserService"] = Vector2.new(336, 128),
		["ThreadState"] = Vector2.new(352, 128),
		["TimerService"] = Vector2.new(368, 128),
		["ToastNotificationService"] = Vector2.new(384, 128),
		["Tool"] = Vector2.new(400, 128),
		["ToolboxService"] = Vector2.new(416, 128),
		["Torque"] = Vector2.new(432, 128),
		["TorsionSpringConstraint"] = Vector2.new(448, 128),
		["TotalCountTimeIntervalItem"] = Vector2.new(464, 128),
		["TouchInputService"] = Vector2.new(480, 128),
		["TouchTransmitter"] = Vector2.new(496, 128),
		["TracerService"] = Vector2.new(512, 128),
		["TrackerStreamAnimation"] = Vector2.new(528, 128),
		["Trail"] = Vector2.new(544, 128),
		["Translator"] = Vector2.new(560, 128),
		["TremoloSoundEffect"] = Vector2.new(576, 128),
		["TriangleMeshPart"] = Vector2.new(592, 128),
		["TrussPart"] = Vector2.new(608, 128),
		["Tween"] = Vector2.new(624, 128),
		["TweenBase"] = Vector2.new(640, 128),
		["TweenService"] = Vector2.new(656, 128),
		["UGCValidationService"] = Vector2.new(672, 128),
		["UIAspectRatioConstraint"] = Vector2.new(688, 128),
		["UIBase"] = Vector2.new(704, 128),
		["UIComponent"] = Vector2.new(720, 128),
		["UIConstraint"] = Vector2.new(736, 128),
		["UICorner"] = Vector2.new(752, 128),
		["UIGradient"] = Vector2.new(768, 128),
		["UIGridLayout"] = Vector2.new(784, 128),
		["UIGridStyleLayout"] = Vector2.new(800, 128),
		["UILayout"] = Vector2.new(816, 128),
		["UIListLayout"] = Vector2.new(832, 128),
		["UIPadding"] = Vector2.new(848, 128),
		["UIPageLayout"] = Vector2.new(864, 128),
		["UIScale"] = Vector2.new(880, 128),
		["UISizeConstraint"] = Vector2.new(896, 128),
		["UIStroke"] = Vector2.new(912, 128),
		["UITableLayout"] = Vector2.new(928, 128),
		["UITextSizeConstraint"] = Vector2.new(944, 128),
		["UnionOperation"] = Vector2.new(960, 128),
		["UniversalConstraint"] = Vector2.new(976, 128),
		["UnvalidatedAssetService"] = Vector2.new(992, 128),
		["UserGameSettings"] = Vector2.new(1008, 128),
		["UserInputService"] = Vector2.new(0, 144),
		["UserService"] = Vector2.new(16, 144),
		["UserSettings"] = Vector2.new(32, 144),
		["UserStorageService"] = Vector2.new(48, 144),
		["VRService"] = Vector2.new(64, 144),
		["ValueBase"] = Vector2.new(80, 144),
		["Vector3Curve"] = Vector2.new(96, 144),
		["Vector3Value"] = Vector2.new(112, 144),
		["VectorForce"] = Vector2.new(128, 144),
		["VehicleController"] = Vector2.new(144, 144),
		["VehicleSeat"] = Vector2.new(160, 144),
		["VelocityMotor"] = Vector2.new(176, 144),
		["VersionControlService"] = Vector2.new(192, 144),
		["VideoCaptureService"] = Vector2.new(208, 144),
		["VideoFrame"] = Vector2.new(224, 144),
		["ViewportFrame"] = Vector2.new(240, 144),
		["VirtualInputManager"] = Vector2.new(256, 144),
		["VirtualUser"] = Vector2.new(272, 144),
		["VisibilityService"] = Vector2.new(288, 144),
		["Visit"] = Vector2.new(304, 144),
		["VoiceChannel"] = Vector2.new(320, 144),
		["VoiceChatInternal"] = Vector2.new(336, 144),
		["VoiceChatService"] = Vector2.new(352, 144),
		["VoiceSource"] = Vector2.new(368, 144),
		["WedgePart"] = Vector2.new(384, 144),
		["Weld"] = Vector2.new(400, 144),
		["WeldConstraint"] = Vector2.new(416, 144),
		["WireframeHandleAdornment"] = Vector2.new(432, 144),
		["Workspace"] = Vector2.new(448, 144),
		["WorldModel"] = Vector2.new(464, 144),
		["WorldRoot"] = Vector2.new(480, 144),
		["WrapLayer"] = Vector2.new(496, 144),
		["WrapTarget"] = Vector2.new(512, 144)
	}
	
	local ImageRectOffsetsLegacy = {
		["Instance"] = Vector2.new(0,0),
		Part = Vector2.new(16,0),
		CornerWedgePart = Vector2.new(16,0),
		WedgePart = Vector2.new(16,0),
		TrussPart = Vector2.new(16,0),
		Model = Vector2.new(32,0),
		Status = Vector2.new(32,0),
		ValueBase = Vector2.new(64,0),
		BoolValue = Vector2.new(64,0),
		BrickColorValue = Vector2.new(64,0),
		CFrameValue = Vector2.new(64,0),
		Color3Value = Vector2.new(64,0),
		IntValue = Vector2.new(64,0),
		NumberValue = Vector2.new(64,0),
		ObjectValue = Vector2.new(64,0),
		RayValue = Vector2.new(64,0),
		StringValue = Vector2.new(64,0),
		Vector3Value = Vector2.new(64,0),
		DoubleConstrainedValue = Vector2.new(64,0),
		IntConstrainedValue = Vector2.new(64,0),
		FloorWire = Vector2.new(64,0),
		Camera = Vector2.new(80,0),
		Script = Vector2.new(96,0),
		Decal = Vector2.new(112,0),
		SpecialMesh = Vector2.new(128,0),
		BlockMesh = Vector2.new(128,0),
		CylinderMesh = Vector2.new(128,0),
		Humanoid = Vector2.new(144,0),
		Texture = Vector2.new(160,0),
		SurfaceAppearance = Vector2.new(160,0),
		Sound = Vector2.new(176,0),
		Player = Vector2.new(192,0),
		Light = Vector2.new(208,0),
		PointLight = Vector2.new(208,0),
		SurfaceLight = Vector2.new(208,0),
		SpotLight = Vector2.new(208,0),
		Lighting = Vector2.new(208,0),
		BodyGyro = Vector2.new(224,0),
		BodyPosition = Vector2.new(224,0),
		BodyVelocity = Vector2.new(224,0),
		BodyForce = Vector2.new(224,0),
		BodyThrust = Vector2.new(224,0),
		BodyAngularVelocity = Vector2.new(224,0),
		NetworkServer = Vector2.new(240,0),
		NetworkClient = Vector2.new(256,0),
		Tool = Vector2.new(272,0),
		LocalScript = Vector2.new(288,0),
		["Workspace"] = Vector2.new(304,0),
		WorldModel = Vector2.new(304,0),
		StarterPack = Vector2.new(320,0),
		StarterGear = Vector2.new(320,0),
		Backpack = Vector2.new(320,0),
		Players = Vector2.new(336,0),
		HopperBin = Vector2.new(352,0),
		Teams = Vector2.new(368,0),
		Team = Vector2.new(384,0),
		SpawnLocation = Vector2.new(400,0),
		UIAspectRatioConstraint = Vector2.new(416,0),
		UICorner = Vector2.new(416,0),
		UIGradient = Vector2.new(416,0),
		UIGridLayout = Vector2.new(416,0),
		UIListLayout = Vector2.new(416,0),
		UIPadding = Vector2.new(416,0),
		UIPageLayout = Vector2.new(416,0),
		UIScale = Vector2.new(416,0),
		UISizeConstraint = Vector2.new(416,0),
		UIStroke = Vector2.new(416,0),
		UITableLayout = Vector2.new(416,0),
		UITextSizeConstraint = Vector2.new(416,0),
		Sky = Vector2.new(448,0),
		Atmosphere = Vector2.new(448,0),
		Clouds = Vector2.new(448,0),
		Debris = Vector2.new(480,0),
		SoundService = Vector2.new(496,0),
		Accoutrement = Vector2.new(512,0),
		Accessory = Vector2.new(512,0),
		Chat = Vector2.new(528,0),
		Message = Vector2.new(528,0),
		Hint = Vector2.new(528,0),
		JointInstance = Vector2.new(544,0),
		Weld = Vector2.new(544,0),
		Snap = Vector2.new(544,0),
		Seat = Vector2.new(560,0),
		VehicleSeat = Vector2.new(560,0),
		Platform = Vector2.new(560,0),
		SkateboardPlatform = Vector2.new(560,0),
		Explosion = Vector2.new(576,0),
		ForceField = Vector2.new(592,0),
		TouchTransmitter = Vector2.new(592,0),
		Flag = Vector2.new(608,0),
		FlagStand = Vector2.new(624,0),
		ShirtGraphic = Vector2.new(640,0),
		ClickDetector = Vector2.new(656,0),
		Sparkles = Vector2.new(672,0),
		Shirt = Vector2.new(688,0),
		Pants = Vector2.new(704,0),
		Hat = Vector2.new(720,0),
		CoreGui = Vector2.new(736,0),
		StarterGui = Vector2.new(736,0),
		PlayerGui = Vector2.new(736,0),
		MarketplaceService = Vector2.new(736,0),
		PluginDebugService = Vector2.new(736,0),
		PluginGuiService = Vector2.new(736,0),
		RobloxPluginGuiService = Vector2.new(736,0),
		ScreenGui = Vector2.new(752,0),
		GuiMain = Vector2.new(752,0),
		Frame = Vector2.new(768,0),
		ScrollingFrame = Vector2.new(768,0),
		CanvasGroup = Vector2.new(768,0),
		ImageLabel = Vector2.new(784,0),
		TextLabel = Vector2.new(800,0),
		TextButton = Vector2.new(816,0),
		TextBox = Vector2.new(816,0),
		ImageButton = Vector2.new(832,0),
		GuiButton = Vector2.new(832,0),
		ViewportFrame = Vector2.new(832,0),
		Handles = Vector2.new(848,0),
		IKControl = Vector2.new(848,0),
		SelectionBox = Vector2.new(864,0),
		SelectionSphere = Vector2.new(864,0),
		SurfaceSelection = Vector2.new(880,0),
		ArcHandles = Vector2.new(896,0),
		SelectionPartLasso = Vector2.new(912,0),
		SelectionPointLasso = Vector2.new(912,0),
		Configuration = Vector2.new(928,0),
		Smoke = Vector2.new(944,0),
		CharacterMesh = Vector2.new(960,0),
		Animation = Vector2.new(960,0),
		AnimationTrack = Vector2.new(960,0),
		Animator = Vector2.new(960,0),
		Keyframe = Vector2.new(960,0),
		KeyframeMarker = Vector2.new(960,0),
		PoseBase = Vector2.new(960,0),
		NumberPose = Vector2.new(960,0),
		Pose = Vector2.new(960,0),
		Fire = Vector2.new(976,0),
		Dialog = Vector2.new(992,0),
		DialogChoice = Vector2.new(1008,0),
		BillboardGui = Vector2.new(1024,0),
		SurfaceGui = Vector2.new(1024,0),
		Terrain = Vector2.new(1040,0),
		TerrainRegion = Vector2.new(1040,0),
		BindableFunction = Vector2.new(1056,0),
		BindableEvent = Vector2.new(1072,0),
		TestService = Vector2.new(1088,0),
		ServerStorage = Vector2.new(1104,0),
		ReplicatedFirst = Vector2.new(1120,0),
		ReplicatedStorage = Vector2.new(1120,0),
		ServerScriptService = Vector2.new(1136,0),
		NegateOperation = Vector2.new(1152,0),
		MeshPart = Vector2.new(1168,0),
		UnionOperation = Vector2.new(1168,0),
		RemoteFunction = Vector2.new(1184,0),
		RemoteEvent = Vector2.new(1200,0),
		ModuleScript = Vector2.new(1216,0),
		Folder = Vector2.new(1232,0),
		PlayerScripts = Vector2.new(1248,0),
		StandalonePluginScripts = Vector2.new(1248,0),
		StarterPlayer = Vector2.new(1264,0),
		StarterCharacterScripts = Vector2.new(1264,0),
		StarterPlayerScripts = Vector2.new(1264,0),
		ParticleEmitter = Vector2.new(1280,0),
		Attachment = Vector2.new(1296,0),
		BloomEffect = Vector2.new(1328,0),
		BlurEffect = Vector2.new(1328,0),
		ColorCorrectionEffect = Vector2.new(1328,0),
		DepthOfFieldEffect = Vector2.new(1328,0),
		SunRaysEffect = Vector2.new(1328,0),
		ChorusSoundEffect = Vector2.new(1344,0),
		CompressorSoundEffect = Vector2.new(1344,0),
		ChannelSelectorSoundEffect = Vector2.new(1344,0),
		DistortionSoundEffect = Vector2.new(1344,0),
		EchoSoundEffect = Vector2.new(1344,0),
		EqualizerSoundEffect = Vector2.new(1344,0),
		FlangeSoundEffect = Vector2.new(1344,0),
		PitchShiftSoundEffect = Vector2.new(1344,0),
		ReverbSoundEffect = Vector2.new(1344,0),
		TremoloSoundEffect = Vector2.new(1344,0),
		SoundGroup = Vector2.new(1360,0),
		BallSocketConstraint = Vector2.new(1376,0),
		Plugin = Vector2.new(1376,0),
		HingeConstraint = Vector2.new(1392,0),
		SlidingBallConstraint = Vector2.new(1408,0),
		PrismaticConstraint = Vector2.new(1408,0),
		RopeConstraint = Vector2.new(1424,0),
		RodConstraint = Vector2.new(1440,0),
		SpringConstraint = Vector2.new(1456,0),
		Trail = Vector2.new(1488,0),
		WeldConstraint = Vector2.new(1504,0),
		CylindricalConstraint = Vector2.new(1520,0),
		Beam = Vector2.new(1536,0),
		AlignPosition = Vector2.new(1584,0),
		AlignOrientation = Vector2.new(1600,0),
		LineForce = Vector2.new(1616,0),
		VectorForce = Vector2.new(1632,0),
		AngularVelocity = Vector2.new(1648,0),
		HumanoidDescription = Vector2.new(1664,0),
		NoCollisionConstraint = Vector2.new(1680,0),
		Motor6D = Vector2.new(1696,0),
		LineHandleAdornment = Vector2.new(1712,0),
		ImageHandleAdornment = Vector2.new(1728,0),
		CylinderHandleAdornment = Vector2.new(1744,0),
		ConeHandleAdornment = Vector2.new(1760,0),
		BoxHandleAdornment = Vector2.new(1776,0),
		SphereHandleAdornment = Vector2.new(1792,0),
		WireframeHandleAdornment = Vector2.new(1808,0),
		Actor = Vector2.new(1808,0),
		Bone = Vector2.new(1824,0),
		VideoFrame = Vector2.new(1920,0),
		UniversalConstraint = Vector2.new(1968,0),
		ProximityPrompt = Vector2.new(1984,0),
		TorsionSpringConstraint = Vector2.new(2000,0),
		WrapLayer = Vector2.new(2016,0),
		WrapTarget = Vector2.new(2032,0),
		PathfindingModifier = Vector2.new(2048,0),
		FaceControls = Vector2.new(2064,0),
		MaterialVariant = Vector2.new(2080,0),
		MaterialService = Vector2.new(2096,0),
		LinearVelocity = Vector2.new(2112,0),
		Highlight = Vector2.new(2128,0),
		PlaneConstraint = Vector2.new(2144,0),
		Plane = Vector2.new(2144,0),
		RigidConstraint = Vector2.new(2160,0),
		VoiceChatService = Vector2.new(2176,0),
		PathfindingLink = Vector2.new(2192,0),
		TextChatCommand = Vector2.new(2208,0),
		TextSource = Vector2.new(2224,0),
		TextChannel = Vector2.new(2240,0),
		ChatWindowConfiguration = Vector2.new(2256,0),
		ChatInputBarConfiguration = Vector2.new(2272,0),
		TextChatService = Vector2.new(2288,0),
		TerrainDetail = Vector2.new(2304,0),
		AdGui = Vector2.new(2320,0),
		AdPortal = Vector2.new(2336,0)
	}
	
	local BuiltinIcons = {
		["Accessory"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Accessory.png",
		["Actor"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Actor.png",
		["AdGui"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AdGui.png",
		["AdPortal"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AdPortal.png",
		["AirController"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AirController.png",
		["AlignOrientation"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AlignOrientation.png",
		["AlignPosition"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AlignPosition.png",
		["AngularVelocity"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AngularVelocity.png",
		["Animation"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Animation.png",
		["AnimationConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AnimationConstraint.png",
		["AnimationController"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AnimationController.png",
		["AnimationFromVideoCreatorService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AnimationFromVideoCreatorService.png",
		["Animator"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Animator.png",
		["ArcHandles"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ArcHandles.png",
		["Atmosphere"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Atmosphere.png",
		["Attachment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Attachment.png",
		["AudioAnalyzer"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioAnalyzer.png",
		["AudioChorus"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioChorus.png",
		["AudioCompressor"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioCompressor.png",
		["AudioDeviceInput"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioDeviceInput.png",
		["AudioDeviceOutput"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioDeviceOutput.png",
		["AudioDistortion"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioDistortion.png",
		["AudioEcho"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioEcho.png",
		["AudioEmitter"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioEmitter.png",
		["AudioEqualizer"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioEqualizer.png",
		["AudioFader"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioFader.png",
		["AudioFlanger"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioFlanger.png",
		["AudioListener"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioListener.png",
		["AudioPitchShifter"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioPitchShifter.png",
		["AudioPlayer"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioPlayer.png",
		["AudioReverb"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AudioReverb.png",
		["AvatarEditorService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/AvatarEditorService.png",
		["Backpack"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Backpack.png",
		["BallSocketConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BallSocketConstraint.png",
		["BasePlate"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BasePlate.png",
		["Beam"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Beam.png",
		["BillboardGui"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BillboardGui.png",
		["BindableEvent"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BindableEvent.png",
		["BindableFunction"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BindableFunction.png",
		["BlockMesh"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BlockMesh.png",
		["BloomEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BloomEffect.png",
		["BlurEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BlurEffect.png",
		["BodyAngularVelocity"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BodyAngularVelocity.png",
		["BodyColors"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BodyColors.png",
		["BodyForce"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BodyForce.png",
		["BodyGyro"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BodyGyro.png",
		["BodyPosition"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BodyPosition.png",
		["BodyThrust"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BodyThrust.png",
		["BodyVelocity"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BodyVelocity.png",
		["Bone"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Bone.png",
		["BoolValue"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BoolValue.png",
		["BoxHandleAdornment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BoxHandleAdornment.png",
		["Breakpoint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Breakpoint.png",
		["BrickColorValue"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BrickColorValue.png",
		["BubbleChatConfiguration"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/BubbleChatConfiguration.png",
		["Buggaroo"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Buggaroo.png",
		["Camera"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Camera.png",
		["CanvasGroup"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CanvasGroup.png",
		["CFrameValue"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CFrameValue.png",
		["CharacterControllerManager"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CharacterControllerManager.png",
		["CharacterMesh"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CharacterMesh.png",
		["Chat"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Chat.png",
		["ChatInputBarConfiguration"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ChatInputBarConfiguration.png",
		["ChatWindowConfiguration"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ChatWindowConfiguration.png",
		["ChorusSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ChorusSoundEffect.png",
		["Class"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Class.png",
		["ClickDetector"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ClickDetector.png",
		["ClientReplicator"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ClientReplicator.png",
		["ClimbController"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ClimbController.png",
		["Clouds"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Clouds.png",
		["Color"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Color.png",
		["ColorCorrectionEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ColorCorrectionEffect.png",
		["CompressorSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CompressorSoundEffect.png",
		["ConeHandleAdornment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ConeHandleAdornment.png",
		["Configuration"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Configuration.png",
		["Constant"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Constant.png",
		["Constructor"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Constructor.png",
		["CoreGui"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CoreGui.png",
		["CornerWedgePart"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CornerWedgePart.png",
		["CylinderHandleAdornment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CylinderHandleAdornment.png",
		["CylindricalConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/CylindricalConstraint.png",
		["Decal"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Decal.png",
		["DepthOfFieldEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/DepthOfFieldEffect.png",
		["Dialog"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Dialog.png",
		["DialogChoice"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/DialogChoice.png",
		["DistortionSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/DistortionSoundEffect.png",
		["DragDetector"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/DragDetector.png",
		["EchoSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/EchoSoundEffect.png",
		["EditableImage"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/EditableImage.png",
		["EditableMesh"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/EditableMesh.png",
		["Enum"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Enum.png",
		["EnumMember"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/EnumMember.png",
		["EqualizerSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/EqualizerSoundEffect.png",
		["Event"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Event.png",
		["Explosion"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Explosion.png",
		["FaceControls"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/FaceControls.png",
		["Field"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Field.png",
		["File"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/File.png",
		["Fire"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Fire.png",
		["FlangeSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/FlangeSoundEffect.png",
		["Folder"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Folder.png",
		["ForceField"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ForceField.png",
		["Frame"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Frame.png",
		["Function"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Function.png",
		["GameSettings"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/GameSettings.png",
		["GroundController"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/GroundController.png",
		["Handles"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Handles.png",
		["HapticService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/HapticService.png",
		["HeightmapImporterService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/HeightmapImporterService.png",
		["Highlight"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Highlight.png",
		["HingeConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/HingeConstraint.png",
		["Humanoid"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Humanoid.png",
		["HumanoidDescription"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/HumanoidDescription.png",
		["IKControl"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/IKControl.png",
		["ImageButton"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ImageButton.png",
		["ImageHandleAdornment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ImageHandleAdornment.png",
		["ImageLabel"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ImageLabel.png",
		["Interface"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Interface.png",
		["IntersectOperation"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/IntersectOperation.png",
		["Keyword"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Keyword.png",
		["Lighting"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Lighting.png",
		["LinearVelocity"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/LinearVelocity.png",
		["LineForce"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/LineForce.png",
		["LineHandleAdornment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/LineHandleAdornment.png",
		["LocalFile"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/LocalFile.png",
		["LocalizationService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/LocalizationService.png",
		["LocalizationTable"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/LocalizationTable.png",
		["LocalScript"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/LocalScript.png",
		["MaterialService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/MaterialService.png",
		["MaterialVariant"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/MaterialVariant.png",
		["MemoryStoreService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/MemoryStoreService.png",
		["MeshPart"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/MeshPart.png",
		["Meshparts"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Meshparts.png",
		["MessagingService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/MessagingService.png",
		["Method"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Method.png",
		["Model"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Model.png",
		["Modelgroups"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Modelgroups.png",
		["Module"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Module.png",
		["ModuleScript"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ModuleScript.png",
		["Motor6D"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Motor6D.png",
		["NegateOperation"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/NegateOperation.png",
		["NetworkClient"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/NetworkClient.png",
		["NoCollisionConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/NoCollisionConstraint.png",
		["Operator"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Operator.png",
		["PackageLink"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PackageLink.png",
		["Pants"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Pants.png",
		["Part"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Part.png",
		["ParticleEmitter"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ParticleEmitter.png",
		["PathfindingLink"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PathfindingLink.png",
		["PathfindingModifier"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PathfindingModifier.png",
		["PathfindingService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PathfindingService.png",
		["PitchShiftSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PitchShiftSoundEffect.png",
		["Place"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Place.png",
		["Plane"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Plane.png",
		["PlaneConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PlaneConstraint.png",
		["Player"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Player.png",
		["Players"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Players.png",
		["PluginGuiService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PluginGuiService.png",
		["PointLight"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PointLight.png",
		["PrismaticConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PrismaticConstraint.png",
		["Property"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Property.png",
		["ProximityPrompt"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ProximityPrompt.png",
		["PublishService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/PublishService.png",
		["Reference"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Reference.png",
		["RemoteEvent"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RemoteEvent.png",
		["RemoteFunction"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RemoteFunction.png",
		["RenderingTest"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RenderingTest.png",
		["ReplicatedFirst"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ReplicatedFirst.png",
		["ReplicatedScriptService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ReplicatedScriptService.png",
		["ReplicatedStorage"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ReplicatedStorage.png",
		["ReverbSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ReverbSoundEffect.png",
		["RigidConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RigidConstraint.png",
		["RobloxPluginGuiService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RobloxPluginGuiService.png",
		["RocketPropulsion"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RocketPropulsion.png",
		["RodConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RodConstraint.png",
		["RopeConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/RopeConstraint.png",
		["Rotate"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Rotate.png",
		["ScreenGui"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ScreenGui.png",
		["Script"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Script.png",
		["ScrollingFrame"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ScrollingFrame.png",
		["Seat"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Seat.png",
		["Selected_Workspace"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Selected_Workspace.png",
		["SelectionBox"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SelectionBox.png",
		["SelectionSphere"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SelectionSphere.png",
		["ServerScriptService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ServerScriptService.png",
		["ServerStorage"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ServerStorage.png",
		["Shirt"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Shirt.png",
		["ShirtGraphic"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ShirtGraphic.png",
		["SkinnedMeshPart"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SkinnedMeshPart.png",
		["Sky"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Sky.png",
		["Smoke"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Smoke.png",
		["Snap"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Snap.png",
		["Snippet"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Snippet.png",
		["SocialService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SocialService.png",
		["Sound"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Sound.png",
		["SoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SoundEffect.png",
		["SoundGroup"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SoundGroup.png",
		["SoundService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SoundService.png",
		["Sparkles"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Sparkles.png",
		["SpawnLocation"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SpawnLocation.png",
		["SpecialMesh"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SpecialMesh.png",
		["SphereHandleAdornment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SphereHandleAdornment.png",
		["SpotLight"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SpotLight.png",
		["SpringConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SpringConstraint.png",
		["StandalonePluginScripts"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StandalonePluginScripts.png",
		["StarterCharacterScripts"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StarterCharacterScripts.png",
		["StarterGui"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StarterGui.png",
		["StarterPack"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StarterPack.png",
		["StarterPlayer"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StarterPlayer.png",
		["StarterPlayerScripts"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StarterPlayerScripts.png",
		["Struct"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Struct.png",
		["StyleDerive"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StyleDerive.png",
		["StyleLink"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StyleLink.png",
		["StyleRule"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StyleRule.png",
		["StyleSheet"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/StyleSheet.png",
		["SunRaysEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SunRaysEffect.png",
		["SurfaceAppearance"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SurfaceAppearance.png",
		["SurfaceGui"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SurfaceGui.png",
		["SurfaceLight"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SurfaceLight.png",
		["SurfaceSelection"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SurfaceSelection.png",
		["SwimController"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/SwimController.png",
		["TaskScheduler"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TaskScheduler.png",
		["Team"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Team.png",
		["Teams"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Teams.png",
		["Terrain"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Terrain.png",
		["TerrainDetail"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TerrainDetail.png",
		["TestService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TestService.png",
		["TextBox"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextBox.png",
		["TextBoxService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextBoxService.png",
		["TextButton"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextButton.png",
		["TextChannel"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextChannel.png",
		["TextChatCommand"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextChatCommand.png",
		["TextChatService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextChatService.png",
		["TextLabel"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextLabel.png",
		["TextString"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TextString.png",
		["Texture"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Texture.png",
		["Tool"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Tool.png",
		["Torque"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Torque.png",
		["TorsionSpringConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TorsionSpringConstraint.png",
		["Trail"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Trail.png",
		["TremoloSoundEffect"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TremoloSoundEffect.png",
		["TrussPart"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TrussPart.png",
		["TypeParameter"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/TypeParameter.png",
		["UGCValidationService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UGCValidationService.png",
		["UIAspectRatioConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIAspectRatioConstraint.png",
		["UICorner"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UICorner.png",
		["UIGradient"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIGradient.png",
		["UIGridLayout"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIGridLayout.png",
		["UIListLayout"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIListLayout.png",
		["UIPadding"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIPadding.png",
		["UIPageLayout"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIPageLayout.png",
		["UIScale"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIScale.png",
		["UISizeConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UISizeConstraint.png",
		["UIStroke"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UIStroke.png",
		["UITableLayout"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UITableLayout.png",
		["UITextSizeConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UITextSizeConstraint.png",
		["UnionOperation"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UnionOperation.png",
		["Unit"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Unit.png",
		["UniversalConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UniversalConstraint.png",
		["UnreliableRemoteEvent"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UnreliableRemoteEvent.png",
		["UpdateAvailable"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UpdateAvailable.png",
		["UserService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/UserService.png",
		["Value"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Value.png",
		["Variable"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Variable.png",
		["VectorForce"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/VectorForce.png",
		["VehicleSeat"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/VehicleSeat.png",
		["VideoFrame"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/VideoFrame.png",
		["ViewportFrame"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/ViewportFrame.png",
		["VirtualUser"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/VirtualUser.png",
		["VoiceChannel"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/VoiceChannel.png",
		["Voicechat"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Voicechat.png",
		["VoiceChatService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/VoiceChatService.png",
		["VRService"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/VRService.png",
		["WedgePart"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/WedgePart.png",
		["Weld"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Weld.png",
		["WeldConstraint"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/WeldConstraint.png",
		["Wire"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Wire.png",
		["WireframeHandleAdornment"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/WireframeHandleAdornment.png",
		["Workspace"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Workspace.png",
		["WorldModel"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/WorldModel.png",
		["WrapLayer"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/WrapLayer.png",
		["WrapTarget"] = "rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/WrapTarget.png"
	}
	
	local BuiltinDefault = "rbxasset://studio_svg_textures/Shared/WidgetIcons/Dark/Standard/Service.png"
	
	local Default = { -- fallback
		Image = api.ClassIcons.Source,
		ImageRectOffset = ImageRectOffsets["Instance"]
	}
	
	function api:GetClassIcon(className)
		if api.RBXApi.Classes[className] then
			if not api.ClassIcons.OnlyUseNewIcons and ImageRectOffsetsLegacy[className] then
				return {
					Image = api.ClassIcons.SourceLegacy,
					ImageRectOffset = ImageRectOffsetsLegacy[className]
				}
			elseif ImageRectOffsets[className] then
				return {
					Image = api.ClassIcons.Source,
					ImageRectOffset = ImageRectOffsets[className]
				}
			end
		end
		return Default
		--[[if BuiltinIcons[className] then
			return BuiltinIcons[className]
		end
		return BuiltinDefault]]
	end
end

return api