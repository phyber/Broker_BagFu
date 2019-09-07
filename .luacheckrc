-- vim:ft=lua:
std = "lua51"
max_line_length = false
exclude_files = {
    "Libs/",
    ".luacheckrc",
}

globals = {
    -- Our globals
    "Broker_BagFu",
}

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
