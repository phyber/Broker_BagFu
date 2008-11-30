Broker_Bags = LibStub("AceAddon-3.0"):NewAddon("Broker_Bags", "AceEvent-3.0", "AceBucket-3.0")
local Broker_Bags, self = Broker_Bags, Broker_Bags
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local L = LibStub("AceLocale-3.0"):GetLocale("Broker_Bags")
local dataobj = LDB:NewDataObject("Broker_Bags", {
	type = "data source",
	text = '?/?',
	icon = "Interface\\AddOns\\Broker_Bags\\icon.tga",
})
local db
local defaults = {
	profile = {
		showDepletion = false,
		includeProfession = true,
		includeAmmo = false,
		showTotal = true,
		openBagsAtBank = false,
		openBagsAtVendor = false,
		showBagsInTooltip = true,
		showColours = false,
	},
}
local _G = _G
local GetBagName = GetBagName
local GetAddOnMetadata = GetAddOnMetadata
local GetItemQualityColor = GetItemQualityColor
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local select = select
local string_format = string.format

local function GetOptions()
	local options = {
		type = "group",
		name = GetAddOnMetadata("Broker_Bags", "Title"),
		args = {
			bbdesc = {
				type = "description",
				order = 0,
				name = GetAddOnMetadata("Broker_Bags", "Notes"),
			},
			showColours = {
				type = "toggle",
				order = 50,
				name = L["Use Colours"],
				desc = L["Use colouring to show level of bag fullness"],
				get = function() return db.showColours end,
				set = function()
					db.showColours = not db.showColours
					Broker_Bags:BAG_UPDATE()
				end,
			},
			showBagsInTooltip = {
				type = "toggle",
				order = 75,
				name = L["Bags in Tooltip"],
				desc = L["Show all bags in the Broker: Bags tooltip"],
				get = function() return db.showBagsInTooltip end,
				set = function() db.showBagsInTooltip = not db.showBagsInTooltip end,
			},
			includeAmmo = {
				type = "toggle",
				order = 100,
				name = L["Ammo/Soul Bags"],
				desc = L["Include ammo/soul bags"],
				get = function() return db.includeAmmo end,
				set = function()
					db.includeAmmo = not db.includeAmmo
					Broker_Bags:BAG_UPDATE()
				end,
			},
			includeProfession = {
				type = "toggle",
				order = 200,
				name = L["Profession Bags"],
				desc = L["Include profession bags"],
				get = function() return db.includeProfession end,
				set = function()
					db.includeProfession = not db.includeProfession
					Broker_Bags:BAG_UPDATE()
				end,
			},
			showDepletion = {
				type = "toggle",
				order = 300,
				name = L["Bag Depletion"],
				desc = L["Show depletion of bags"],
				get = function() return db.showDepletion end,
				set = function()
					db.showDepletion = not db.showDepletion
					Broker_Bags:BAG_UPDATE()
				end,
			},
			showTotal = {
				type = "toggle",
				order = 400,
				name = L["Bag Total"],
				desc = L["Show total amount of space in bags"],
				get = function() return db.showTotal end,
				set = function()
					db.showTotal = not db.showTotal
					Broker_Bags:BAG_UPDATE()
				end,
			},
			openBagsAtBank = {
				type = "toggle",
				order = 500,
				name = L["Open Bags at Bank"],
				desc = L["Open all of your bags when you're at the bank"],
				get = function() return db.openBagsAtBank end,
				set = function()
					db.openBagsAtBank = not db.openBagsAtBank
					if db.openBagsAtBank then
						Broker_Bags:RegisterEvent("BANKFRAME_OPENED", function() OpenAllBags(true) end)
					else
						Broker_Bags:UnregisterEvent("BANKFRAME_OPENED")
					end
				end,
			},
			openBagsAtVendor = {
				type = "toggle",
				order = 600,
				name = L["Open Bags at Vendor"],
				desc = L["Open all of your bags when you're at a vendor"],
				get = function() return db.openBagsAtVendor end,
				set = function()
					db.openBagsAtVendor = not db.openBagsAtVendor
					if db.openBagsAtVendor then
						Broker_Bags:RegisterEvent("MERCHANT_SHOW", function() OpenAllBags(true) end)
						Broker_Bags:RegisterEvent("MERCHANT_CLOSED", function() CloseAllBags() end)
					else
						Broker_Bags:UnregisterEvent("MERCHANT_SHOW")
						Broker_Bags:UnregisterEvent("MERCHANT_CLOSED")
					end
				end,
			},
		},
	}
	return options
end

local function IsAmmoBag(bagType)
	-- 4: Soul Bag
	-- 2: Ammo Pouch
	-- 1: Quiver
	if bagType == 4 or bagType == 2 or bagType == 1 then
		return true
	end
	return false
end

local function IsProfessionBag(bagType)
	-- 1024: Mining Bag
	-- 512: Gem Bag
	-- 128: Engineering Bag
	-- 64: Enchanting Bag
	-- 32: Herb Bag
	-- 16: Inscription Bag
	-- 8: Leatherworking Bag
	if bagType == 1024 or bagType == 512 or bagType == 128 or bagType == 64 or bagType == 32 or bagType == 16 or bagType == 8 then
		return true
	end
	return false
