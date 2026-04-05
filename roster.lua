local _, addon = ...

addon.roster = addon.roster or {}

local specCache = {}
local inspectQueue = {}
local currentInspect = nil

local INSPECT_INTERVAL = 0.5
local lastInspectTime = 0

-- --------------------------------------------------
-- Helpers
-- --------------------------------------------------

local function Now()
    return GetTime()
end

local function GetGroupUnits()
    local units = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    else
        units[#units + 1] = "player"
    end

    return units
end

-- --------------------------------------------------
-- Tooltip spec detection (FAST PATH)
-- --------------------------------------------------

local tooltipSpecMap = nil

local function BuildSpecMap()
    tooltipSpecMap = {}

    for classIdx = 1, GetNumClasses() do
        local className, _, classId = GetClassInfo(classIdx)

        if classId then
            for specIdx = 1, GetNumSpecializationsForClassID(classId) do
                local specId, specName = GetSpecializationInfoForClassID(classId, specIdx)
                if specId and specName then
                    tooltipSpecMap[specName .. " " .. className] = specId
                end
            end
        end
    end
end

local function GetSpecFromTooltip(unit)
    if not C_TooltipInfo then return nil end

    if not tooltipSpecMap then
        BuildSpecMap()
    end

    local data = C_TooltipInfo.GetUnit(unit)
    if not data then return nil end

    for _, line in ipairs(data.lines) do
        if line.leftText then
            local specId = tooltipSpecMap[line.leftText]
            if specId then
                return specId
            end
        end
    end

    return nil
end

-- --------------------------------------------------
-- Spec resolving
-- --------------------------------------------------

function addon.roster:GetSpec(unit)
    if UnitIsUnit(unit, "player") then
        local index = GetSpecialization()
        if index then
            return GetSpecializationInfo(index)
        end
        return nil
    end

    local guid = UnitGUID(unit)
    if not guid then return nil end

    -- cached
    if specCache[guid] then
        return specCache[guid]
    end

    -- tooltip fast path
    local specId = GetSpecFromTooltip(unit)
    if specId then
        specCache[guid] = specId
        return specId
    end

    -- queue inspect
    if CanInspect(unit) then
        inspectQueue[guid] = unit
    end

    return nil
end

-- --------------------------------------------------
-- Inspect loop
-- --------------------------------------------------

local function ProcessInspectQueue()
    if currentInspect then return end

    if (Now() - lastInspectTime) < INSPECT_INTERVAL then
        return
    end

    for guid, unit in pairs(inspectQueue) do
        if UnitExists(unit) and CanInspect(unit) then
            currentInspect = unit
            inspectQueue[guid] = nil

            NotifyInspect(unit)
            lastInspectTime = Now()
            return
        else
            inspectQueue[guid] = nil
        end
    end
end

local function OnInspectReady(unit)
    if not currentInspect or unit ~= currentInspect then return end

    local specId = GetInspectSpecialization(unit)
    if specId and specId > 0 then
        local guid = UnitGUID(unit)
        if guid then
            specCache[guid] = specId
        end
    end

    ClearInspectPlayer()
    currentInspect = nil

    addon:Refresh()
end

-- --------------------------------------------------
-- Build externals
-- --------------------------------------------------

function addon.roster:GetExternalsForUnit(unit)
    local _, classTag = UnitClass(unit)
    local specId = self:GetSpec(unit)

    local result = {}

    for spellID, info in pairs(addon.spells) do
        if info.class == classTag then
            if addon:IsSpellEnabled(spellID) then
                if addon:IsSpellSpecAllowed(spellID, specId) then
                    result[#result + 1] = spellID
                end
            end
        end
    end

    return result
end

-- --------------------------------------------------
-- Scan group
-- --------------------------------------------------

function addon.roster:Scan()
    addon.state.roster = {}

    for _, unit in ipairs(GetGroupUnits()) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid then
                addon.state.roster[guid] = {
                    unit = unit,
                    name = GetUnitName(unit, false),
                    class = select(2, UnitClass(unit)),
                    role = UnitGroupRolesAssigned(unit),
                    spec = self:GetSpec(unit),
                    externals = self:GetExternalsForUnit(unit),
                }
            end
        end
    end
end

-- --------------------------------------------------
-- Init
-- --------------------------------------------------

function addon.roster:Init()
    local f = CreateFrame("Frame")

    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("INSPECT_READY")

    f:SetScript("OnEvent", function(_, event, ...)
        if event == "INSPECT_READY" then
            OnInspectReady(...)
        else
            addon.roster:Scan()
            addon:Refresh()
        end
    end)

    -- lightweight loop
    C_Timer.NewTicker(0.2, function()
        ProcessInspectQueue()
    end)
end
