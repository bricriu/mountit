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
	defaultMount = nil
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
	Print("Save")
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then return nil end
	return self.settings
end

function MountIt:OnRestore(eLevel, tSaveData)
	Print("Restore")
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
	Print("Random Setting: " .. (self.settings.randomMount == true and "true" or "false"))
	self.wndMain:FindChild("Randomize"):SetCheck(self.settings.randomMount)
	self:LoadMountList()
end

function MountIt:OnToggleMountIt()
	Print("toggle mount it")
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
	Print("Load Mount List")
	
	self:EmptyMountList()
	
	local mountList = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}
	for idx, mount in pairs(mountList) do
		-- do something with mount here
		self:AddMountToList(mount)
	end
	
	self.mountListForm:ArrangeChildrenVert()
end

function MountIt:EmptyMountList()
	Print("Empty Mount List")
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
	Print("Add Mount: " .. mountData.name .. " (" .. mountData.id .. ")")
	
	local mountItem = Apollo.LoadForm(self.xmlDoc, "MountListController", self.mountListForm, self)
	
	local mountName = mountItem:FindChild("MountName")
	if mountName then
		mountName:SetText(mountData.name)
	end
	
	local mountIcon = mountItem:FindChild("MountIcon")
	if mountIcon then
		mountIcon:SetSprite(mountData.icon)
	end
	
	mountItem:SetData(mountData)
	
	self.listOfMounts[mountData.id] = mountItem
end

function MountIt:SetDefaultMount(mountId)
	self.settings.defaultMount = mountId
	Apollo.GetAddon("ActionBarFrame").nSelectedMount = mountId
	Apollo.GetAddon("ActionBarFrame"):RedrawMounts()
end


-----------------------------------------------------------------------------------------------
-- MountItForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function MountIt:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function MountIt:OnCancel()
	self.wndMain:Close() -- hide the window
end

-- when random option is turned on
function MountIt:RandomOn( wndHandler, wndControl, eMouseButton )
	--Print("Random Turned on")
	self.settings.randomMount = true
end

-- when random option is turned off
function MountIt:RandomOff( wndHandler, wndControl, eMouseButton )
	--Print("Random Turned off")
	self.settings.randomMount = false
end


-----------------------------------------------------------------------------------------------
-- Event Functions
-----------------------------------------------------------------------------------------------
-- detect mount events. if random option is chosen, change to a random mount when dismounting
-- TODO: register and deregister event handling when option is changed to save on memory usage
function MountIt:OnMount()
	--Print("Mount Event Fired")
	if GameLib.GetPlayerMountUnit() == nil and self.settings.randomMount == true then
		local mountList = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}
		local count = 0
		for idx, mount  in pairs(mountList) do
			count = count + 1
		end
		local mountIndex = math.random(count)
		--Print(count .. " mounts available")
		Print("choosing random mount #: " .. mountIndex)
		local randomMount = mountList[mountIndex]
		local mountId = randomMount.tTiers[1].splObject:GetId()
		Print(randomMount.strName .. " (" .. mountId .. ")")
		Apollo.GetAddon("ActionBarFrame").nSelectedMount = mountId
		Apollo.GetAddon("ActionBarFrame"):RedrawMounts()
	end
end



---------------------------------------------------------------------------------------------------
-- MountListController Functions
---------------------------------------------------------------------------------------------------

function MountIt:OnSelectMount( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	if wndHandler ~= wndControl then return	end
	
	local chosenMount = wndControl:GetData()
	Print("Clicked on Mount: " .. chosenMount.name .. " (" .. chosenMount.id .. ")")
	
	self:SetDefaultMount(chosenMount.id)
end

-----------------------------------------------------------------------------------------------
-- MountIt Instance
-----------------------------------------------------------------------------------------------
local MountItInst = MountIt:new()
MountItInst:Init()
