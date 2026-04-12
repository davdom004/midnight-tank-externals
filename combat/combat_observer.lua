local _, addon = ...

addon.combatObserver = addon.combatObserver or {}

local O = addon.combatObserver

local watched = {}
local auraCallbacks = {}
local castCallbacks = {}
local rosterCallbacks = {}
local wipeCallbacks = {}
local pendingRefresh = false

local function GetDesiredUnits()
    local units = {}

    for _, entry in pairs(addon.state.roster or {}) do
        if entry.unit and UnitExists(entry.unit) and not UnitCanAttack("player", entry.unit) then
            local guid = UnitGUID(entry.unit)
            if guid and not issecretvalue(guid) then
                units[entry.unit] = {
                    unit = entry.unit,
                    guid = guid,
                }
            end
        end
    end

    return units
end

local function FireAura(watch, updateInfo)
    for _, fn in ipairs(auraCallbacks) do
        fn(watch, updateInfo)
    end
end

local function FireCast(watch, spellID)
    for _, fn in ipairs(castCallbacks) do
        fn(watch, spellID)
    end
end

local function FireRosterChanged()
    for _, fn in ipairs(rosterCallbacks) do
        fn()
    end
end

local function FireWipe(encounterID, encounterName, difficultyID, groupSize)
    for _, fn in ipairs(wipeCallbacks) do
        fn(encounterID, encounterName, difficultyID, groupSize)
    end
end

local function CreateWatchFrame(watch)
    local frame = CreateFrame("Frame")
    frame.watch = watch

    frame:SetScript("OnEvent", function(self, event, ...)
        local w = self.watch
        if not w or not w.unit or not w.guid then
            return
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, rawSpellID = ...
            local spellID = nil

            if rawSpellID and not issecretvalue(rawSpellID) then
                spellID = rawSpellID
            end

            FireCast(w, spellID)
        elseif event == "UNIT_AURA" then
            local _, updateInfo = ...
            FireAura(w, updateInfo)
        end
    end)

    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", watch.unit)
    frame:RegisterUnitEvent("UNIT_AURA", watch.unit)

    return frame
end

local function DisposeWatch(unit)
    local watch = watched[unit]
    if not watch then
        return
    end

    if watch.frame then
        watch.frame:UnregisterAllEvents()
        watch.frame:SetScript("OnEvent", nil)
    end

    watched[unit] = nil
end

function O:RefreshWatches()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    pendingRefresh = false

    local desired = GetDesiredUnits()

    for unit in pairs(watched) do
        if not desired[unit] then
            DisposeWatch(unit)
        end
    end

    for unit, data in pairs(desired) do
        local existing = watched[unit]

        if not existing then
            local watch = {
                unit = data.unit,
                guid = data.guid,
            }
            watch.frame = CreateWatchFrame(watch)
            watched[unit] = watch
        else
            existing.guid = data.guid
        end
    end

    FireRosterChanged()
end

function O:RegisterAuraCallback(fn)
    auraCallbacks[#auraCallbacks + 1] = fn
end

function O:RegisterCastCallback(fn)
    castCallbacks[#castCallbacks + 1] = fn
end

function O:RegisterRosterChangedCallback(fn)
    rosterCallbacks[#rosterCallbacks + 1] = fn
end

function O:RegisterWipeCallback(fn)
    wipeCallbacks[#wipeCallbacks + 1] = fn
end

function O:Init()
    if self.eventsFrame then
        return
    end

    local frame = CreateFrame("Frame")
    self.eventsFrame = frame

    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("ENCOUNTER_END")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            if success == 0 then
                FireWipe(encounterID, encounterName, difficultyID, groupSize)
            end
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if pendingRefresh then
                O:RefreshWatches()
            end
            return
        end

        C_Timer.After(0, function()
            O:RefreshWatches()
        end)
    end)

    self:RefreshWatches()
end
