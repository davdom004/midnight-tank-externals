local _, addon = ...

addon.talents = addon.talents or {}

local T = addon.talents

-- Minimal talent adapter for TankExternals.
-- This intentionally focuses only on currently tracked externals.
--
-- Relevant talent-driven overrides for tracked externals.
-- We currently model flat cooldown reductions and extra charges.
-- Dynamic cooldown reduction effects like Protector of the Frail's PW:S
-- interaction are intentionally not modeled yet.

local TalentDrivenSpecModifiers = {
    [256] = { -- Discipline Priest
        [373035] = { { SpellId = 33206, ExtraCharges = 1 } }, -- Protector of the Frail
    },
    [105] = { -- Restoration Druid
        [382552] = { { SpellId = 102342, Amount = -20 } }, -- Ironbark
    },
    [1468] = { -- Preservation Evoker
        [376204] = { { SpellId = 357170, Amount = -10, ExtraCharges = 1 } }, -- Just in Time
    },
    [270] = { -- Mistweaver Monk
        [202424] = { { SpellId = 116849, Amount = -45 } }, -- Life Cocoon
    },
    [65] = { -- Holy Paladin
        [384820] = { { SpellId = 6940, Amount = -15 } }, -- Blessing of Sacrifice
    },
    [66] = { -- Protection Paladin
        [384820] = { { SpellId = 6940, Amount = -60 } }, -- Blessing of Sacrifice
    },
    [70] = { -- Retribution Paladin
        [384820] = { { SpellId = 6940, Amount = -60 } }, -- Blessing of Sacrifice
    },
}

local ConfigOnlySpecModifiers = {}

local playerTalentRanks = {}
local ConfigurableSpellCooldownModifiers = {}
local ConfigurableSpecCooldownModifiers = {}
local modifierMapsBuilt = false
local BuildConfigurableModifierMaps

local function SortEntries(entries)
    table.sort(entries, function(a, b)
        if (a.spellName or "") ~= (b.spellName or "") then
            return (a.spellName or "") < (b.spellName or "")
        end

        if (a.specName or "") ~= (b.specName or "") then
            return (a.specName or "") < (b.specName or "")
        end

        return (a.spellID or 0) < (b.spellID or 0)
    end)
end

local function EnsureCooldownModifierConfig()
    local config = addon:GetConfig("cooldownModifiers")
    if type(config) ~= "table" then
        config = {}
        addon:SetConfig("cooldownModifiers", config)
    end

    if type(config.defaults) ~= "table" then
        config.defaults = {}
    end

    if type(config.roster) ~= "table" then
        config.roster = {}
    end

    return config
end

local function GetModifierAmount(specID, spellID)
    if not modifierMapsBuilt then
        BuildConfigurableModifierMaps()
    end

    local modifiers = ConfigurableSpecCooldownModifiers[specID]
    local entry = modifiers and modifiers[spellID]
    return entry and entry.amount or 0
end

local function GetModifierExtraCharges(specID, spellID)
    if not modifierMapsBuilt then
        BuildConfigurableModifierMaps()
    end

    local modifiers = ConfigurableSpecCooldownModifiers[specID]
    local entry = modifiers and modifiers[spellID]
    return entry and entry.extraCharges or 0
end

local function ApplyModifier(baseCooldown, amount)
    return math.max((baseCooldown or 0) + (amount or 0), 0)
end

BuildConfigurableModifierMaps = function()
    ConfigurableSpellCooldownModifiers = {}
    ConfigurableSpecCooldownModifiers = {}

    local function RegisterModifier(specID, mod)
        local spellID = mod.SpellId
        local spellInfo = addon.spells and addon.spells[spellID]
        local specName = spellInfo and spellInfo.specs and spellInfo.specs[specID]

        if spellID and specName then
            local entry = {
                spellID = spellID,
                spellName = spellInfo.name,
                specID = specID,
                specName = specName,
                amount = mod.Amount or 0,
                extraCharges = mod.ExtraCharges or 0,
            }

            ConfigurableSpellCooldownModifiers[spellID] = ConfigurableSpellCooldownModifiers[spellID] or {}
            table.insert(ConfigurableSpellCooldownModifiers[spellID], entry)

            ConfigurableSpecCooldownModifiers[specID] = ConfigurableSpecCooldownModifiers[specID] or {}
            ConfigurableSpecCooldownModifiers[specID][spellID] = entry
        end
    end

    for specID, talents in pairs(TalentDrivenSpecModifiers) do
        for _, mods in pairs(talents) do
            for _, mod in ipairs(mods) do
                RegisterModifier(specID, mod)
            end
        end
    end

    for specID, mods in pairs(ConfigOnlySpecModifiers) do
        for _, mod in ipairs(mods) do
            if not (ConfigurableSpecCooldownModifiers[specID] and ConfigurableSpecCooldownModifiers[specID][mod.SpellId]) then
                RegisterModifier(specID, mod)
            end
        end
    end

    for _, entries in pairs(ConfigurableSpellCooldownModifiers) do
        SortEntries(entries)
    end

    modifierMapsBuilt = true
end

local function GetPlayerActiveTalentRanks()
    local ranks = {}

    if not (C_ClassTalents and C_Traits) then
        return ranks
    end

    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then
        return ranks
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then
        return ranks
    end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodeIDs = C_Traits.GetTreeNodes(treeID)
        for _, nodeID in ipairs(nodeIDs or {}) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
                local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
                if entryInfo and entryInfo.definitionID then
                    local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if defInfo and defInfo.spellID then
                        ranks[defInfo.spellID] = nodeInfo.activeRank
                    end
                end
            end
        end
    end

    return ranks
end

