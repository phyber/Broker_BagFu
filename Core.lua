-- Broker: BagFu
Broker_BagFu = LibStub("AceAddon-3.0"):NewAddon("Broker_BagFu", "AceEvent-3.0")
local Broker_BagFu, self = Broker_BagFu, Broker_BagFu
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local L = LibStub("AceLocale-3.0"):GetLocale("Broker_BagFu")
local icon = LibStub("LibDBIcon-1.0")
local _G = _G

-- LDB data object
local dataobj = LDB:NewDataObject("Broker_BagFu", {
    type = "data source",
    text = '?/?',
    icon = "Interface\\AddOns\\Broker_BagFu\\icon.tga",
})

-- Options database and defaults
local addonOptionsFrameName
local db
local defaults = {
    profile = {
        showDepletion = false,
        includeAmmo = true,
        includeProfession = true,
        showTotal = true,
        openBagsAtBank = false,
        openBagsAtVendor = false,
        showBagsInTooltip = true,
        showColours = false,
        minimap = {
            hide = false,
        },
    },
}

-- Locations of these functions vary between WoW versions.
local GetAddOnMetadata
local GetBagName
local GetContainerNumFreeSlots
local GetContainerNumSlots

-- We need to know if we're in the Classic client at multiple points throughout
-- the addon to decide which version of a function to use.
local IsClassic
do
    local is_retail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

    -- The inverse of the above should be true for Classic.
    local is_classic = not is_retail

    IsClassic = function()
        return is_classic
    end
end

-- Bag functions are in different locations depending on game version.
if IsClassic () then
    GetAddOnMetadata = _G.GetAddOnMetadata
    GetBagName = _G.GetBagName
    GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
    GetContainerNumSlots = _G.GetContainerNumSlots
else
    GetAddOnMetadata = C_AddOns.GetAddOnMetadata
    GetBagName = C_Container.GetBagName
    GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots
    GetContainerNumSlots = C_Container.GetContainerNumSlots
end

--  Local functions and tables
local select = select
local CloseAllBags = CloseAllBags
local GetItemInfo = GetItemInfo
local GetItemInfoInstant = GetItemInfoInstant
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
            minimap = {
                name = L["Minimap Icon"],
                desc = L["Toggle minimap icon"],
                type = "toggle",
                get = function() return not db.minimap.hide end,
                set = function()
                    db.minimap.hide = not db.minimap.hide
                    if db.minimap.hide then
                        icon:Hide("Broker_BagFu")
                    else
                        icon:Show("Broker_BagFu")
                    end
                end,
            },
        },
    }

    if IsClassic() then
        options.args.includeAmmo = {
            type = "toggle",
            order = "100",
            name = L["Ammo Bags"],
            desc = L["Include ammo bags"],
        }
    end

    return options
end

local function OpenOptions()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addonOptionsFrameName)
    else
        InterfaceOptionsFrame_OpenToCategory(addonOptionsFrameName)
    end
end

-- Ammo bags exist again in Classic
local function IsAmmoBag(bagType)
    -- 4: Soul Bag
    -- 2: Ammo Pouch
    -- 1: Quiver
    if bagType == 4 or bagType == 2 or bagType == 1 then
        return true
    end

    return false
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

-- This function is responsible for getting the bag icons and quality.
-- It will cache what it finds instead of repeatedly asking the client.
local GetBagIconAndQuality
do
    local bagIcon = {}
    local bagQuality = {}
    local BACKPACK_ICON = "Interface\\Icons\\INV_Misc_Bag_08:16"
    local ITEM_QUALITY_COMMON

    if IsClassic() then
        ITEM_QUALITY_COMMON = LE_ITEM_QUALITY_COMMON
    else
        ITEM_QUALITY_COMMON = Enum.ItemQuality.Common
    end

    GetBagIconAndQuality = function(name)
        -- This returns less than the usual GetItemInfo() but should always
        -- get us the itemID at least.
        local itemID = GetItemInfoInstant(name)

        -- If we already cached a result, use that.
        if bagQuality[itemID] then
            local icon = bagIcon[itemID]
            local quality = bagQuality[itemID]

            return quality, icon
        end

        -- Otherwise query the client for more info
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            local _,_,quality,_,_,_,_,_,_,icon = GetItemInfo(name)

            bagIcon[itemID] = icon
            bagQuality[itemID] = quality
        end)

        -- Return a default icon and quality if we fell through.
        return ITEM_QUALITY_COMMON, BACKPACK_ICON
    end
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
                local name = GetBagName(i)

                if name then
                    local quality, icon

                    if i == 0 then
                        icon = "Interface\\Icons\\INV_Misc_Bag_08:16"
                        quality = select(4, GetItemQualityColor(1))
                    else
                        quality, icon = GetBagIconAndQuality(name)
                        quality = select(4, GetItemQualityColor(quality))
                        icon = icon .. ":16"
                    end

                    local freeSlots, bagType = GetContainerNumFreeSlots(i)
                    local takenSlots = bagSize - freeSlots
                    local colour

                    if db.showColours then
                        local fillLevel

                        -- Ammo bags reverse the colour, it's good for them to
                        -- be full.
                        if IsAmmoBag(bagType) then
                            fillLevel = 1 - ((bagSize - takenSlots) / bagSize)
                        else
                            fillLevel = (bagSize - takenSlots) / bagSize
                        end

                        colour = GetBagColour(fillLevel)
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

                    if not db.includeAmmo and IsAmmoBag(bagType) then
                        usable = false
                    end

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
        OpenOptions()
    end
end

function Broker_BagFu:OnInitialize()
    local _

    -- Saved Vars
    self.db = LibStub("AceDB-3.0"):New("BrokerBagsDB", defaults, "Default")
    db = self.db.profile

    icon:Register("Broker_BagFu", dataobj, db.minimap)

    -- Register the config
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(
        "Broker_BagFu",
        GetOptions
    )

    _, addonOptionsFrameName = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
        "Broker_BagFu",
        ADDON_TITLE
    )
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
            OpenAllBags(nil)
        end)
    else
        self:UnregisterEvent("BANKFRAME_OPENED")
    end
end

function Broker_BagFu:ToggleOpenAtVendor()
    if db.openBagsAtVendor then
        Broker_BagFu:RegisterEvent("MERCHANT_SHOW", function()
            OpenAllBags(nil)
        end)

        Broker_BagFu:RegisterEvent("MERCHANT_CLOSED", function()
            CloseAllBags(nil)
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
            if not db.includeAmmo and IsAmmoBag(bagType) then
                usable = false
            end

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
