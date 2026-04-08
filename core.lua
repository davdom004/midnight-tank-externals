local addonName, addon = ...

addon.name = addonName
addon.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
    or "DEV"

addon.defaults = {
    testMode = false,
    locked = false,
    -- layout = "HORIZONTAL",
    grow = "RIGHT",
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
    spellFilters = {
        enabled = {
            [33206] = true,
            [47788] = true,
            [102342] = true,
            [6940] = true,
            [116849] = true,
            [357170] = true,
        },
        specFilter = {
            [6940] = {
                [65] = true, -- Holy
                [66] = false, -- Protection
                [70] = false -- Retri
            },
        },
    },
    cooldownModifiers = {
        defaults = {},
        roster = {},
    },
    configWindow = {
        width = 520,
        height = 640,
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
    roster = {},
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

local pendingCombatModules = false

local function InitCombatModules()
    if addon.combatObserver and addon.combatObserver.Init then
        addon.combatObserver:Init()
    end

    if addon.combat and addon.combat.Init then
        addon.combat:Init()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingCombatModules and not InCombatLockdown() then
            pendingCombatModules = false
            InitCombatModules()
            addon:Refresh()
        end
        return
    end

    TankExternalsDB = CopyDefaults(addon.defaults, TankExternalsDB or {})
    -- Migrator
    if TankExternalsDB.grow == nil and TankExternalsDB.layout ~= nil then
        if TankExternalsDB.layout == "VERTICAL" then
            TankExternalsDB.grow = "DOWN"
        else
            TankExternalsDB.grow = "RIGHT"
        end
    end

    if addon.ui then
        addon.ui:Init()
    end

    if addon.config and addon.config.Init then
        addon.config:Init()
    end

    if addon.roster and addon.roster.Init then
        addon.roster:Init()
    end

    if addon.talents and addon.talents.Init then
        addon.talents:Init()
    end

    if InCombatLockdown() then
        pendingCombatModules = true
    else
        InitCombatModules()
    end

    addon:Refresh()
end)
