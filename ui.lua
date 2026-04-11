local _, addon = ...

addon.ui = {
    frame = nil,
    anchorFrame = nil,
    icons = {},
    elapsed = 0,
    updateInterval = 0.1,
}

local function TruncateText(text, maxChars)
    if not text then
        return ""
    end

    maxChars = tonumber(maxChars) or 0
    if maxChars <= 0 then
        return text
    end

    if #text <= maxChars then
        return text
    end

    return string.sub(text, 1, maxChars)
end

local function ApplyBorder(frame, bgR, bgG, bgB, bgA, brR, brG, brB, brA)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(brR, brG, brB, brA)
end

local function GetDisplayChargeReadyTimes(spellID, readyAt)
    local maxCharges = 1
    if addon.combatRules and addon.combatRules.GetChargesForSpellId then
        maxCharges = addon.combatRules:GetChargesForSpellId(spellID)
    end

    if maxCharges <= 1 then
        return { readyAt or 0 }
    end

    local results = { readyAt or 0 }
    for _ = 2, maxCharges do
        results[#results + 1] = 0
    end
    return results
end

local function GetDisplayChargeState(spellID, readyAt)
    local readyTimes = GetDisplayChargeReadyTimes(spellID, readyAt)
    local maxCharges = #readyTimes
    local currentCharges = 0

    for _, chargeReadyAt in ipairs(readyTimes) do
        if chargeReadyAt <= 0 then
            currentCharges = currentCharges + 1
        end
    end

    local nextReadyAt = 0
    for _, chargeReadyAt in ipairs(readyTimes) do
        if chargeReadyAt > 0 then
            nextReadyAt = chargeReadyAt
            break
        end
    end

    if maxCharges == 0 then
        maxCharges = 1
        currentCharges = 1
    end

    return currentCharges, maxCharges, nextReadyAt
end

function addon.ui:SavePosition()
    if not self.anchorFrame then
        return
    end

    local point, _, relativePoint, x, y = self.anchorFrame:GetPoint(1)

    TankExternalsDB.position = TankExternalsDB.position or {}
    TankExternalsDB.position.point = point
    TankExternalsDB.position.relativePoint = relativePoint
    TankExternalsDB.position.x = x
    TankExternalsDB.position.y = y
end

function addon.ui:LoadPosition()
    if not self.anchorFrame then
        return
    end

    local pos = addon:GetConfig("position")
    if not pos then
        return
    end

    self.anchorFrame:ClearAllPoints()
    self.anchorFrame:SetPoint(
        pos.point or "CENTER",
        UIParent,
        pos.relativePoint or "CENTER",
        pos.x or 0,
        pos.y or 0
    )
end

function addon.ui:ApplyFrameState()
    if not self.anchorFrame or not self.frame then
        return
    end

    local locked = addon:GetConfig("locked")
    local iconSize = addon:GetConfig("iconSize")

    self.anchorFrame:SetSize(iconSize, iconSize)

    if locked then
        self.anchorFrame:SetBackdrop(nil)
        self.anchorFrame:EnableMouse(false)
    else
        ApplyBorder(self.anchorFrame, 0.04, 0.04, 0.06, 0.45, 0.18, 0.18, 0.22, 0.85)
        self.anchorFrame:EnableMouse(true)
    end
end

function addon.ui:Init()
    local anchor = CreateFrame("Frame", "TankExternalsAnchorFrame", UIParent, "BackdropTemplate")
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetClampedToScreen(true)

    anchor:SetScript("OnDragStart", function(frame)
        if not addon:GetConfig("locked") then
            frame:StartMoving()
        end
    end)

    anchor:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon.ui:SavePosition()
    end)

    local f = CreateFrame("Frame", "TankExternalsFrame", UIParent)
    f:SetClampedToScreen(true)

    f:SetScript("OnUpdate", function(_, elapsed)
        addon.ui.elapsed = addon.ui.elapsed + elapsed
        if addon.ui.elapsed >= addon.ui.updateInterval then
            addon.ui.elapsed = 0
            addon.ui:Update()
        end
    end)

    self.anchorFrame = anchor
    self.frame = f

    self:LoadPosition()
    self:ApplyFrameState()
end

