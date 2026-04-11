local _, addon = ...

addon.combat = addon.combat or {}

local activeAurasByTargetGuid = {}
local lastCastByGuid = {}

local castWindow = 0.25
local chargeCommitWindow = 0.25

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

local function GetSpellBaseCharges(spellID)
    if addon.combatRules and addon.combatRules.GetChargesForSpellId then
        return addon.combatRules:GetChargesForSpellId(spellID)
    end

    return 1
end

local function GetUnitMaxChargesForSpell(entry, spellID)
    local baseCharges = GetSpellBaseCharges(spellID)
    if not entry or not entry.unit then
        return baseCharges
    end

    if addon.talents and addon.talents.GetUnitMaxCharges then
        local _, classToken = UnitClass(entry.unit)
        return addon.talents:GetUnitMaxCharges(entry.unit, entry.specID, classToken, spellID, baseCharges)
    end

    return baseCharges
end

local function EnsureChargeList(casterGUID, spellID)
    local cooldowns = EnsureCooldownTable()
    cooldowns[casterGUID] = cooldowns[casterGUID] or {}

    local charges = cooldowns[casterGUID][spellID]
    if type(charges) ~= "table" then
        if type(charges) == "number" and charges > Now() then
            charges = { charges }
        else
            charges = {}
        end
        cooldowns[casterGUID][spellID] = charges
    end

    return charges
end