end

local function GetBagColour(percent)
	local r, g, b
	if percent < 0 then
		r, g, b = 1, 0, 0
	elseif percent <= 0.5 then
		r, g, b = 1, percent * 2, 0
	elseif percent >= 1 then
		r, g, b = 0, 1, 0
	else
		r, g, b = 2 - percent * 2, 1, 0
	end
	return string_format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function dataobj:OnTooltipShow()
	-- Title, grab it from the TOC.
	self:AddLine(GetAddOnMetadata("Broker_Bags", "Title"))
	-- Show the bags in the tooltip, if needed
	if db.showBagsInTooltip then
		for i = 0, 4 do
			local bagSize = GetContainerNumSlots(i)
			if bagSize ~= nil and bagSize > 0 then
				local name, quality, icon, _
				if i == 0 then
					name = GetBagName(0)
					icon = "Interface\\Icons\\INV_Misc_Bag_08:16"
					quality = select(4, GetItemQualityColor(1))
				else
					name = GetBagName(i)
					_,_,quality,_,_,_,_,_,_,icon = GetItemInfo(name)
					quality = select(4, GetItemQualityColor(quality))
					icon = icon .. ":16"
				end
				local freeSlots = GetContainerNumFreeSlots(i)
				local takenSlots = bagSize - freeSlots
				local colour
				if db.showColours then
					colour = GetBagColour((bagSize - takenSlots) / bagSize)
					name = string_format("%s%s|r", quality, name)
				end
				if db.showDepletion then
					takenSlots = bagSize - takenSlots
				end
				local textL, textR
				textL = string_format("|T%s|t %s", icon, name)
				if db.showTotal then
					textR = string_format("%s%d/%d%s", colour and colour or "", takenSlots, bagSize, colour and "|r" or "")
				else
					textR = string_format("%s%d%s", colour and colour or "", takenSlots, colour and "|r" or "")
				end
				self:AddDoubleLine(textL, textR)
			end
		end
	end
	-- Hints!
	self:AddLine("|cffffff00" .. L["Click|r to open your bags"])
	self:AddLine("|cffffff00" .. L["Right-Click|r to open options menu"])
end

function dataobj:OnClick(button)
	if button == "LeftButton" then
		if not ContainerFrame1:IsShown() then
			for i = 1, 4 do
				if _G["ContainerFrame" .. (i + 1)]:IsShown() then
					_G["ContainerFrame" .. (i + 1)]:Hide()
				end
			end
			ToggleBackpack()
			if ContainerFrame1:IsShown() then
				for i = 1, 4 do
					local usable = true
					local _, bagType = GetContainerNumFreeSlots(i)
					if not db.includeAmmo and IsAmmoBag(bagType) then
						usable = false
					elseif not db.includeProfession and IsProfessionBag(bagType) then
						usable = false
					end
					if usable then
						ToggleBag(i)
					end
				end
			end
		else
			for i = 0, 4 do
				if _G["ContainerFrame" .. (i + 1)]:IsShown() then
					_G["ContainerFrame" .. (i + 1)]:Hide()
				end
			end
		end
	elseif button == "RightButton" then
		InterfaceOptionsFrame_OpenToCategory(LibStub("AceConfigDialog-3.0").BlizOptions["Broker_Bags"].frame)
	end
end

function Broker_Bags:OnInitialize()
	-- Saved Vars
	self.db = LibStub("AceDB-3.0"):New("BrokerBagsDB", defaults, "Default")
	db = self.db.profile
	-- Register the config
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Broker_Bags", GetOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Broker_Bags", GetAddOnMetadata("Broker_Bags", "Title"))
end

function Broker_Bags:OnEnable()
	self:RegisterBucketEvent("BAG_UPDATE", 1)
end

function Broker_Bags:BAG_UPDATE()
	local totalSlots = 0
	local takenSlots = 0
	for i = 0, 4 do
		local usable = true
		local freeSlots, bagType = GetContainerNumFreeSlots(i)

		if i >= 1 then
			if not db.includeAmmo and IsAmmoBag(bagType) then
				usable = false
			elseif not db.includeProfession and IsProfessionBag(bagType) then
				usable = false
			end
		end
		if usable then
			local bagSize = GetContainerNumSlots(i)
			if bagSize ~= nil and bagSize > 0 then
				totalSlots = totalSlots + bagSize
				takenSlots = takenSlots + (bagSize - freeSlots)
			end
		end
	end
	local colour
	if db.showColours then
		colour = GetBagColour((totalSlots - takenSlots) / totalSlots)
	end
	if db.showDepletion then
		takenSlots = totalSlots - takenSlots
	end
	local displayText
	if db.showTotal then
		displayText = string_format("%s%d/%d%s", colour and colour or "", takenSlots, totalSlots, colour and "|r" or "")
	else
		displayText = string_format("%s%d%s", colour and colour or "", takenSlots, colour and "|r" or "")
	end
	dataobj.text = displayText
end
