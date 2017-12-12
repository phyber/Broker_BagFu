-- Broker: BagFu
Broker_BagFu = LibStub("AceAddon-3.0"):NewAddon("Broker_BagFu", "AceEvent-3.0")
local Broker_BagFu, self = Broker_BagFu, Broker_BagFu
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local L = LibStub("AceLocale-3.0"):GetLocale("Broker_BagFu")

-- LDB data object
local dataobj = LDB:NewDataObject("Broker_BagFu", {
    type = "data source",
    text = '?/?',
    icon = "Interface\\AddOns\\Broker_BagFu\\icon.tga",
})

-- Options database and defaults
local db
local defaults = {
    profile = {
        showDepletion = false,
        includeProfession = true,
        showTotal = true,
        openBagsAtBank = false,
        openBagsAtVendor = false,
        showBagsInTooltip = true,
        showColours = false,
    },
}

--  Local functions and tables
local _G = _G
local select = select
local CloseAllBags = CloseAllBags
local GetAddOnMetadata = GetAddOnMetadata
local GetBagName = GetBagName
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetContainerNumSlots = GetContainerNumSlots
local GetItemQualityColor = GetItemQualityColor
local IsShiftKeyDown = IsShiftKeyDown
local OpenAllBags = OpenAllBags
local ToggleBackpack = ToggleBackpack

-- Addon Metadata
local ADDON_TITLE = GetAddOnMetadata("Broker_BagFu", "Title")
local ADDON_NOTES = GetAddOnMetadata("Broker_BagFu", "Notes")

-- Constants
local NUM_BAG_SLOTS = NUM_BAG_SLOTS

