local _, addon = ...

addon.combat = addon.combat or {}

local trackedAurasByTargetGuid = {}

local function Now()
    return GetTime()
end

local function IsTrackedSpell(spellID)
    return addon.spells and addon.spells[spellID] ~= nil
end

local function EnsureCooldownTable()
    addon.state.cooldowns = addon.state.cooldowns or {}
    return addon.state.cooldowns
end

local function EnsureTrackedTable(targetGUID)
    trackedAurasByTargetGuid[targetGUID] = trackedAurasByTargetGuid[targetGUID] or {}
    return trackedAurasByTargetGuid[targetGUID]
end

local function GetAuraSourceGUID(aura)
    if not aura or not aura.sourceUnit then
        return nil
    end

    local sourceGUID = UnitGUID(aura.sourceUnit)
    if not sourceGUID or issecretvalue(sourceGUID) then
        return nil
    end

    return sourceGUID
end

local function GetCooldownForSpell(spellID)
    local info = addon.spells and addon.spells[spellID]
    return info and info.cooldown or nil
end

local function CommitCooldown(casterGUID, spellID, startTime)
    if not casterGUID or not spellID or not startTime then
        return
    end

    local cooldown = GetCooldownForSpell(spellID)
    if not cooldown then
        return
    end

    local cooldowns = EnsureCooldownTable()
    cooldowns[casterGUID] = cooldowns[casterGUID] or {}
    cooldowns[casterGUID][spellID] = startTime + cooldown
end

local function TrackAura(targetUnit, aura)
    if not aura or not aura.auraInstanceID or not aura.spellId then
        return
    end

    if not IsTrackedSpell(aura.spellId) then
        return
    end

    local targetGUID = UnitGUID(targetUnit)
    if not targetGUID or issecretvalue(targetGUID) then
        return
    end

    local tracked = EnsureTrackedTable(targetGUID)

    tracked[aura.auraInstanceID] = {
        auraInstanceID = aura.auraInstanceID,
        spellID = aura.spellId,
        startTime = Now(),
        targetGUID = targetGUID,
        sourceGUID = GetAuraSourceGUID(aura),
    }
end

local function RemoveTrackedAura(targetUnit, auraInstanceID)
    if not auraInstanceID then
        return
    end

    local targetGUID = UnitGUID(targetUnit)
    if not targetGUID or issecretvalue(targetGUID) then
        return
    end

    local tracked = trackedAurasByTargetGuid[targetGUID]
    if not tracked then
        return
    end

    local auraData = tracked[auraInstanceID]
    if not auraData then
        return
    end

    local casterGUID = auraData.sourceGUID or auraData.targetGUID
    CommitCooldown(casterGUID, auraData.spellID, auraData.startTime)

    tracked[auraInstanceID] = nil
end

local function ClearTrackedAurasForUnit(unit)
    local targetGUID = UnitGUID(unit)
    if not targetGUID or issecretvalue(targetGUID) then
        return
    end

    trackedAurasByTargetGuid[targetGUID] = {}
end

local function RebuildTrackedAurasForUnit(unit)
    ClearTrackedAurasForUnit(unit)

    if not UnitExists(unit) then
        return
    end

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
            if aura and aura.spellId and IsTrackedSpell(aura.spellId) then
                TrackAura(unit, aura)
            end
            return false
        end, true)
    end
end

local function HandleUnitAura(unit, updateInfo)
    if not unit or not UnitExists(unit) then
        return
    end

    if UnitCanAttack("player", unit) then
        return
    end

    if not updateInfo then
        return
    end

    if updateInfo.isFullUpdate then
        RebuildTrackedAurasForUnit(unit)
        addon:Refresh()
        return
    end

    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            TrackAura(unit, aura)
        end
    end

    if updateInfo.updatedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            -- Best-effort refresh: if the aura still exists and is tracked, refresh source if needed.
            if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
                if aura and aura.spellId and IsTrackedSpell(aura.spellId) then
                    TrackAura(unit, aura)
                end
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            RemoveTrackedAura(unit, auraInstanceID)
        end
    end

    addon:Refresh()
end

local function RebuildAllTrackedAuras()
    trackedAurasByTargetGuid = {}

    if not addon.state.roster then
        return
    end

    for _, entry in pairs(addon.state.roster) do
        if entry.unit and UnitExists(entry.unit) then
            RebuildTrackedAurasForUnit(entry.unit)
        end
    end
end

function addon.combat:GetReadyAt(guid, spellID)
    local cooldowns = addon.state.cooldowns
    if not cooldowns or not cooldowns[guid] then
        return 0
    end

    return cooldowns[guid][spellID] or 0
end

function addon.combat:Reset()
    trackedAurasByTargetGuid = {}
    addon.state.cooldowns = {}
    addon:Refresh()
end

function addon.combat:Init()
    addon.state.cooldowns = addon.state.cooldowns or {}

    local frame = CreateFrame("Frame")
    self.frame = frame

    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_AURA" then
            local unit, updateInfo = ...
            HandleUnitAura(unit, updateInfo)
            return
        end

        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0, function()
                RebuildAllTrackedAuras()
                addon:Refresh()
            end)
        end
    end)
end
