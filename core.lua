local addonName, addon = ...

addon.name = addonName
addon.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
    or "DEV"

addon.defaults = {
    testMode = false,
    locked = false,
    layout = "HORIZONTAL",
    iconSize = 40,
    spacing = 6,
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -200,
    },
    nameText = {
        enabled = true,
        anchor = "BOTTOMLEFT",
        x = 1,
        y = 1,
        truncate = 5, -- 0 = full name
        fontSize = 10,
    },
}

local function CopyDefaults(src, dst)
    if type(src) ~= "table" then
        return dst
    end

    if type(dst) ~= "table" then
        dst = {}
    end

    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end

    return dst
end

addon.state = {
    externals = {},
}

function addon:GetConfig(key)
    return TankExternalsDB and TankExternalsDB[key]
end

function addon:SetConfig(key, value)
    if not TankExternalsDB then
        TankExternalsDB = {}
    end
    TankExternalsDB[key] = value
end

function addon:Refresh()
    if self.ui then
        self.ui:ApplyFrameState()
        self.ui:Update()
    end
end

SLASH_TANKEXTERNALS1 = "/te"
SlashCmdList["TANKEXTERNALS"] = function()
    if addon.config and addon.config.ToggleWindow then
        addon.config:ToggleWindow()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function()
    TankExternalsDB = CopyDefaults(addon.defaults, TankExternalsDB or {})

    if addon.ui then
        addon.ui:Init()
    end

    if addon.config and addon.config.Init then
        addon.config:Init()
    end

    addon:Refresh()
end)
