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
    "Libs/",
    ".luacheckrc",
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

    -- API Functions
    "CloseAllBags",
    "GetAddOnMetadata",
    "GetBagName",
    "GetContainerNumFreeSlots",
    "GetContainerNumSlots",
    "GetItemInfo",
    "GetItemQualityColor",
    "InterfaceOptionsFrame_OpenToCategory",
    "IsShiftKeyDown",
    "OpenAllBags",
    "ToggleBackpack",
    "ToggleBag",

    -- FrameXML Globals
    "NUM_BAG_SLOTS",

    -- Frames
    "ContainerFrame1",
}
