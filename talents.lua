local _, addon = ...

addon.talents = addon.talents or {}

local T = addon.talents

-- Minimal talent adapter for TankExternals.
-- This intentionally focuses only on currently tracked externals.
--
-- Relevant CDRs taken from the reference talent file:
-- Ironbark -20s, Time Dilation -10s, Life Cocoon -45s,
-- Blessing of Sacrifice -15s (Holy) / -60s (Prot/Ret).
-- Guardian Spirit's post-buff behavior is omitted for now.

local SpecCooldownModifiers = {
    [105] = { -- Restoration Druid
        [382552] = { { SpellId = 102342, Amount = -20 } }, -- Ironbark
    },
    [1468] = { -- Preservation Evoker
        [376204] = { { SpellId = 357170, Amount = -10 } }, -- Time Dilation
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

-- Assumed defaults when we do not have real talent data for a group member.
local SpecDefaultTalentRanks = {
    [105] = {
        [382552] = 1,
    },
    [1468] = {
        [376204] = 1,
    },
    [270] = {
        [202424] = 1,
    },
    [65] = {
        [384820] = 1,
    },
    [66] = {
        [384820] = 1,
    },
    [70] = {
        [384820] = 1,
    },
}

local playerTalentRanks = {}

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

local function GetEffectiveTalentRanks(unit, specID)
    if UnitIsUnit(unit, "player") then
        return playerTalentRanks
    end

    return SpecDefaultTalentRanks[specID] or {}
end

function T:GetUnitSpecId(unit)
    if addon.roster and addon.roster.GetUnitSpecID then
        return addon.roster:GetUnitSpecID(unit)
    end
    return nil
end

function T:UnitHasTalent(unit, talentSpellID, specID)
    local ranks = GetEffectiveTalentRanks(unit, specID)
    return (ranks[talentSpellID] or 0) > 0
end

function T:GetUnitCooldown(unit, specID, classToken, abilityID, baseCooldown, measuredDuration)
    local ranks = GetEffectiveTalentRanks(unit, specID)
    if not ranks then
        return baseCooldown
    end

    local mods = SpecCooldownModifiers[specID]
    if not mods then
        return baseCooldown
    end

    local addAmount = 0
    local multAmount = 0

    for talentSpellID, talentMods in pairs(mods) do
        local rank = ranks[talentSpellID]
        if rank and rank > 0 then
            for _, mod in ipairs(talentMods) do
                if mod.SpellId == abilityID then
                    if mod.Mult then
                        multAmount = multAmount + mod.Amount
                    else
                        addAmount = addAmount + mod.Amount
                    end
                end
            end
        end
    end

    local cooldown = baseCooldown + addAmount + (baseCooldown * multAmount / 100)
    return math.max(cooldown, 0)
end

function T:GetUnitBuffDuration(unit, specID, classToken, abilityID, baseDuration)
    return baseDuration
end

function T:Init()
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
