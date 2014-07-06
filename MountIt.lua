-----------------------------------------------------------------------------------------------
-- Client Lua Script for MountIt
-- Copyright (c) derdriu. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- MountIt Module Definition
-----------------------------------------------------------------------------------------------
local MountIt = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local defaultSettings = {
	randomMount = false,
	defaultMount = nil,
	craftingDismount = true,
	randomList = {}
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function MountIt:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function MountIt:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "MountIt"
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- MountIt OnLoad
-----------------------------------------------------------------------------------------------
function MountIt:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("MountIt.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	self.settings = {}
	for k, v in pairs(defaultSettings) do
		self.settings[k] = v
	end
	self.listOfMounts = {}
	Apollo.RegisterEventHandler("Mount", "OnMount", self)
	Apollo.RegisterEventHandler("InvokeCraftingWindow", "OnCraft", self)
	Apollo.RegisterEventHandler("TradeskillEngravingStationOpen", "OnEngrave", self)
end

-----------------------------------------------------------------------------------------------
-- MountIt OnDocLoaded
-----------------------------------------------------------------------------------------------
function MountIt:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MountItForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.mountListForm = self.wndMain:FindChild("MountList")
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("mountit", "OnMountItOn", self)
		Apollo.RegisterEventHandler("MountItOn", "OnMountItOn", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("ToggleMountIt", "OnToggleMountIt", self)


		-- Do additional Addon initialization here
		if self.settings.defaultMount ~= nil then
			self:SetDefaultMount(self.settings.defaultMount)
		end
	end
end

function MountIt:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "MountIt", {"ToggleMountIt", "", "Icon_Windows32_UI_CRB_InterfaceMenu_MountCustomization"})
end



-----------------------------------------------------------------------------------------------
-- MountIt Save/Load
-----------------------------------------------------------------------------------------------
function MountIt:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then return nil end
	return self.settings
end

function MountIt:OnRestore(eLevel, tSaveData)
	if tSaveData then
		self.settings = tSaveData
	end
end

-----------------------------------------------------------------------------------------------
-- MountIt Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/mountit"
function MountIt:OnMountItOn()
	self.wndMain:Invoke() -- show the window
	self.wndMain:FindChild("RandomButton"):SetCheck(self.settings.randomMount)
	self.wndMain:FindChild("DefaultButton"):SetCheck(not self.settings.randomMount)
	self.wndMain:FindChild("DismountButton"):SetCheck(self.settings.craftingDismount)
	self:LoadMountList()
end

function MountIt:OnToggleMountIt()
	if self.wndMain:IsVisible() then
		self.wndMain:Close()
	else
		--self.wndMain:Invoke()
		self:OnMountItOn()
	end
end

function MountIt:OnConfigure()
	--self.wndMain:Invoke()
	self:OnMountItOn()
end

function MountIt:LoadMountList()
	self:EmptyMountList()
	
	local mountList = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}
	for idx, mount in pairs(mountList) do
		-- do something with mount here
		self:AddMountToList(mount)
	end
	
	self.mountListForm:ArrangeChildrenVert()
end

function MountIt:EmptyMountList()
	for idx, item in pairs(self.listOfMounts) do
		item:Destroy()
	end
	
	self.listOfMounts = {}
end

function MountIt:AddMountToList(mount)
	local mountObject = mount.tTiers[1].splObject;
	local mountData = {
		id = mountObject:GetId(),
		icon = mountObject:GetIcon(),
		name = mount.strName
	}
	
	local mountItem = Apollo.LoadForm(self.xmlDoc, "MountListController", self.mountListForm, self)
	local mountButton = mountItem:FindChild("ChooseMountButton")
	
	if (self.settings.randomMount == true and self.settings.randomList[mountData.id] ~= nil) or (self.settings.randomMount == false and self.settings.defaultMount == mountData.id) then
		mountButton:SetCheck(true)
	end
	
	local mountName = mountItem:FindChild("MountName")
	if mountName then
		mountName:SetText(mountData.name)
	end
	
	local mountIcon = mountItem:FindChild("MountIcon")
	if mountIcon then
		mountIcon:SetSprite(mountData.icon)
	end
	
	mountButton:SetData(mountData)
	
	self.listOfMounts[mountData.id] = mountItem
end

function MountIt:SetDefaultMount(mountId)
	self.settings.defaultMount = mountId
    GameLib.SetShortcutMount(mountId)
end


-----------------------------------------------------------------------------------------------
-- MountItForm Functions
-----------------------------------------------------------------------------------------------
-- when the Cancel button is clicked
function MountIt:OnCancel()
	self.wndMain:Close() -- hide the window
end

-- when random option is turned on
function MountIt:RandomOn( wndHandler, wndControl, eMouseButton )
	self.settings.randomMount = true
	for idx, mountItem in pairs(self.listOfMounts) do
		if self.settings.randomList[idx] ~= nil then
			mountItem:FindChild("ChooseMountButton"):SetCheck(true)
		else
			mountItem:FindChild("ChooseMountButton"):SetCheck(false)
		end
	end
end

-- when random option is turned off
function MountIt:RandomOff( wndHandler, wndControl, eMouseButton )
	self.settings.randomMount = false
	for idx, mountItem in pairs(self.listOfMounts) do
		if idx == self.settings.defaultMount then
			mountItem:FindChild("ChooseMountButton"):SetCheck(true)
		else
			mountItem:FindChild("ChooseMountButton"):SetCheck(false)
		end
	end
    GameLib.SetShortcutMount(self.settings.defaultMount)
end


function MountIt:DismountOn( wndHandler, wndControl, eMouseButton )
	self.settings.craftingDismount = true
end

function MountIt:DismountOff( wndHandler, wndControl, eMouseButton )
	self.settings.craftingDismount = false
end

-----------------------------------------------------------------------------------------------
-- Event Functions
-----------------------------------------------------------------------------------------------
-- detect mount events. if random option is chosen, change to a random mount when dismounting
-- TODO: register and deregister event handling when option is changed to save on memory usage
function MountIt:OnMount()
	if GameLib.GetPlayerMountUnit() == nil and self.settings.randomMount == true then
	
		local count = 0
		local randomMount = nil
		local mountId = nil
		local mountIndex = nil
		local mountList = nil
	
		-- check if table is empty
		if next(self.settings.randomList) == nil then
			-- Table is empty, use all mounts
			mountList = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}
			count = 0
			for idx, mount  in pairs(mountList) do
				count = count + 1
			end
			mountIndex = math.random(count)
			randomMount = mountList[mountIndex]
			mountId = randomMount.tTiers[1].splObject:GetId()
		else
			-- Table is not empty, use the list
			mountList = self.settings.randomList
			local countList = {}
			for idx, mount in pairs(mountList) do
				countList[count] = idx
				count = count + 1
			end
			
			mountIndex = math.random(count) - 1
			randomMount = mountList[countList[mountIndex]]
			mountId = randomMount.id
		end
		
        GameLib.SetShortcutMount(mountId)
	end