function addon.ui:CreateIcon(index)
    local icon = CreateFrame("Frame", nil, self.frame)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()

    icon.shade = icon:CreateTexture(nil, "BORDER")
    icon.shade:SetAllPoints()
    icon.shade:SetColorTexture(0, 0, 0, 0)

    icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cd:SetAllPoints()
    icon.cd:SetFrameLevel(icon:GetFrameLevel() + 2)

    icon.foreground = CreateFrame("Frame", nil, icon)
    icon.foreground:SetAllPoints()
    icon.foreground:SetFrameLevel(icon:GetFrameLevel() + 10)

    icon.nameText = icon.foreground:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.nameText:SetMaxLines(1)
    icon.nameText:SetWordWrap(false)

    icon.chargeText = icon.foreground:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.chargeText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    icon.chargeText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    icon.chargeText:SetTextColor(0.98, 0.93, 0.60, 1)

    self.icons[index] = icon
    return icon
end

function addon.ui:EnsureIcons(count)
    for i = 1, count do
        if not self.icons[i] then
            self:CreateIcon(i)
        end
    end
end

function addon.ui:ApplyNameTextPosition(icon)
    local nameCfg = addon:GetConfig("nameText") or {}
    local anchor = nameCfg.anchor or "BOTTOMLEFT"
    local x = nameCfg.x or 0
    local y = nameCfg.y or 0
    local fontSize = nameCfg.fontSize or 10

    icon.nameText:ClearAllPoints()
    icon.nameText:SetPoint(anchor, icon, anchor, x, y)
    icon.nameText:SetWidth(0)
    icon.nameText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    icon.nameText:SetTextColor(0.96, 0.96, 0.98, 1)
end

function addon.ui:Layout(count)
    local grow = addon:GetConfig("grow") or "RIGHT"
    local iconSize = addon:GetConfig("iconSize")
    local spacing = addon:GetConfig("spacing")

    for i = 1, count do
        local icon = self.icons[i]
        if icon then
            icon:SetSize(iconSize, iconSize)
            self:ApplyNameTextPosition(icon)

            icon:ClearAllPoints()

            if i == 1 then
                if grow == "LEFT" then
                    icon:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
                elseif grow == "UP" then
                    icon:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
                else
                    icon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
                end
            else
                local prev = self.icons[i - 1]

                if grow == "LEFT" then
                    icon:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
                elseif grow == "UP" then
                    icon:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
                elseif grow == "DOWN" then
                    icon:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
                else
                    icon:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
                end
            end

            icon:Show()
        end
    end

    for i = count + 1, #self.icons do
        self.icons[i]:Hide()
    end

    if count == 0 then
        self.frame:SetSize(iconSize, iconSize)
    else
        local totalWidth = (grow == "LEFT" or grow == "RIGHT")
            and ((iconSize * count) + (spacing * (count - 1)))
            or iconSize

        local totalHeight = (grow == "UP" or grow == "DOWN")
            and ((iconSize * count) + (spacing * (count - 1)))
            or iconSize

        self.frame:SetSize(totalWidth, totalHeight)
    end

    self.frame:ClearAllPoints()

    if grow == "LEFT" then
        self.frame:SetPoint("TOPRIGHT", self.anchorFrame, "TOPRIGHT", 0, 0)
    elseif grow == "UP" then
        self.frame:SetPoint("BOTTOMLEFT", self.anchorFrame, "BOTTOMLEFT", 0, 0)
    elseif grow == "DOWN" then
        self.frame:SetPoint("TOPLEFT", self.anchorFrame, "TOPLEFT", 0, 0)
    else
        self.frame:SetPoint("TOPLEFT", self.anchorFrame, "TOPLEFT", 0, 0)
    end
end

