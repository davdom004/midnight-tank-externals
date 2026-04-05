local _, addon = ...

addon.combat = addon.combat or {}

local activeAurasByTargetGuid = {}
local lastCastByGuid = {}

local castWindow = 0.25

local function Now()
    return GetTime()
end

local function EnsureCooldownTable()
    addon.state.cooldowns = addon.state.cooldowns or {}
    return addon.state.cooldowns
end

local function EnsureAuraTable(targetGUID)
    activeAurasByTargetGuid[targetGUID] = activeAurasByTargetGuid[targetGUID] or {}
    return activeAurasByTargetGuid[targetGUID]
end

local function GetRosterEntryByGuid(guid)
    if not guid or issecretvalue(guid) then
        return nil
    end

    return addon.state.roster and addon.state.roster[guid] or nil
end

local function SpellIsAllowedForEntry(entry, spellID)
    if not entry or not spellID or issecretvalue(spellID) then
        return false
    end

    if not addon:IsSpellEnabled(spellID) then
        return false
    end

    local info = addon.spells and addon.spells[spellID]
    if not info or info.class ~= entry.class then
        return false
    end

    local specID = entry.specID
    if info.specs and next(info.specs) ~= nil then
        if specID then
            if not info.specs[specID] then
                return false
            end
            if not addon:IsSpellSpecAllowed(spellID, specID) then
                return false
            end
        end
    end

    return true
end

local function CommitCooldown(casterGUID, spellID, startTime)
    if not casterGUID or issecretvalue(casterGUID) or not spellID or issecretvalue(spellID) or not startTime then
        return
    end

    local cooldown = addon.combatRules and addon.combatRules:GetCooldownForSpellId(spellID)
    if not cooldown then
        return
    end

    local cooldowns = EnsureCooldownTable()
    cooldowns[casterGUID] = cooldowns[casterGUID] or {}

    local newReadyAt = startTime + cooldown
    local existingReadyAt = cooldowns[casterGUID][spellID] or 0

    if newReadyAt > existingReadyAt then
        cooldowns[casterGUID][spellID] = newReadyAt
    end
end

local function IsExternalAuraInstance(unit, auraInstanceID)
    if not unit or issecretvalue(unit) or not auraInstanceID or issecretvalue(auraInstanceID) then
        return false
    end

    if not C_UnitAuras or not C_UnitAuras.IsAuraFilteredOutByInstanceID then
        return false
    end

    return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
end

local function SnapshotCastTimes()
    local snapshot = {}

    for guid, castInfo in pairs(lastCastByGuid) do
        snapshot[guid] = {
            time = castInfo.time,
            spellID = castInfo.spellID,
        }
    end

    return snapshot
end

local function TrackAura(watch, aura)
    if not watch or not watch.guid or not aura or not aura.auraInstanceID or issecretvalue(aura.auraInstanceID) then
        return
    end

    if not IsExternalAuraInstance(watch.unit, aura.auraInstanceID) then
        return
    end

    local auras = EnsureAuraTable(watch.guid)
    local existing = auras[aura.auraInstanceID]

    auras[aura.auraInstanceID] = {
        auraInstanceID = aura.auraInstanceID,
        startTime = existing and existing.startTime or Now(),
        targetGUID = watch.guid,
        sourceGUID = existing and existing.sourceGUID or nil,
        castSnapshot = existing and existing.castSnapshot or SnapshotCastTimes(),
    }
end

local function FindBestRuleForRemoval(auraData)
    if not auraData then
        return nil, nil
    end

    local measuredDuration = Now() - auraData.startTime

    if auraData.sourceGUID then
        local sourceEntry = GetRosterEntryByGuid(auraData.sourceGUID)
        if sourceEntry and sourceEntry.unit then
            local rule = addon.combatRules and addon.combatRules:GetMatchingRule(sourceEntry.unit, measuredDuration)
            if rule and SpellIsAllowedForEntry(sourceEntry, rule.SpellId) then
                return auraData.sourceGUID, rule
            end
        end
    end

    local bestGuid = nil
    local bestRule = nil
    local bestCastTime = nil

    for guid, castInfo in pairs(auraData.castSnapshot or {}) do
        if castInfo and castInfo.time and math.abs(castInfo.time - auraData.startTime) <= castWindow then
            local entry = GetRosterEntryByGuid(guid)
            if entry and entry.unit then
                local rule = addon.combatRules and addon.combatRules:GetMatchingRule(entry.unit, measuredDuration)
                if rule and SpellIsAllowedForEntry(entry, rule.SpellId) then
                    if (not bestCastTime) or castInfo.time > bestCastTime then
                        bestGuid = guid
                        bestRule = rule
                        bestCastTime = castInfo.time
                    end
                end
            end
        end
    end

    return bestGuid, bestRule