local function RefreshLocalPlayerTalents()
    playerTalentRanks = GetPlayerActiveTalentRanks()
end

local function GetPlayerModifierAmount(specID, abilityID)
    local mods = TalentDrivenSpecModifiers[specID]
    if not mods then
        return 0, 0, 0
    end

    local addAmount = 0
    local multAmount = 0
    local extraCharges = 0

    for talentSpellID, talentMods in pairs(mods) do
        local rank = playerTalentRanks[talentSpellID]
        if rank and rank > 0 then
            for _, mod in ipairs(talentMods) do
                if mod.SpellId == abilityID then
                    if mod.Mult then
                        multAmount = multAmount + mod.Amount
                    else
                        addAmount = addAmount + (mod.Amount or 0)
                    end
                    extraCharges = extraCharges + (mod.ExtraCharges or 0)
                end
            end
        end
    end

    return addAmount, multAmount, extraCharges
end

function T:GetUnitSpecId(unit)
    if addon.roster and addon.roster.GetUnitSpecID then
        return addon.roster:GetUnitSpecID(unit)
    end
    return nil
end

function T:UnitHasTalent(unit, talentSpellID, specID)
    if not UnitIsUnit(unit, "player") then
        return false
    end

    return (playerTalentRanks[talentSpellID] or 0) > 0
end

function T:GetSpellCooldownModifierOptions(spellID)
    if not modifierMapsBuilt then
        BuildConfigurableModifierMaps()
    end
    return ConfigurableSpellCooldownModifiers[spellID] or {}
end

function T:GetSpecCooldownModifierOptions(specID)
    if not modifierMapsBuilt then
        BuildConfigurableModifierMaps()
    end

    local indexed = ConfigurableSpecCooldownModifiers[specID]
    if not indexed then
        return {}
    end

    local results = {}
    for _, entry in pairs(indexed) do
        results[#results + 1] = entry
    end
    SortEntries(results)
    return results
end

function T:GetDefaultModifierEnabled(spellID, specID)
    local config = EnsureCooldownModifierConfig()
    local spellDefaults = config.defaults[spellID]
    if not spellDefaults then
        return false
    end

    return spellDefaults[specID] == true
end

function T:SetDefaultModifierEnabled(spellID, specID, enabled)
    local config = EnsureCooldownModifierConfig()
    config.defaults[spellID] = config.defaults[spellID] or {}
    config.defaults[spellID][specID] = enabled == true
    addon:SetConfig("cooldownModifiers", config)
end

function T:GetRosterModifierOverride(guid, spellID, specID)
    if not guid then
        return nil
    end

    local config = EnsureCooldownModifierConfig()
    local rosterConfig = config.roster[guid]
    local spellConfig = rosterConfig and rosterConfig[spellID]
    if spellConfig == nil then
        return nil
    end

    return spellConfig[specID]
end

function T:SetRosterModifierOverride(guid, spellID, specID, state)
    if not guid then
        return
    end

    local config = EnsureCooldownModifierConfig()

    if state == nil then
        local rosterConfig = config.roster[guid]
        local spellConfig = rosterConfig and rosterConfig[spellID]
        if spellConfig then
            spellConfig[specID] = nil
            if next(spellConfig) == nil then
                rosterConfig[spellID] = nil
            end
            if next(rosterConfig) == nil then
                config.roster[guid] = nil
            end
        end
    else
        config.roster[guid] = config.roster[guid] or {}
        config.roster[guid][spellID] = config.roster[guid][spellID] or {}
        config.roster[guid][spellID][specID] = state == true
    end

    addon:SetConfig("cooldownModifiers", config)
end

function T:GetEffectiveModifierEnabled(guid, spellID, specID)
    local override = self:GetRosterModifierOverride(guid, spellID, specID)
    if override ~= nil then
        return override
    end

    return self:GetDefaultModifierEnabled(spellID, specID)
end

function T:GetUnitCooldown(unit, specID, classToken, abilityID, baseCooldown, measuredDuration)
    if not abilityID or not specID then
        return baseCooldown
    end

    if UnitIsUnit(unit, "player") then
        local addAmount, multAmount = GetPlayerModifierAmount(specID, abilityID)
        local cooldown = baseCooldown + addAmount + (baseCooldown * multAmount / 100)
        return math.max(cooldown, 0)
    end

    local guid = unit and UnitGUID(unit)
    if not guid or issecretvalue(guid) then
        return baseCooldown
    end

    if self:GetEffectiveModifierEnabled(guid, abilityID, specID) then
        return ApplyModifier(baseCooldown, GetModifierAmount(specID, abilityID))
    end

    return baseCooldown
end

function T:GetUnitMaxCharges(unit, specID, classToken, abilityID, baseCharges)
    baseCharges = math.max(baseCharges or 1, 1)

    if not abilityID or not specID then
        return baseCharges
    end

    if UnitIsUnit(unit, "player") then
        local _, _, extraCharges = GetPlayerModifierAmount(specID, abilityID)
        return math.max(baseCharges + extraCharges, 1)
    end

    local guid = unit and UnitGUID(unit)
    if not guid or issecretvalue(guid) then
        return baseCharges
    end

    if self:GetEffectiveModifierEnabled(guid, abilityID, specID) then
        return math.max(baseCharges + GetModifierExtraCharges(specID, abilityID), 1)
    end

    return baseCharges
end

function T:GetUnitBuffDuration(unit, specID, classToken, abilityID, baseDuration)
    return baseDuration
end

function T:Init()
    BuildConfigurableModifierMaps()
    RefreshLocalPlayerTalents()

    local frame = CreateFrame("Frame")
    self.frame = frame
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:SetScript("OnEvent", function()
        RefreshLocalPlayerTalents()
    end)
end