local function NormalizeChargeList(charges, maxCharges)
    if type(charges) ~= "table" then
        return {}
    end

    local now = Now()
    local normalized = {}

    for _, readyAt in ipairs(charges) do
        if type(readyAt) == "number" and readyAt > now then
            normalized[#normalized + 1] = readyAt
        end
    end

    table.sort(normalized)

    while #normalized > maxCharges do
        table.remove(normalized, #normalized)
    end

    return normalized
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

    local ruleCooldown = addon.combatRules and addon.combatRules:GetCooldownForSpellId(spellID)
    if not ruleCooldown then
        return
    end

    local cooldown = ruleCooldown
    local entry = GetRosterEntryByGuid(casterGUID)

    if entry and entry.unit and addon.talents and addon.talents.GetUnitCooldown then
        cooldown = addon.talents:GetUnitCooldown(
            entry.unit,
            entry.specID,
            entry.class,
            spellID,
            ruleCooldown,
            Now() - startTime
        )
    end

    local maxCharges = GetUnitMaxChargesForSpell(entry, spellID)
    local charges = EnsureChargeList(casterGUID, spellID)
    charges = NormalizeChargeList(charges, maxCharges)
    EnsureCooldownTable()[casterGUID][spellID] = charges

    local queueTailReadyAt = charges[#charges] or startTime
    local newReadyAt = math.max(startTime, queueTailReadyAt) + cooldown

    for _, existingReadyAt in ipairs(charges) do
        if math.abs(existingReadyAt - newReadyAt) <= chargeCommitWindow then
            return
        end
    end

    if #charges >= maxCharges then
        return
    end

    charges[#charges + 1] = newReadyAt
    table.sort(charges)
    EnsureCooldownTable()[casterGUID][spellID] = charges
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

local function GetAllowedExternalRulesForEntry(entry)
    if not entry or not entry.unit then
        return {}
    end

    local measuredDummy = 0
    local allRules = {}
    local specID = entry.specID
    local _, classTag = UnitClass(entry.unit)
    if not classTag then
        return allRules
    end

    local rules = addon.combatRules and addon.combatRules.rules
    if not rules then
        return allRules
    end

    local ruleList = nil
    if specID and rules.BySpec and rules.BySpec[specID] then
        ruleList = rules.BySpec[specID]
    else
        ruleList = rules.ByClass and rules.ByClass[classTag]
    end

    if not ruleList then
        return allRules
    end

    for _, rule in ipairs(ruleList) do
        if rule.ExternalDefensive == true and SpellIsAllowedForEntry(entry, rule.SpellId) then
            allRules[#allRules + 1] = rule
        end
    end

    return allRules
end

local function PredictRuleFromSnapshot(auraStartTime, castSnapshot)
    local bestGuid = nil
    local bestRule = nil
    local bestCastTime = nil

    for guid, castInfo in pairs(castSnapshot or {}) do
        if castInfo and castInfo.time and math.abs(castInfo.time - auraStartTime) <= castWindow then
            local entry = GetRosterEntryByGuid(guid)
            if entry then
                local rules = GetAllowedExternalRulesForEntry(entry)

                if #rules == 1 then
                    if (not bestCastTime) or castInfo.time > bestCastTime then
                        bestGuid = guid
                        bestRule = rules[1]
                        bestCastTime = castInfo.time
                    end
                elseif castInfo.spellID and not issecretvalue(castInfo.spellID) then
                    for _, rule in ipairs(rules) do
                        if rule.SpellId == castInfo.spellID then
                            if (not bestCastTime) or castInfo.time > bestCastTime then
                                bestGuid = guid
                                bestRule = rule
                                bestCastTime = castInfo.time
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    return bestGuid, bestRule
end

local function ShouldCommitPredictedAuraCharge(predictedGuid, predictedRule, castSnapshot)
    if not predictedGuid or not predictedRule or not predictedRule.SpellId then
        return false
    end

    local castInfo = castSnapshot and castSnapshot[predictedGuid]
    if not castInfo then
        return true
    end

    if castInfo.spellID and castInfo.spellID == predictedRule.SpellId then
        return false
    end

    return true
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

    if existing then
        auras[aura.auraInstanceID] = {
            auraInstanceID = aura.auraInstanceID,
            startTime = existing.startTime,
            targetGUID = watch.guid,
            sourceGUID = existing.sourceGUID,
            predictedSpellID = existing.predictedSpellID,
            castSnapshot = existing.castSnapshot,
        }
        return
    end

    local startTime = Now()
    local castSnapshot = SnapshotCastTimes()
    local predictedGuid, predictedRule = PredictRuleFromSnapshot(startTime, castSnapshot)

    auras[aura.auraInstanceID] = {
        auraInstanceID = aura.auraInstanceID,
        startTime = startTime,
        targetGUID = watch.guid,
        sourceGUID = predictedGuid,
        predictedSpellID = predictedRule and predictedRule.SpellId or nil,
        castSnapshot = castSnapshot,
    }

    if ShouldCommitPredictedAuraCharge(predictedGuid, predictedRule, castSnapshot) then
        CommitCooldown(predictedGuid, predictedRule.SpellId, startTime)
    end
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

    if spellID and not issecretvalue(spellID) and addon.combatRules and addon.combatRules:IsExternalSpellId(spellID) then
        if SpellIsAllowedForEntry(entry, spellID) then
            CommitCooldown(watch.guid, spellID, Now())
            addon:Refresh()
            return
        end
    end
end

function addon.combat:GetReadyAt(guid, spellID)
    local currentCharges, _, nextReadyAt = self:GetChargeState(guid, spellID)
    if currentCharges > 0 then
        return 0
    end

    return nextReadyAt or 0
end

function addon.combat:GetChargeState(guid, spellID)
    if not guid or not spellID or issecretvalue(guid) or issecretvalue(spellID) then
        return 1, 1, 0
    end

    local entry = GetRosterEntryByGuid(guid)
    local maxCharges = GetUnitMaxChargesForSpell(entry, spellID)
    local cooldowns = addon.state.cooldowns
    local charges = cooldowns and cooldowns[guid] and cooldowns[guid][spellID]
    charges = NormalizeChargeList(charges, maxCharges)

    if cooldowns and cooldowns[guid] then
        cooldowns[guid][spellID] = charges
    end

    local currentCharges = math.max(maxCharges - #charges, 0)
    local nextReadyAt = charges[1] or 0

    return currentCharges, maxCharges, nextReadyAt
end

function addon.combat:GetChargeReadyTimes(guid, spellID)
    local currentCharges, maxCharges, nextReadyAt = self:GetChargeState(guid, spellID)
    local results = {}

    for _ = 1, currentCharges do
        results[#results + 1] = 0
    end

    if currentCharges < maxCharges then
        local cooldowns = addon.state.cooldowns
        local charges = cooldowns and cooldowns[guid] and cooldowns[guid][spellID]
        charges = NormalizeChargeList(charges, maxCharges)

        for _, readyAt in ipairs(charges) do
            results[#results + 1] = readyAt
        end
    elseif nextReadyAt and nextReadyAt > 0 then
        results[#results + 1] = nextReadyAt
    end

    if #results == 0 then
        results[1] = 0
    end

    return results
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