end

-- Detect Crafting event and dismount if the option is enabled
function MountIt:OnCraft()
	if self.settings.craftingDismount == true then
		GameLib:Disembark()
	end
end

function MountIt:OnEngrave()
	Print("Use Engraving Station")
	if self.settings.craftingDismount == true then
		GameLib:Disembark()
	end
end



---------------------------------------------------------------------------------------------------
-- MountListController Functions
---------------------------------------------------------------------------------------------------

function MountIt:OnSelectMount( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	if wndHandler ~= wndControl then return	end
	
	local chosenMount = wndControl:GetData()
	
	if self.settings.randomMount == true then
		-- If Random, then do a thing
		if wndControl:IsChecked() then
			--Add to random list
			self.settings.randomList[chosenMount.id] =  chosenMount
		else
			-- Remove from random list
			self.settings.randomList[chosenMount.id] = nil
		end
	else
		-- If Default, then choose the default mount and uncheck the other ones
		for idx, mountItem in pairs(self.listOfMounts) do
			if idx ~= chosenMount.id then
				mountItem:FindChild("ChooseMountButton"):SetCheck(false)
			end
		end
		
		self:SetDefaultMount(chosenMount.id)
	end
end

-----------------------------------------------------------------------------------------------
-- MountIt Instance
-----------------------------------------------------------------------------------------------
local MountItInst = MountIt:new()
MountItInst:Init()
