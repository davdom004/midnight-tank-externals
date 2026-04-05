local _, addon = ...

addon.ui = {
    frame = nil,
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

function addon.ui:SavePosition()
    if not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)

    TankExternalsDB.position = TankExternalsDB.position or {}
    TankExternalsDB.position.point = point
    TankExternalsDB.position.relativePoint = relativePoint
    TankExternalsDB.position.x = x
    TankExternalsDB.position.y = y
end

function addon.ui:LoadPosition()
    if not self.frame then
        return
    end

    local pos = addon:GetConfig("position")
    if not pos then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        pos.point or "CENTER",
        UIParent,
        pos.relativePoint or "CENTER",
        pos.x or 0,
        pos.y or 0
    )
end

function addon.ui:ApplyFrameState()
    if not self.frame then
        return
    end

    local locked = addon:GetConfig("locked")
    local iconSize = addon:GetConfig("iconSize")

    self.frame:SetSize(iconSize, iconSize)

    if locked then
        self.frame:SetBackdrop(nil)
        self.frame:EnableMouse(false)
    else
        ApplyBorder(self.frame, 0.04, 0.04, 0.06, 0.45, 0.18, 0.18, 0.22, 0.85)
        self.frame:EnableMouse(true)
    end
end

function addon.ui:Init()
    local f = CreateFrame("Frame", "TankExternalsFrame", UIParent, "BackdropTemplate")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    f:SetScript("OnDragStart", function(frame)
        if not addon:GetConfig("locked") then
            frame:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon.ui:SavePosition()
    end)

    f:SetScript("OnUpdate", function(_, elapsed)
        addon.ui.elapsed = addon.ui.elapsed + elapsed
        if addon.ui.elapsed >= addon.ui.updateInterval then
            addon.ui.elapsed = 0
            addon.ui:Update()
        end
    end)

    self.frame = f
    self:LoadPosition()
    self:ApplyFrameState()
end

function addon.ui:CreateIcon(index)
    local icon = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    ApplyBorder(icon, 0.05, 0.05, 0.06, 0.95, 0.16, 0.16, 0.18, 1)

    icon.inner = CreateFrame("Frame", nil, icon)
    icon.inner:SetPoint("TOPLEFT", 1, -1)
    icon.inner:SetPoint("BOTTOMRIGHT", -1, 1)

    icon.texture = icon.inner:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()

    icon.shade = icon.inner:CreateTexture(nil, "BORDER")
    icon.shade:SetAllPoints()
    icon.shade:SetColorTexture(0, 0, 0, 0)

    icon.cd = CreateFrame("Cooldown", nil, icon.inner, "CooldownFrameTemplate")
    icon.cd:SetAllPoints()
    icon.cd:SetFrameLevel(icon:GetFrameLevel() + 2)

    icon.foreground = CreateFrame("Frame", nil, icon)
    icon.foreground:SetAllPoints()
    icon.foreground:SetFrameLevel(icon:GetFrameLevel() + 10)

    icon.nameText = icon.foreground:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.nameText:SetMaxLines(1)
    icon.nameText:SetWordWrap(false)

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
    local layout = addon:GetConfig("layout")
    local iconSize = addon:GetConfig("iconSize")
    local spacing = addon:GetConfig("spacing")

    for i = 1, count do
        local icon = self.icons[i]
        if icon then
            icon:SetSize(iconSize, iconSize)
            self:ApplyNameTextPosition(icon)

            icon:ClearAllPoints()

            if i == 1 then
                icon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
            else
                if layout == "VERTICAL" then
                    icon:SetPoint("TOP", self.icons[i - 1], "BOTTOM", 0, -spacing)
                else
                    icon:SetPoint("LEFT", self.icons[i - 1], "RIGHT", spacing, 0)
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
        return
    end

    if layout == "VERTICAL" then
        self.frame:SetSize(iconSize, (iconSize * count) + (spacing * (count - 1)))
    else
        self.frame:SetSize((iconSize * count) + (spacing * (count - 1)), iconSize)
    end
end

function addon.ui:BuildDisplayData()
    if addon:GetConfig("testMode") then
        if not addon.state.testData then
            local now = GetTime()
            addon.state.testData = {
                { owner = "Playerone",   spellID = 33206,  readyAt = now + 20  },
                { owner = "Playertwo",   spellID = 102342, readyAt = now + 60  },
                { owner = "Playerthree", spellID = 6940,   readyAt = now - 5   },
                { owner = "Playerfour",  spellID = 47788,  readyAt = now + 120 },
            }
        end

        return addon.state.testData
    end

    addon.state.testData = nil

    local data = {}

    for _, entry in pairs(addon.state.roster or {}) do
        for _, spellID in ipairs(entry.externals or {}) do
            data[#data + 1] = {
                owner = entry.name or "?",
                class = entry.class,
                spellID = spellID,
                readyAt = 0,
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
        local remaining = entry.readyAt - now

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

        if remaining <= 0 then
            icon.cd:Hide()
            icon.texture:SetDesaturated(false)
            icon.shade:SetColorTexture(0, 0, 0, 0)
            icon:SetAlpha(1)
            icon:SetBackdropBorderColor(0.45, 0.45, 0.52, 1)
        else
            if duration > 0 then
                icon.cd:SetCooldown(entry.readyAt - duration, duration)
                icon.cd:Show()
            else
                icon.cd:Hide()
            end

            icon.texture:SetDesaturated(true)
            icon.shade:SetColorTexture(0, 0, 0, 0.20)
            icon:SetAlpha(0.82)
            icon:SetBackdropBorderColor(0.18, 0.18, 0.22, 1)
        end
    end
end
