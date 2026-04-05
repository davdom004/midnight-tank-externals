local _, addon = ...

addon.roster = addon.roster or {}

local inspectInterval = 0.5
local inspectTimeout = 10

local specCache = {}
local priorityQueue = {}
local requestedUnit = nil
local currentInspectUnit = nil
local inspectStarted = nil
local needUpdate = true

local tooltipSpecMap = nil

local function Now()
    return GetTimePreciseSec and GetTimePreciseSec() or GetTime()
end

local function BuildTooltipSpecMap()
    if tooltipSpecMap then
        return tooltipSpecMap
    end

    tooltipSpecMap = {}

    if not (GetNumClasses and GetClassInfo and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID) then
        return tooltipSpecMap
    end

    for classIndex = 1, GetNumClasses() do
        local className, _, classID = GetClassInfo(classIndex)
        if className and classID then
            for specIndex = 1, GetNumSpecializationsForClassID(classID) do
                local specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
                if specID and specName then
                    tooltipSpecMap[specName .. " " .. className] = specID
                end
            end
        end
    end

    return tooltipSpecMap
end

local function GetSpecFromTooltip(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return nil
    end

    local tooltipData = C_TooltipInfo.GetUnit(unit)
    if not tooltipData then
        return nil
    end

    local specMap = BuildTooltipSpecMap()

    for _, line in ipairs(tooltipData.lines or {}) do
        if line and line.leftText and not issecretvalue(line.leftText) then
            local specID = specMap[line.leftText]
            if specID then
                return specID
            end
        end
    end

    return nil
end

local function GetGroupUnits()
    local units = { "player" }

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    end

    return units
end

local function QueueInspect(unit)
    if not unit or UnitIsUnit(unit, "player") then
        return
    end

    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then
        return
    end

    if not priorityQueue[guid] then
        priorityQueue[guid] = unit
        needUpdate = true
    end
end

function addon.roster:GetUnitSpecID(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    if UnitIsUnit(unit, "player") then
        if GetSpecialization and GetSpecializationInfo then
            local index = GetSpecialization()
            if index then
                return GetSpecializationInfo(index)
            end
        end
        return nil
    end

    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then
        return nil
    end

    if specCache[guid] and specCache[guid] > 0 then
        return specCache[guid]
    end

    local tooltipSpecID = GetSpecFromTooltip(unit)
    if tooltipSpecID then
        specCache[guid] = tooltipSpecID
        return tooltipSpecID
    end

    if CanInspect(unit) and UnitIsConnected(unit) then
        QueueInspect(unit)
    end

    return nil
end

function addon.roster:GetFilteredExternals(unit)
    local _, classTag = UnitClass(unit)
    if not classTag then
        return {}
    end

    local specID = self:GetUnitSpecID(unit)
    local results = {}

    for spellID, info in pairs(addon.spells or {}) do
        if info.class == classTag and addon:IsSpellEnabled(spellID) then
            local allowed = true

            if info.specs and next(info.specs) ~= nil then
                allowed = false

                if specID and info.specs[specID] then
                    allowed = addon:IsSpellSpecAllowed(spellID, specID)
                end
            end

            if allowed then
                results[#results + 1] = spellID
            end
        end
    end

    table.sort(results)
    return results
end

function addon.roster:Scan()
    addon.state.roster = addon.state.roster or {}

    local seen = {}
    for _, unit in ipairs(GetGroupUnits()) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid and not issecretvalue(guid) then
                local entry = addon.state.roster[guid] or {}

                entry.guid = guid
                entry.unit = unit
                entry.name = GetUnitName(unit, false) or "?"
                entry.class = select(2, UnitClass(unit))
                entry.role = UnitGroupRolesAssigned(unit)
                entry.specID = self:GetUnitSpecID(unit)
                entry.externals = self:GetFilteredExternals(unit)

                addon.state.roster[guid] = entry
                seen[guid] = true
            end
        end
    end

    for guid in pairs(addon.state.roster) do
        if not seen[guid] then
            addon.state.roster[guid] = nil
            specCache[guid] = nil
            priorityQueue[guid] = nil
        end
    end
end

local function ProcessInspectQueue()
    if requestedUnit ~= nil and inspectStarted and (Now() - inspectStarted) < inspectTimeout then
        return
    end

    if requestedUnit ~= nil then
        ClearInspectPlayer()
        requestedUnit = nil
        currentInspectUnit = nil
    end

    if not needUpdate then
        return
    end

    local now = Now()
    if addon.roster.lastInspectAttempt and (now - addon.roster.lastInspectAttempt) < inspectInterval then
        return
    end

    for guid, unit in pairs(priorityQueue) do
        priorityQueue[guid] = nil

        if UnitExists(unit) and CanInspect(unit) and UnitIsConnected(unit) then
            addon.roster.lastInspectAttempt = now
            requestedUnit = unit
            currentInspectUnit = unit
            inspectStarted = now
            ClearInspectPlayer()
            NotifyInspect(unit)
            return
        end
    end

    needUpdate = false
end

local function HandleInspectReady(unit)
    if not currentInspectUnit or unit ~= currentInspectUnit then
        return
    end

    local guid = UnitGUID(unit)
    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)

    if guid and specID and specID > 0 then
        specCache[guid] = specID
    end

    ClearInspectPlayer()
    requestedUnit = nil
    currentInspectUnit = nil
    needUpdate = true

    addon.roster:Scan()
    addon:Refresh()
end

function addon.roster:Init()
    local frame = CreateFrame("Frame")
    self.frame = frame
    self.lastInspectAttempt = 0

    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("INSPECT_READY")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "INSPECT_READY" then
            HandleInspectReady(...)
            return
        end

        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            local unit = ...
            if unit and UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    specCache[guid] = nil
                    QueueInspect(unit)
                end
            end
        end

        needUpdate = true
        addon.roster:Scan()
        addon:Refresh()
    end)

    C_Timer.NewTicker(0.2, function()
        ProcessInspectQueue()
    end)

    needUpdate = true
    self:Scan()
end
