local _, addon = ...

addon.combatRules = addon.combatRules or {}

-- Minimal external-cooldown matching rules for TankExternals.
-- We intentionally keep this much smaller than the reference addon:
-- - only tracked externals
-- - duration-based matching
-- - spec-first, class fallback
-- - no talent/C DR logic yet
--
-- Spec IDs:
-- Paladin: Holy=65, Protection=66, Retribution=70
-- Priest: Discipline=256, Holy=257
-- Monk: Mistweaver=270
-- Druid: Restoration=105
-- Evoker: Preservation=1468

local rules = {
    Tolerance = 0.5,

    -- More precise rules first.
    BySpec = {
        [256] = { -- Discipline Priest
            {
                SpellId = 33206,
                BuffDuration = 8,
                Cooldown = 180,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Pain Suppression
        },

        [257] = { -- Holy Priest
            {
                SpellId = 47788,
                BuffDuration = 10,
                Cooldown = 180,
                ExternalDefensive = true,
                CanCancelEarly = true,
            }, -- Guardian Spirit
        },

        [105] = { -- Restoration Druid
            {
                SpellId = 102342,
                BuffDuration = 12,
                Cooldown = 90,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Ironbark
        },

        [270] = { -- Mistweaver Monk
            {
                SpellId = 116849,
                BuffDuration = 12,
                Cooldown = 120,
                ExternalDefensive = true,
                CanCancelEarly = true,
            }, -- Life Cocoon
        },

        [1468] = { -- Preservation Evoker
            {
                SpellId = 357170,
                BuffDuration = 8,
                Cooldown = 60,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Time Dilation
        },

        [65] = { -- Holy Paladin
            {
                SpellId = 6940,
                BuffDuration = 12,
                Cooldown = 120,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Blessing of Sacrifice
        },

        [66] = { -- Protection Paladin
            {
                SpellId = 6940,
                BuffDuration = 12,
                Cooldown = 120,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Blessing of Sacrifice
        },

        [70] = { -- Retribution Paladin
            {
                SpellId = 6940,
                BuffDuration = 12,
                Cooldown = 120,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Blessing of Sacrifice
        },
    },

    -- Fallback if spec is unknown.
    ByClass = {
        PRIEST = {
            {
                SpellId = 33206,
                BuffDuration = 8,
                Cooldown = 180,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Pain Suppression
            {
                SpellId = 47788,
                BuffDuration = 10,
                Cooldown = 180,
                ExternalDefensive = true,
                CanCancelEarly = true,
            }, -- Guardian Spirit
        },

        DRUID = {
            {
                SpellId = 102342,
                BuffDuration = 12,
                Cooldown = 90,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Ironbark
        },

        MONK = {
            {
                SpellId = 116849,
                BuffDuration = 12,
                Cooldown = 120,
                ExternalDefensive = true,
                CanCancelEarly = true,
            }, -- Life Cocoon
        },

        EVOKER = {
            {
                SpellId = 357170,
                BuffDuration = 8,
                Cooldown = 60,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Time Dilation
        },

        PALADIN = {
            {
                SpellId = 6940,
                BuffDuration = 12,
                Cooldown = 120,
                ExternalDefensive = true,
                CanCancelEarly = false,
            }, -- Blessing of Sacrifice
        },
    },
}

local function GetRuleListForUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local _, classTag = UnitClass(unit)
    if not classTag then
        return nil
    end

    local specID = addon.roster and addon.roster.GetUnitSpecID and addon.roster:GetUnitSpecID(unit)

    if specID and rules.BySpec[specID] then
        return rules.BySpec[specID]
    end

    return rules.ByClass[classTag]
end

function addon.combatRules:GetMatchingRule(unit, measuredDuration)
    local ruleList = GetRuleListForUnit(unit)
    if not ruleList then
        return nil
    end

    for _, rule in ipairs(ruleList) do
        local expected = rule.BuffDuration
        local tolerance = rules.Tolerance or 0.5

        local durationMatches
        if rule.CanCancelEarly then
            durationMatches = measuredDuration <= (expected + tolerance)
        else
            durationMatches = math.abs(measuredDuration - expected) <= tolerance
        end

        if durationMatches then
            return rule
        end
    end

    return nil
end

function addon.combatRules:GetRuleBySpellId(spellID)
    if not spellID then
        return nil
    end

    for _, ruleList in pairs(rules.BySpec) do
        for _, rule in ipairs(ruleList) do
            if rule.SpellId == spellID then
                return rule
            end
        end
    end

    for _, ruleList in pairs(rules.ByClass) do
        for _, rule in ipairs(ruleList) do
            if rule.SpellId == spellID then
                return rule
            end
        end
    end

    return nil
end

function addon.combatRules:GetCooldownForSpellId(spellID)
    local rule = self:GetRuleBySpellId(spellID)
    return rule and rule.Cooldown or nil
end

function addon.combatRules:IsExternalSpellId(spellID)
    local rule = self:GetRuleBySpellId(spellID)
    return rule and rule.ExternalDefensive == true or false
end

addon.combatRules.rules = rules