local function GetOptions()
    local options = {
        type = "group",
        name = ADDON_TITLE,
        get = function(info)
            return db[info[#info]]
        end,
        set = function(info, value)
            db[info[#info]] = value
            Broker_BagFu:BAG_UPDATE_DELAYED()
        end,
        args = {
            bbdesc = {
                type = "description",
                order = 0,
                name = ADDON_NOTES,
            },
            showColours = {
                type = "toggle",
                order = 50,
                name = L["Use Colours"],
                desc = L["Use colouring to show level of bag fullness"],
            },
            showBagsInTooltip = {
                type = "toggle",
                order = 75,
                name = L["Bags in Tooltip"],
                desc = L["Show all bags in the Broker: Bags tooltip"],
            },
            includeProfession = {
                type = "toggle",
                order = 200,
                name = L["Profession Bags"],
                desc = L["Include profession bags"],
            },
            showDepletion = {
                type = "toggle",
                order = 300,
                name = L["Bag Depletion"],
                desc = L["Show depletion of bags"],
            },
            showTotal = {
                type = "toggle",
                order = 400,
                name = L["Bag Total"],
                desc = L["Show total amount of space in bags"],
            },
            openBagsAtBank = {
                type = "toggle",
                order = 500,
                name = L["Open Bags at Bank"],
                desc = L["Open all of your bags when you're at the bank"],
                set = function()
                    db.openBagsAtBank = not db.openBagsAtBank
                    Broker_BagFu:ToggleOpenAtBank()
                end,
            },
            openBagsAtVendor = {
                type = "toggle",
                order = 600,
                name = L["Open Bags at Vendor"],
                desc = L["Open all of your bags when you're at a vendor"],
                set = function()
                    db.openBagsAtVendor = not db.openBagsAtVendor
                    Broker_BagFu:ToggleOpenAtVendor()
                end,
            },
        },
    }
    return options
end

-- Handy function to tell if something is a profession bag.
local IsProfessionBag
do
    local bagTypes = {
        -- 1048576: Tackle Box
        [0x100000] = true,
        -- 65536: Cooking Bag
        [0x10000] = true,
        -- 1024: Mining Bag
        [0x0400] = true,
        -- 512: Gem Bag
        [0x0200] = true,
        -- 128: Engineering Bag
        [0x0080] = true,
        -- 64: Enchanting Bag
        [0x0040] = true,
        -- 32: Herb Bag
        [0x0020] = true,
        -- 16: Inscription Bag
        [0x0010] = true,
        -- 8: Leatherworking Bag
        [0x0008] = true,
    }

    IsProfessionBag = function(bagType)
        return bagTypes[bagType] or false
    end
end

-- Get text colour for a bag based on percentage of fullness.
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

    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

-- Shown on LDB dataobj mouseover.
function dataobj:OnTooltipShow()
    -- Title, grab it from the TOC.
    self:AddLine(ADDON_TITLE)
    -- Show the bags in the tooltip, if needed
    if db.showBagsInTooltip then
        for i = 0, NUM_BAG_SLOTS do
            local bagSize = GetContainerNumSlots(i)

            if bagSize ~= nil and bagSize > 0 then
                local name, quality, icon, _
                name = GetBagName(i)

                if i == 0 then
                    icon = "Interface\\Icons\\INV_Misc_Bag_08:16"
                    quality = select(4, GetItemQualityColor(1))
                else
                    _,_,quality,_,_,_,_,_,_,icon = GetItemInfo(name)
                    quality = select(4, GetItemQualityColor(quality))
                    icon = icon .. ":16"
                end

                local freeSlots = GetContainerNumFreeSlots(i)
                local takenSlots = bagSize - freeSlots
                local colour

                if db.showColours then
                    colour = GetBagColour((bagSize - takenSlots) / bagSize)
                    name = ("|c%s%s|r"):format(quality, name)
                end

                if db.showDepletion then
                    takenSlots = bagSize - takenSlots
                end

                local textL, textR
                textL = ("|T%s|t %s"):format(icon, name)

                if db.showTotal then
                    textR = ("%s%d/%d%s"):format(
                        colour and colour or "",
                        takenSlots,
                        bagSize,
                        colour and "|r" or ""
                    )
                else
                    textR = ("%s%d%s"):format(
                        colour and colour or "",
                        takenSlots,
                        colour and "|r" or ""
                    )
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
            for i = 1, NUM_BAG_SLOTS do
                local cf = _G["ContainerFrame" .. (i + 1)]

                if cf:IsShown() then
                    cf:Hide()
                end
            end

            ToggleBackpack()

            if ContainerFrame1:IsShown() then
                for i = 1, NUM_BAG_SLOTS do
                    local usable = true
                    local _, bagType = GetContainerNumFreeSlots(i)

                    if not db.includeProfession and IsProfessionBag(bagType) then
                        usable = false
                    end

                    if usable or IsShiftKeyDown() then
                        ToggleBag(i)
                    end
                end
            end
        else
            for i = 0, NUM_BAG_SLOTS do
                local cf = _G["ContainerFrame" .. (i + 1)]

                if cf:IsShown() then
                    cf:Hide()
                end
            end
        end
    elseif button == "RightButton" then
        InterfaceOptionsFrame_OpenToCategory(ADDON_TITLE)
    end
end

function Broker_BagFu:OnInitialize()
    -- Saved Vars
    self.db = LibStub("AceDB-3.0"):New("BrokerBagsDB", defaults, "Default")
    db = self.db.profile
    -- Register the config
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Broker_BagFu", GetOptions)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Broker_BagFu", ADDON_TITLE)
end

function Broker_BagFu:OnEnable()
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:ToggleOpenAtBank()
    self:ToggleOpenAtVendor()

    -- Force a BAG_UPDATE since it no longer seems to fire at PLAYER_LOGIN
    -- since 5.0.4
    self:BAG_UPDATE_DELAYED()
end

function Broker_BagFu:ToggleOpenAtBank()
    if db.openBagsAtBank then
        self:RegisterEvent("BANKFRAME_OPENED", function()
            OpenAllBags(true)
        end)
    else
        self:UnregisterEvent("BANKFRAME_OPENED")
    end
end

function Broker_BagFu:ToggleOpenAtVendor()
    if db.openBagsAtVendor then
        Broker_BagFu:RegisterEvent("MERCHANT_SHOW", function()
            OpenAllBags(true)
        end)

        Broker_BagFu:RegisterEvent("MERCHANT_CLOSED", function()
            CloseAllBags()
        end)
    else
        Broker_BagFu:UnregisterEvent("MERCHANT_SHOW")
        Broker_BagFu:UnregisterEvent("MERCHANT_CLOSED")
    end
end

function Broker_BagFu:BAG_UPDATE_DELAYED()
    local totalSlots = 0
    local takenSlots = 0

    for i = 0, NUM_BAG_SLOTS do
        local usable = true
        local freeSlots, bagType = GetContainerNumFreeSlots(i)

        if i >= 1 then
            if not db.includeProfession and IsProfessionBag(bagType) then
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
        displayText = ("%s%d/%d%s"):format(
            colour and colour or "",
            takenSlots,
            totalSlots,
            colour and "|r" or ""
        )
    else
        displayText = ("%s%d%s"):format(
            colour and colour or "",
            takenSlots,
            colour and "|r" or ""
        )
    end

    dataobj.text = displayText
end