function addon.ui:BuildDisplayData()
    local data = {}

    if addon:GetConfig("testMode") then
        if not addon.state.testData then
            local now = GetTime()
            addon.state.testData = {
                { owner = "Playerone",   class = "PRIEST",  spellID = 33206,  readyAt = now + 20  },
                { owner = "Playertwo",   class = "DRUID",   spellID = 102342, readyAt = now + 60  },
                { owner = "Playerthree", class = "PALADIN", spellID = 6940,   readyAt = now - 5   },
                { owner = "Playerfour",  class = "PRIEST",  spellID = 47788,  readyAt = now + 120 },
                { owner = "Playerfive",  class = "MONK",    spellID = 116849, readyAt = now + 45  },
                { owner = "Playersix",   class = "EVOKER",  spellID = 357170, readyAt = now + 15  },
            }
        end

        for _, entry in ipairs(addon.state.testData) do
            if addon:IsSpellEnabled(entry.spellID) then
                local currentCharges, maxCharges, nextReadyAt = GetDisplayChargeState(entry.spellID, entry.readyAt)
                data[#data + 1] = {
                    owner = entry.owner,
                    class = entry.class,
                    spellID = entry.spellID,
                    readyAt = currentCharges > 0 and 0 or nextReadyAt,
                    currentCharges = currentCharges,
                    maxCharges = maxCharges,
                    nextReadyAt = nextReadyAt,
                }
            end
        end

        return data
    end

    addon.state.testData = nil

    for _, entry in pairs(addon.state.roster or {}) do
        for _, spellID in ipairs(entry.externals or {}) do
            local currentCharges, maxCharges, nextReadyAt = 1, 1, 0
            if addon.combat and addon.combat.GetChargeState then
                currentCharges, maxCharges, nextReadyAt = addon.combat:GetChargeState(entry.guid, spellID)
            end

            data[#data + 1] = {
                owner = entry.name or "?",
                class = entry.class,
                spellID = spellID,
                readyAt = currentCharges > 0 and 0 or nextReadyAt,
                currentCharges = currentCharges,
                maxCharges = maxCharges,
                nextReadyAt = nextReadyAt,
            }
        end
    end

    return data
end

function addon.ui:Update()
    if not self.frame then
        return
    end

    self:ApplyFrameState()

    local now = GetTime()
    local data = self:BuildDisplayData()

    table.sort(data, function(a, b)
        local aRemaining = a.readyAt - now
        local bRemaining = b.readyAt - now

        local aReady = aRemaining <= 0
        local bReady = bRemaining <= 0

        if aReady ~= bReady then
            return aReady
        end

        if a.readyAt ~= b.readyAt then
            return a.readyAt < b.readyAt
        end

        if (a.owner or "") ~= (b.owner or "") then
            return (a.owner or "") < (b.owner or "")
        end

        return (a.spellID or 0) < (b.spellID or 0)
    end)

    self:EnsureIcons(#data)
    self:Layout(#data)

    local nameCfg = addon:GetConfig("nameText") or {}
    local truncate = nameCfg.truncate or 0
    local showName = nameCfg.enabled ~= false

    for index, entry in ipairs(data) do
        local icon = self.icons[index]
        local spellInfo = addon.spells[entry.spellID]
        local texture = C_Spell.GetSpellTexture(entry.spellID)
        local duration = spellInfo and spellInfo.cooldown or 0
        local currentCharges = entry.currentCharges or 1
        local maxCharges = entry.maxCharges or 1
        local nextReadyAt = entry.nextReadyAt or 0
        local remaining = nextReadyAt - now

        icon.texture:SetTexture(texture)

        if showName then
            icon.nameText:Show()
            local name = TruncateText(entry.owner or "?", truncate)
            icon.nameText:SetText(name)

            local classTag = entry.class
            local color = RAID_CLASS_COLORS[classTag]
            if color then
                local hex = color.colorStr or ("ff%02x%02x%02x"):format(color.r*255, color.g*255, color.b*255)
                icon.nameText:SetText("|c" .. hex .. name .. "|r")
            else
                icon.nameText:SetText(name)
            end
        else
            icon.nameText:SetText("")
            icon.nameText:Hide()
        end

        if maxCharges > 1 then
            icon.chargeText:SetText(tostring(currentCharges))
            icon.chargeText:Show()
        else
            icon.chargeText:SetText("")
            icon.chargeText:Hide()
        end

        if currentCharges >= maxCharges then
            icon.cd:Hide()
            icon.texture:SetDesaturated(false)
            icon.shade:SetColorTexture(0, 0, 0, 0)
            icon:SetAlpha(1)
        else
            if duration > 0 then
                icon.cd:SetCooldown(nextReadyAt - duration, duration)
                icon.cd:Show()
            else
                icon.cd:Hide()
            end

            if currentCharges > 0 then
                icon.texture:SetDesaturated(false)
                icon.shade:SetColorTexture(0, 0, 0, 0)
                icon:SetAlpha(1)
            else
                icon.texture:SetDesaturated(true)
                icon.shade:SetColorTexture(0, 0, 0, 0.20)
                icon:SetAlpha(0.82)
            end
        end
    end
end
