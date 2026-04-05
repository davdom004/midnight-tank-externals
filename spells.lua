local _, addon = ...

addon.spells = {
    [33206] = {
        name = "Pain Suppression",
        cooldown = 180,
        class = "PRIEST",
        specs = {
            [256] = "Discipline",
        },
        configurable = true,
    },

    [47788] = {
        name = "Guardian Spirit",
        cooldown = 180,
        class = "PRIEST",
        specs = {
            [257] = "Holy",
        },
        configurable = true,
    },

    [102342] = {
        name = "Ironbark",
        cooldown = 90,
        class = "DRUID",
        specs = {
            [105] = "Restoration",
        },
        configurable = true,
    },

    [6940] = {
        name = "Blessing of Sacrifice",
        cooldown = 120,
        class = "PALADIN",
        specs = {
            [65] = "Holy",
            [66] = "Protection",
        },
        configurable = true,
        allowSpecFilter = true,
    },

    [116849] = {
        name = "Life Cocoon",
        cooldown = 120,
        class = "MONK",
        specs = {
            [270] = "Mistweaver",
        },
        configurable = true,
    },

    [357170] = {
        name = "Time Dilation",
        cooldown = 60,
        class = "EVOKER",
        specs = {
            [1468] = "Preservation",
        },
        configurable = true,
    },
}

function addon:GetSpellList()
    local results = {}

    for spellID, info in pairs(self.spells or {}) do
        if info.configurable ~= false then
            table.insert(results, {
                spellID = spellID,
                name = info.name,
                info = info,
            })
        end
    end

    table.sort(results, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return results
end

function addon:IsSpellEnabled(spellID)
    local filters = self:GetConfig("spellFilters")
    if not filters or not filters.enabled then
        return true
    end

    local value = filters.enabled[spellID]
    if value == nil then
        return true
    end

    return value
end

function addon:IsSpellSpecAllowed(spellID, specID)
    local spell = self.spells and self.spells[spellID]
    if not spell then
        return false
    end

    if not spell.allowSpecFilter then
        return true
    end

    local filters = self:GetConfig("spellFilters")
    local spellSpecFilters = filters and filters.specFilter and filters.specFilter[spellID]

    if not spellSpecFilters then
        return true
    end

    if specID == nil then
        return true
    end

    return spellSpecFilters[specID] == true
end