end

local function RemoveAura(watch, auraInstanceID)
    if not watch or not watch.guid or not auraInstanceID or issecretvalue(auraInstanceID) then
        return
    end

    local auras = activeAurasByTargetGuid[watch.guid]
    if not auras then
        return
    end

    local auraData = auras[auraInstanceID]
    if not auraData then
        return
    end

    local casterGUID, rule = FindBestRuleForRemoval(auraData)
    if casterGUID and rule and rule.SpellId then
        CommitCooldown(casterGUID, rule.SpellId, auraData.startTime)
    end

    auras[auraInstanceID] = nil
end

local function RebuildAurasForUnit(unit, guid)
    if not unit or issecretvalue(unit) or not guid or issecretvalue(guid) or not UnitExists(unit) then
        return
    end

    activeAurasByTargetGuid[guid] = {}

    if AuraUtil and AuraUtil.ForEachAura then
        local watch = { unit = unit, guid = guid }

        AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
            if aura and aura.auraInstanceID and not issecretvalue(aura.auraInstanceID) then
                TrackAura(watch, aura)
            end
            return false
        end, true)
    end
end

local function RebuildAllAuras()
    activeAurasByTargetGuid = {}

    for guid, entry in pairs(addon.state.roster or {}) do
        if entry.unit and UnitExists(entry.unit) then
            RebuildAurasForUnit(entry.unit, guid)
        end
    end
end

local function HandleAuraUpdate(watch, updateInfo)
    if not watch or not watch.unit or not watch.guid or not updateInfo then
        return
    end

    if updateInfo.isFullUpdate then
        RebuildAurasForUnit(watch.unit, watch.guid)
        addon:Refresh()
        return
    end

    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            TrackAura(watch, aura)
        end
    end

    if updateInfo.updatedAuraInstanceIDs and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            if auraInstanceID and not issecretvalue(auraInstanceID) then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(watch.unit, auraInstanceID)
                if aura then
                    TrackAura(watch, aura)
                end
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            RemoveAura(watch, auraInstanceID)
        end
    end

    addon:Refresh()
end

local function HandleCast(watch, spellID)
    if not watch or not watch.guid then
        return
    end

    lastCastByGuid[watch.guid] = {
        time = Now(),
        spellID = spellID,
    }

    local entry = GetRosterEntryByGuid(watch.guid)
    if not entry then
        return
    end

    -- Immediate cooldown start only when spell ID is readable.
    if spellID and not issecretvalue(spellID) and addon.combatRules and addon.combatRules:IsExternalSpellId(spellID) then
        if SpellIsAllowedForEntry(entry, spellID) then
            CommitCooldown(watch.guid, spellID, Now())
            addon:Refresh()
            return
        end
    end
end

function addon.combat:GetReadyAt(guid, spellID)
    local cooldowns = addon.state.cooldowns
    if not cooldowns or not guid or not spellID or issecretvalue(guid) or issecretvalue(spellID) then
        return 0
    end

    if not cooldowns[guid] then
        return 0
    end

    return cooldowns[guid][spellID] or 0
end

function addon.combat:Reset()
    activeAurasByTargetGuid = {}
    lastCastByGuid = {}
    addon.state.cooldowns = {}
    addon:Refresh()
end

function addon.combat:Init()
    if self.initialized then
        return
    end
    self.initialized = true

    addon.state.cooldowns = addon.state.cooldowns or {}

    addon.combatObserver:RegisterAuraCallback(function(watch, updateInfo)
        HandleAuraUpdate(watch, updateInfo)
    end)

    addon.combatObserver:RegisterCastCallback(function(watch, spellID)
        HandleCast(watch, spellID)
    end)

    addon.combatObserver:RegisterRosterChangedCallback(function()
        RebuildAllAuras()
        addon:Refresh()
    end)
end
