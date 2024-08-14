-- vim:ft=lua:
std = "lua51"

-- Show codes for warnings
codes = true

-- Disable colour output
color = false

-- Suppress reports for files without warnings
quiet = 1

-- Disable max line length check
max_line_length = false

-- We don't want to check externals Libs or this config file
exclude_files = {
    ".release/",
    "Libs/",
    ".luacheckrc",
}

-- Ignored warnings
ignore = {
    "211", -- Unused variable
    "212", -- Unused argument
    "431", -- Shadowed upvalue
}

-- Globals that we read/write
globals = {
    -- Our globals
    "Broker_BagFu",
}

-- Globals that we only read
read_globals = {
    -- Libraries
    "LibStub",

    -- C API
    "C_AddOns",
    "C_Container",

    -- API Functions
    "CloseAllBags",
    "GetAddOnMetadata",
    "GetBagName",
    "GetBuildInfo",
    "GetContainerNumFreeSlots",
    "GetContainerNumSlots",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetItemQualityColor",
    "InterfaceOptionsFrame_OpenToCategory",
    "IsShiftKeyDown",
    "Item",
    "OpenAllBags",
    "ToggleBackpack",
    "ToggleBag",

    -- FrameXML Globals
    "Enum",
    "LE_ITEM_QUALITY_COMMON",
    "NUM_BAG_SLOTS",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",

    -- Frames
    "ContainerFrame1",
    "Settings",
}
