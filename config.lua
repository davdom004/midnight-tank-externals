local _, addon = ...

addon.config = addon.config or {}

local NAME_ANCHORS = {
    "TOPLEFT",
    "TOP",
    "TOPRIGHT",
    "LEFT",
    "CENTER",
    "RIGHT",
    "BOTTOMLEFT",
    "BOTTOM",
    "BOTTOMRIGHT",
}

local GROW_OPTIONS = {
    "UP",
    "DOWN",
    "LEFT",
    "RIGHT",
}

local LAYOUT_OPTIONS = {
    "HORIZONTAL",
    "VERTICAL",
}

local function AbbreviateSpellName(name)
    if not name or name == "" then
        return "Spell"
    end

    if #name <= 12 then
        return name
    end

    local initials = {}
    for word in string.gmatch(name, "%S+") do
        initials[#initials + 1] = string.sub(word, 1, 1)
    end

    if #initials >= 2 then
        return table.concat(initials)
    end

    return string.sub(name, 1, 12)
end

local function AbbreviateSpecName(name)
    local known = {
        Restoration = "Resto",
        Preservation = "Pres",
        Mistweaver = "MW",
        Protection = "Prot",
        Retribution = "Ret",
        Discipline = "Disc",
    }

    if known[name] then
        return known[name]
    end

    if not name or name == "" then
        return "Spec"
    end

    if #name <= 8 then
        return name
    end

    return string.sub(name, 1, 8)
end

local function BuildDefaultModifierEntries()
    local entries = {}

    if not (addon.talents and addon.talents.GetSpellCooldownModifierOptions) then
        return entries
    end

    for _, spellEntry in ipairs(addon:GetSpellList()) do
        for _, option in ipairs(addon.talents:GetSpellCooldownModifierOptions(spellEntry.spellID)) do
            entries[#entries + 1] = option
        end
    end

    table.sort(entries, function(a, b)
        if (a.spellName or "") ~= (b.spellName or "") then
            return (a.spellName or "") < (b.spellName or "")
        end

        if (a.specName or "") ~= (b.specName or "") then
            return (a.specName or "") < (b.specName or "")
        end

        return (a.spellID or 0) < (b.spellID or 0)
    end)

    return entries
end

local function BuildModifierSummary(option, shortMode)
    local parts = {}

    if option.extraCharges and option.extraCharges > 0 then
        parts[#parts + 1] = string.format("+%dc", option.extraCharges)
    end

    if option.amount and option.amount ~= 0 then
        parts[#parts + 1] = string.format("%+ds", option.amount)
    end

    if #parts == 0 then
        return shortMode and "Talent" or "Talent override"
    end

    return table.concat(parts, ", ")
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function SetFrameBounds(frame, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
end

local function GetClampedWindowSize(width, height)
    return Clamp(width, 420, 900), Clamp(height, 410, 900)
end

local function ApplyPanelBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Buttons/WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.06, 0.06, 0.08, alpha or 0.96)
    frame:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)
end

local function CreateSection(parent, titleText, x, y, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    ApplyPanelBackdrop(frame, 0.75)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(titleText)

    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetColorTexture(1, 1, 1, 0.06)
    divider:SetPoint("TOPLEFT", 10, -30)
    divider:SetPoint("TOPRIGHT", -10, -30)
    divider:SetHeight(1)

    frame.title = title
    return frame
end

local function StyleFlatButton(button, active)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")

    button:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    if active then
        button:SetBackdropColor(0.18, 0.18, 0.24, 1)
        button:SetBackdropBorderColor(0.38, 0.38, 0.48, 1)
    else
        button:SetBackdropColor(0.10, 0.10, 0.13, 1)
        button:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)
    end
end

local function CreateHeaderActionButton(parent, text, width, height, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)
    button:SetScript("OnClick", onClick)

    StyleFlatButton(button, false)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.14, 0.14, 0.18, 1)
    end)

    button:SetScript("OnLeave", function(self)
        StyleFlatButton(self, false)
    end)

    return button
end

local function CreateCheckbox(parent, label, x, y, initialValue, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check.text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    check.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.text:SetText(label)
    check:SetChecked(initialValue)
    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)
    return check
end

local function CreateDropdown(parent, width)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    return dropdown
end

local function CreateNumberEditBox(parent, width, height, x, y, applyValue)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, height)
    box:SetPoint("TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)

    local function Commit(self)
        applyValue(self)
    end

    box:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)

    box:SetScript("OnEditFocusLost", function(self)
        Commit(self)
    end)

    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return box
end

local function CreateToggleButton(parent, label, width, height, x, y, initialValue, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    button.label = label
    button.isOn = initialValue and true or false

    ApplyPanelBackdrop(button, 1)

    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.text:SetPoint("CENTER")

    local function Refresh()
        if button.isOn then
            button.text:SetText(label .. ": ON")
            button:SetBackdropColor(0.16, 0.24, 0.18, 1)
            button:SetBackdropBorderColor(0.35, 0.52, 0.38, 1)
        else
            button.text:SetText(label .. ": OFF")
            button:SetBackdropColor(0.12, 0.12, 0.14, 1)
            button:SetBackdropBorderColor(0.22, 0.22, 0.26, 1)
        end
    end

    button:SetScript("OnEnter", function(self)
        if self.isOn then
            self:SetBackdropColor(0.20, 0.28, 0.22, 1)
        else
            self:SetBackdropColor(0.15, 0.15, 0.18, 1)
        end
    end)

    button:SetScript("OnLeave", function()
        Refresh()
    end)

    button:SetScript("OnClick", function(self)
        self.isOn = not self.isOn
        Refresh()
        onClick(self.isOn)
    end)

    button.SetState = function(self, value)
        self.isOn = value and true or false
        Refresh()
    end

    Refresh()
    return button
end

local function CreateCycleStateButton(parent, label, width, height, x, y, initialState, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    button.label = label
    button.state = initialState

    ApplyPanelBackdrop(button, 1)

    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.text:SetPoint("CENTER")

    local function Refresh()
        if button.state == true then
            button.text:SetText(button.label .. ": ON")
            button:SetBackdropColor(0.16, 0.24, 0.18, 1)
            button:SetBackdropBorderColor(0.35, 0.52, 0.38, 1)
        elseif button.state == false then
            button.text:SetText(button.label .. ": OFF")
            button:SetBackdropColor(0.25, 0.14, 0.14, 1)
            button:SetBackdropBorderColor(0.52, 0.28, 0.28, 1)
        else
            button.text:SetText(button.label .. ": DEFAULT")
            button:SetBackdropColor(0.12, 0.12, 0.14, 1)
            button:SetBackdropBorderColor(0.22, 0.22, 0.26, 1)
        end
    end

    button:SetScript("OnEnter", function(self)
        if self.state == true then
            self:SetBackdropColor(0.20, 0.28, 0.22, 1)
        elseif self.state == false then
            self:SetBackdropColor(0.30, 0.17, 0.17, 1)
        else
            self:SetBackdropColor(0.15, 0.15, 0.18, 1)
        end
    end)

    button:SetScript("OnLeave", function()
        Refresh()
    end)

    button:SetScript("OnClick", function(self)
        if self.state == nil then
            self.state = true
        elseif self.state == true then
            self.state = false
        else
            self.state = nil
        end

        Refresh()
        onClick(self, self.state)
    end)

    button.SetLabel = function(self, value)
        self.label = value
        Refresh()
    end

    button.SetState = function(self, value)
        self.state = value
        Refresh()
    end

    Refresh()
    return button
end

local function CreateTabButton(parent, text, width, height, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)
    button:SetScript("OnClick", onClick)
    StyleFlatButton(button, false)
    return button
end

function addon.config:ShowTab(tabName)
    self.activeTab = tabName

    if self.generalPage then
        if tabName == "GENERAL" then self.generalPage:Show() else self.generalPage:Hide() end
    end

    if self.textPage then
        if tabName == "TEXT" then self.textPage:Show() else self.textPage:Hide() end
    end

    if self.spellsPage then
        if tabName == "SPELLS" then self.spellsPage:Show() else self.spellsPage:Hide() end
    end

    if self.rosterPage then
        if tabName == "ROSTER" then self.rosterPage:Show() else self.rosterPage:Hide() end
    end

    if self.generalTab and self.textTab and self.spellsTab and self.rosterTab then
        StyleFlatButton(self.generalTab, tabName == "GENERAL")
        StyleFlatButton(self.textTab, tabName == "TEXT")
        StyleFlatButton(self.spellsTab, tabName == "SPELLS")
        StyleFlatButton(self.rosterTab, tabName == "ROSTER")
    end

    if tabName == "ROSTER" then
        self:RefreshRosterOverrides()
    end
end

function addon.config:RefreshOwnerNameVisibility()
    if not self.textPage then
        return
    end

    local enabled = ((addon:GetConfig("nameText") or {}).enabled ~= false)

    if self.positionSection then
        if enabled then self.positionSection:Show() else self.positionSection:Hide() end
    end

    if self.contentSection then
        if enabled then self.contentSection:Show() else self.contentSection:Hide() end
    end

    if self.typographySection then
        if enabled then self.typographySection:Show() else self.typographySection:Hide() end
    end
end

function addon.config:RefreshSpellControls()
    if self.spellRows then
        for spellID, row in pairs(self.spellRows) do
            row.enabled:SetChecked(addon:IsSpellEnabled(spellID))

            if row.specChecks then
                local spellFilters = addon:GetConfig("spellFilters") or {}
                local spellSpecFilter = spellFilters.specFilter and spellFilters.specFilter[spellID]

                for specID, specCheck in pairs(row.specChecks) do
                    local checked = true
                    if spellSpecFilter and spellSpecFilter[specID] ~= nil then
                        checked = spellSpecFilter[specID]
                    end
                    specCheck:SetChecked(checked == true)
                end
            end
        end
    end

    if self.defaultModifierChecks and addon.talents and addon.talents.GetDefaultModifierEnabled then
        for _, check in ipairs(self.defaultModifierChecks) do
            check:SetChecked(addon.talents:GetDefaultModifierEnabled(check.spellID, check.specID))
        end
    end
end

function addon.config:RefreshControls()
    if not self.window then
        return
    end

    self:ApplyResponsiveLayout()

    self.testModeButton:SetState(addon:GetConfig("testMode"))
    self.lockedButton:SetState(addon:GetConfig("locked"))

    local iconSize = addon:GetConfig("iconSize")
    self.iconSizeSlider:SetValue(iconSize)
    self.iconSizeValue:SetText(tostring(iconSize))

    local spacing = addon:GetConfig("spacing") or 0
    self.spacingSlider:SetValue(spacing)
    self.spacingValue:SetText(tostring(spacing))

    -- UIDropDownMenu_SetText(self.layoutDropdown, addon:GetConfig("layout") or "HORIZONTAL")
    UIDropDownMenu_SetText(self.growDropdown, addon:GetConfig("grow") or "RIGHT")

    local nameText = addon:GetConfig("nameText") or {}
    self.enableName:SetChecked(nameText.enabled ~= false)
    UIDropDownMenu_SetText(self.nameAnchorDropdown, nameText.anchor or "BOTTOMLEFT")
    self.nameXBox:SetText(tostring(nameText.x or 0))
    self.nameYBox:SetText(tostring(nameText.y or 0))
    self.nameTruncateBox:SetText(tostring(nameText.truncate or 0))
    self.nameFontSizeBox:SetText(tostring(nameText.fontSize or 10))

    self:RefreshOwnerNameVisibility()
    self:RefreshSpellControls()
    self:RefreshRosterOverrides()
end

function addon.config:SaveWindowSize()
    if not self.window then
        return
    end

    local width, height = GetClampedWindowSize(self.window:GetWidth(), self.window:GetHeight())

    addon:SetConfig("configWindow", {
        width = math.floor(width + 0.5),
        height = math.floor(height + 0.5),
    })
end

function addon.config:ApplyResponsiveLayout()
    if not (self.window and self.content) then
        return
    end

    local windowWidth = self.window:GetWidth()
    local windowHeight = self.window:GetHeight()
    local contentWidth = math.max(windowWidth - 36, 384)
    local contentHeight = math.max(windowHeight - 100, 310)

    local tabGap = 10
    local tabLeft = 14
    local availableTabWidth = windowWidth - (tabLeft * 2) - (tabGap * 3)
    local tabWidth = math.floor(availableTabWidth / 4)

    self.generalTab:SetWidth(tabWidth)
    self.textTab:SetWidth(tabWidth)
    self.spellsTab:SetWidth(tabWidth)
    self.rosterTab:SetWidth(tabWidth)

    self.generalTab:ClearAllPoints()
    self.generalTab:SetPoint("TOPLEFT", self.window, "TOPLEFT", tabLeft, -52)

    self.textTab:ClearAllPoints()
    self.textTab:SetPoint("LEFT", self.generalTab, "RIGHT", tabGap, 0)

    self.spellsTab:ClearAllPoints()
    self.spellsTab:SetPoint("LEFT", self.textTab, "RIGHT", tabGap, 0)

    self.rosterTab:ClearAllPoints()
    self.rosterTab:SetPoint("LEFT", self.spellsTab, "RIGHT", tabGap, 0)

    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", self.window, "TOPLEFT", 18, -84)
    self.content:SetPoint("BOTTOMRIGHT", self.window, "BOTTOMRIGHT", -18, 16)

    if self.generalPage then
        SetFrameBounds(self.generalStateSection, 0, 0, contentWidth, 72)
        SetFrameBounds(self.generalLayoutSection, 0, -84, contentWidth, 74)
        SetFrameBounds(self.generalSizingSection, 0, -170, contentWidth, math.max(contentHeight - 170, 142))
        self.iconSizeSlider:SetWidth(math.max(contentWidth - 164, 220))
        self.spacingSlider:SetWidth(math.max(contentWidth - 164, 220))
    end

    if self.textPage then
        SetFrameBounds(self.visibilitySection, 0, 0, contentWidth, 72)
        SetFrameBounds(self.positionSection, 0, -76, contentWidth, 92)
        SetFrameBounds(self.contentSection, 0, -180, contentWidth, 64)
        SetFrameBounds(self.typographySection, 0, -256, contentWidth, math.max(contentHeight - 256, 64))

        self.nameYLabel:ClearAllPoints()
        self.nameYLabel:SetPoint("TOPLEFT", self.positionSection, "TOPLEFT", math.max(contentWidth - 184, 200), -70)

        self.nameYBox:ClearAllPoints()
        self.nameYBox:SetPoint("TOPLEFT", self.positionSection, "TOPLEFT", math.max(contentWidth - 92, 292), -64)
    end

    if self.spellsPage then
        local defaultCount = #(self.defaultModifierChecks or {})
        local defaultsHeight = Clamp((defaultCount * 24) + 48, 110, math.max(contentHeight - 140, 110))
        local trackedHeight = math.max(contentHeight - defaultsHeight - 12, 120)

        SetFrameBounds(self.spellsTrackedSection, 0, 0, contentWidth, trackedHeight)
        SetFrameBounds(self.spellsDefaultsSection, 0, -(trackedHeight + 12), contentWidth, defaultsHeight)

        local trackedContentWidth = math.max(contentWidth - 42, 320)
        local defaultsContentWidth = math.max(contentWidth - 42, 320)
        self.spellsTrackedContent:SetWidth(trackedContentWidth)
        self.spellsDefaultsContent:SetWidth(defaultsContentWidth)

        for _, row in pairs(self.spellRows or {}) do
            row:SetWidth(trackedContentWidth - 12)
        end

        for _, check in ipairs(self.defaultModifierChecks or {}) do
            local row = check:GetParent()
            row:SetWidth(defaultsContentWidth - 12)
        end
    end

    if self.rosterPage then
        SetFrameBounds(self.rosterSection, 0, 0, contentWidth, contentHeight)
        self.rosterContent:SetWidth(math.max(contentWidth - 42, 320))
    end
end

function addon.config:RefreshRosterOverrides()
    if not self.rosterContent then
        return
    end

    self.rosterRows = self.rosterRows or {}

    local entries = {}
    for _, entry in pairs(addon.state.roster or {}) do
        entries[#entries + 1] = entry
    end

    table.sort(entries, function(a, b)
        if (a.name or "") ~= (b.name or "") then
            return (a.name or "") < (b.name or "")
        end

        return (a.guid or "") < (b.guid or "")
    end)

    local rowHeight = 58
    local offsetY = -4

    for index, entry in ipairs(entries) do
        local row = self.rosterRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.rosterContent, "BackdropTemplate")
            row:SetSize(348, rowHeight)
            ApplyPanelBackdrop(row, 0.55)

            row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.nameText:SetPoint("TOPLEFT", 10, -8)

            row.detailText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.detailText:SetPoint("TOPLEFT", 10, -24)
            row.detailText:SetTextColor(0.72, 0.72, 0.76, 1)

            row.emptyText = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            row.emptyText:SetPoint("TOPLEFT", 10, -40)

            row.buttons = {}
            self.rosterRows[index] = row
        end

        local rowWidth = math.max((self.rosterContent:GetWidth() or 348) - 8, 320)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, offsetY)
        row:SetWidth(rowWidth)
        row:Show()

        local specName = entry.specID and GetSpecializationInfoByID and select(2, GetSpecializationInfoByID(entry.specID))
        if not specName then
            specName = entry.specID and tostring(entry.specID) or "Unknown spec"
        end

        row.nameText:SetText(entry.name or "?")
        row.detailText:SetText(string.format("%s  |  %s", entry.class or "Unknown", specName))

        local options = {}
        if addon.talents and addon.talents.GetSpecCooldownModifierOptions then
            options = addon.talents:GetSpecCooldownModifierOptions(entry.specID)
        end

        local isPlayer = entry.unit and UnitExists(entry.unit) and UnitIsUnit(entry.unit, "player")

        for buttonIndex, button in ipairs(row.buttons) do
            if buttonIndex > #options then
                button:Hide()
            end
        end

        if isPlayer then
            for _, button in ipairs(row.buttons) do
                button:Hide()
            end
            row.emptyText:SetText("Uses your live talent data.")
            row.emptyText:Show()
        elseif #options == 0 then
            row.emptyText:SetText("No configurable cooldown reductions for this spec yet.")
            row.emptyText:Show()
        else
            row.emptyText:Hide()
        end

        if not isPlayer then
            local buttonWidth = Clamp(math.floor((rowWidth - 44) / math.max(#options, 1)), 92, 132)
            local buttonGap = 8
            for optionIndex, option in ipairs(options) do
                local button = row.buttons[optionIndex]
                if not button then
                    button = CreateCycleStateButton(
                        row,
                        "",
                        buttonWidth,
                        22,
                        10 + ((optionIndex - 1) * (buttonWidth + buttonGap)),
                        -32,
                        nil,
                        function(selfButton, state)
                            addon.talents:SetRosterModifierOverride(
                                selfButton.guid,
                                selfButton.spellID,
                                selfButton.specID,
                                state
                            )
                            addon:Refresh()
                            addon.config:RefreshRosterOverrides()
                        end
                    )
                    row.buttons[optionIndex] = button
                end

                button.guid = entry.guid
                button.spellID = option.spellID
                button.specID = option.specID
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", row, "TOPLEFT", 10 + ((optionIndex - 1) * (buttonWidth + buttonGap)), -32)
                button:SetWidth(buttonWidth)
                button:SetLabel(string.format("%s %s", AbbreviateSpellName(option.spellName), BuildModifierSummary(option, true)))
                button:SetState(addon.talents:GetRosterModifierOverride(entry.guid, option.spellID, option.specID))
                button:Show()
            end
        end

        offsetY = offsetY - rowHeight - 8
    end

    for index = #entries + 1, #self.rosterRows do
        self.rosterRows[index]:Hide()
    end

    local contentHeight = math.max((#entries * (rowHeight + 8)) + 16, self.rosterScroll and self.rosterScroll:GetHeight() or 1)
    self.rosterContent:SetHeight(contentHeight)

    if self.rosterEmptyLabel then
        self.rosterEmptyLabel:SetShown(#entries == 0)
    end
end

function addon.config:InitLayoutDropdown()
    UIDropDownMenu_Initialize(self.layoutDropdown, function(_, level)
        local current = addon:GetConfig("layout") or "HORIZONTAL"

        for _, layout in ipairs(LAYOUT_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = layout
            info.checked = (layout == current)
            info.func = function()
                addon:SetConfig("layout", layout)
                addon.config:RefreshControls()
                addon:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function addon.config:InitGrowDropdown()
    UIDropDownMenu_Initialize(self.growDropdown, function(_, level)
        local current = addon:GetConfig("grow") or "RIGHT"

        for _, grow in ipairs(GROW_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = grow
            info.checked = (grow == current)
            info.func = function()
                addon:SetConfig("grow", grow)
                addon.config:RefreshControls()
                addon:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function addon.config:InitAnchorDropdown()
    UIDropDownMenu_Initialize(self.nameAnchorDropdown, function(_, level)
        local current = (addon:GetConfig("nameText") or {}).anchor or "BOTTOMLEFT"

        for _, anchor in ipairs(NAME_ANCHORS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = anchor
            info.checked = (anchor == current)
            info.func = function()
                local nameText = addon:GetConfig("nameText") or {}
                nameText.anchor = anchor
                addon:SetConfig("nameText", nameText)
                addon.config:RefreshControls()
                addon:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function addon.config:CreateGeneralPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local stateSection = CreateSection(page, "State", 0, 0, 384, 72)
    self.generalStateSection = stateSection
    self.testModeButton = CreateToggleButton(
        stateSection,
        "Test Mode",
        150,
        26,
        12,
        -38,
        addon:GetConfig("testMode"),
        function(value)
            addon:SetConfig("testMode", value)
            if not value then
                addon.state.testData = nil
            end
            addon:Refresh()
        end
    )

    self.lockedButton = CreateToggleButton(
        stateSection,
        "Lock Frame",
        150,
        26,
        174,
        -38,
        addon:GetConfig("locked"),
        function(value)
            addon:SetConfig("locked", value)
            addon:Refresh()
        end
    )

    local layoutSection = CreateSection(page, "Grow Direction", 0, -84, 384, 74)
    self.generalLayoutSection = layoutSection
    local growLabel = layoutSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    growLabel:SetPoint("TOPLEFT", 12, -40)
    growLabel:SetText("Direction")

    self.growDropdown = CreateDropdown(layoutSection, 140)
    self.growDropdown:SetPoint("TOPLEFT", growLabel, "TOPRIGHT", 20, 10)

    local sizingSection = CreateSection(page, "Sizing", 0, -170, 384, 142)
    self.generalSizingSection = sizingSection

    local iconSizeLabel = sizingSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    iconSizeLabel:SetPoint("TOPLEFT", 12, -40)
    iconSizeLabel:SetText("Icon Size")

    self.iconSizeSlider = CreateFrame("Slider", "TankExternalsIconSizeSlider", sizingSection, "OptionsSliderTemplate")
    self.iconSizeSlider:SetPoint("TOPLEFT", 12, -60)
    self.iconSizeSlider:SetWidth(220)
    self.iconSizeSlider:SetMinMaxValues(24, 80)
    self.iconSizeSlider:SetValueStep(1)
    self.iconSizeSlider:SetObeyStepOnDrag(true)

    _G[self.iconSizeSlider:GetName() .. "Low"]:SetText("24")
    _G[self.iconSizeSlider:GetName() .. "High"]:SetText("80")
    _G[self.iconSizeSlider:GetName() .. "Text"]:SetText("")

    self.iconSizeValue = sizingSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.iconSizeValue:SetPoint("LEFT", self.iconSizeSlider, "RIGHT", 12, 0)

    self.iconSizeSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        addon:SetConfig("iconSize", value)
        self.iconSizeValue:SetText(tostring(value))
        addon:Refresh()
    end)

    local spacingLabel = sizingSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    spacingLabel:SetPoint("TOPLEFT", 12, -92)
    spacingLabel:SetText("Spacing")

    self.spacingSlider = CreateFrame("Slider", "TankExternalsSpacingSlider", sizingSection, "OptionsSliderTemplate")
    self.spacingSlider:SetPoint("TOPLEFT", 12, -112)
    self.spacingSlider:SetWidth(220)
    self.spacingSlider:SetMinMaxValues(0, 20)
    self.spacingSlider:SetValueStep(1)
    self.spacingSlider:SetObeyStepOnDrag(true)

    _G[self.spacingSlider:GetName() .. "Low"]:SetText("0")
    _G[self.spacingSlider:GetName() .. "High"]:SetText("20")
    _G[self.spacingSlider:GetName() .. "Text"]:SetText("")

    self.spacingValue = sizingSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.spacingValue:SetPoint("LEFT", self.spacingSlider, "RIGHT", 12, 0)

    self.spacingSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        addon:SetConfig("spacing", value)
        self.spacingValue:SetText(tostring(value))
        addon:Refresh()
    end)

    self.generalPage = page
end

function addon.config:CreateTextPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    self.visibilitySection = CreateSection(page, "Visibility", 0, 0, 384, 72)
    self.enableName = CreateCheckbox(
        self.visibilitySection,
        "Enable Owner Name",
        12,
        -38,
        (addon:GetConfig("nameText") or {}).enabled ~= false,
        function(value)
            local nameText = addon:GetConfig("nameText") or {}
            nameText.enabled = value
            addon:SetConfig("nameText", nameText)
            addon.config:RefreshControls()
            addon:Refresh()
        end
    )

    self.positionSection = CreateSection(page, "Position", 0, -76, 384, 92)

    self.nameAnchorLabel = self.positionSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.nameAnchorLabel:SetPoint("TOPLEFT", 12, -40)
    self.nameAnchorLabel:SetText("Anchor")

    self.nameAnchorDropdown = CreateDropdown(self.positionSection, 140)
    self.nameAnchorDropdown:SetPoint("TOPLEFT", self.nameAnchorLabel, "TOPRIGHT", 20, 10)

    self.nameXLabel = self.positionSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.nameXLabel:SetPoint("TOPLEFT", 12, -70)
    self.nameXLabel:SetText("X Offset")

    self.nameXBox = CreateNumberEditBox(self.positionSection, 60, 22, 110, -64, function(selfBox)
        local value = tonumber(selfBox:GetText())
        if not value then
            local current = ((addon:GetConfig("nameText") or {}).x or 0)
            selfBox:SetText(tostring(current))
            return
        end

        value = math.floor(value)
        if value < -200 then value = -200 end
        if value > 200 then value = 200 end

        local nameText = addon:GetConfig("nameText") or {}
        nameText.x = value
        addon:SetConfig("nameText", nameText)
        selfBox:SetText(tostring(value))
        addon:Refresh()
    end)

    self.nameYLabel = self.positionSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.nameYLabel:SetPoint("TOPLEFT", 200, -70)
    self.nameYLabel:SetText("Y Offset")

    self.nameYBox = CreateNumberEditBox(self.positionSection, 60, 22, 292, -64, function(selfBox)
        local value = tonumber(selfBox:GetText())
        if not value then
            local current = ((addon:GetConfig("nameText") or {}).y or 0)
            selfBox:SetText(tostring(current))
            return
        end

        value = math.floor(value)
        if value < -200 then value = -200 end
        if value > 200 then value = 200 end

        local nameText = addon:GetConfig("nameText") or {}
        nameText.y = value
        addon:SetConfig("nameText", nameText)
        selfBox:SetText(tostring(value))
        addon:Refresh()
    end)

    self.contentSection = CreateSection(page, "Content", 0, -180, 384, 64)

    self.truncateLabel = self.contentSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.truncateLabel:SetPoint("TOPLEFT", 12, -40)
    self.truncateLabel:SetText("Character Limit")

    self.nameTruncateBox = CreateNumberEditBox(self.contentSection, 60, 22, 122, -34, function(selfBox)
        local value = tonumber(selfBox:GetText())
        if not value then
            local current = ((addon:GetConfig("nameText") or {}).truncate or 0)
            selfBox:SetText(tostring(current))
            return
        end

        value = math.floor(value)
        if value < 0 then value = 0 end
        if value > 50 then value = 50 end

        local nameText = addon:GetConfig("nameText") or {}
        nameText.truncate = value
        addon:SetConfig("nameText", nameText)
        selfBox:SetText(tostring(value))
        addon:Refresh()
    end)

    self.typographySection = CreateSection(page, "Typography", 0, -256, 384, 64)

    self.fontSizeLabel = self.typographySection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.fontSizeLabel:SetPoint("TOPLEFT", 12, -40)
    self.fontSizeLabel:SetText("Font Size")

    self.nameFontSizeBox = CreateNumberEditBox(self.typographySection, 60, 22, 122, -34, function(selfBox)
        local value = tonumber(selfBox:GetText())
        if not value then
            local current = ((addon:GetConfig("nameText") or {}).fontSize or 10)
            selfBox:SetText(tostring(current))
            return
        end

        value = math.floor(value)
        if value < 6 then value = 6 end
        if value > 32 then value = 32 end

        local nameText = addon:GetConfig("nameText") or {}
        nameText.fontSize = value
        addon:SetConfig("nameText", nameText)
        selfBox:SetText(tostring(value))
        addon:Refresh()
    end)

    self.textPage = page
end

function addon.config:CreateSpellsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local trackedSection = CreateSection(page, "Tracked Spells", 0, 0, 384, 198)
    self.spellsTrackedSection = trackedSection
    local trackedScroll = CreateFrame("ScrollFrame", nil, trackedSection, "UIPanelScrollFrameTemplate")
    trackedScroll:SetPoint("TOPLEFT", 8, -34)
    trackedScroll:SetPoint("BOTTOMRIGHT", -30, 8)

    local trackedContent = CreateFrame("Frame", nil, trackedScroll)
    trackedContent:SetSize(348, 1)
    trackedScroll:SetScrollChild(trackedContent)
    self.spellsTrackedScroll = trackedScroll
    self.spellsTrackedContent = trackedContent

    local defaultsSection = CreateSection(page, "Default Cooldown Reductions", 0, -210, 384, 110)
    self.spellsDefaultsSection = defaultsSection
    local defaultsScroll = CreateFrame("ScrollFrame", nil, defaultsSection, "UIPanelScrollFrameTemplate")
    defaultsScroll:SetPoint("TOPLEFT", 8, -34)
    defaultsScroll:SetPoint("BOTTOMRIGHT", -30, 8)

    local defaultsContent = CreateFrame("Frame", nil, defaultsScroll)
    defaultsContent:SetSize(348, 1)
    defaultsScroll:SetScrollChild(defaultsContent)
    self.spellsDefaultsScroll = defaultsScroll
    self.spellsDefaultsContent = defaultsContent

    self.spellRows = {}
    self.defaultModifierChecks = {}

    local y = 0
    for _, entry in ipairs(addon:GetSpellList()) do
        local spellID = entry.spellID
        local info = entry.info

        local row = CreateFrame("Frame", nil, trackedContent)
        row:SetPoint("TOPLEFT", 12, y)
        row:SetSize(350, 24)

        row.iconFrame = CreateFrame("Frame", nil, row)
        row.iconFrame:SetSize(18, 18)
        row.iconFrame:SetPoint("LEFT", 0, 0)
        row.iconFrame:EnableMouse(true)

        row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
        row.icon:SetAllPoints()
        row.icon:SetTexture(C_Spell.GetSpellTexture(spellID))

        local function ShowSpellTooltip(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(spellID)
            else
                GameTooltip:SetHyperlink("spell:" .. spellID)
            end
            GameTooltip:Show()
        end

        local function HideSpellTooltip()
            GameTooltip:Hide()
        end

        row.iconFrame:SetScript("OnEnter", ShowSpellTooltip)
        row.iconFrame:SetScript("OnLeave", HideSpellTooltip)

        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.iconFrame, "RIGHT", 8, 0)
        row.label:SetText(info.name)

        row.enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.enabled:SetPoint("RIGHT", 0, 0)
        row.enabled:SetChecked(addon:IsSpellEnabled(spellID))
        row.enabled:SetScript("OnClick", function(btn)
            local filters = addon:GetConfig("spellFilters") or {}
            filters.enabled = filters.enabled or {}
            filters.enabled[spellID] = btn:GetChecked() and true or false
            addon:SetConfig("spellFilters", filters)
            addon.config:RefreshControls()
            if addon.roster and addon.roster.Scan then
                addon.roster:Scan()
            end
            addon:Refresh()
        end)

        row.specChecks = nil
        self.spellRows[spellID] = row

        if info.allowSpecFilter and info.specs then
            y = y - 20
            row.specChecks = {}

            local specIDs = {}
            for specID in pairs(info.specs) do
                table.insert(specIDs, specID)
            end
            table.sort(specIDs)

            local specX = 30
            for _, specID in ipairs(specIDs) do
                local specName = info.specs[specID]

                local specCheck = CreateFrame("CheckButton", nil, trackedContent, "UICheckButtonTemplate")
                specCheck:SetPoint("TOPLEFT", specX, y)
                specCheck:SetChecked(addon:IsSpellSpecAllowed(spellID, specID))
                specCheck:SetScript("OnClick", function(btn)
                    local filters = addon:GetConfig("spellFilters") or {}
                    filters.specFilter = filters.specFilter or {}
                    filters.specFilter[spellID] = filters.specFilter[spellID] or {}
                    filters.specFilter[spellID][specID] = btn:GetChecked() and true or false
                    addon:SetConfig("spellFilters", filters)
                    addon.config:RefreshControls()
                    if addon.roster and addon.roster.Scan then
                        addon.roster:Scan()
                    end
                    addon:Refresh()
                end)

                local specLabel = specCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                specLabel:SetPoint("LEFT", specCheck, "RIGHT", 2, 0)
                specLabel:SetText(specName)

                row.specChecks[specID] = specCheck
                specX = specX + 110
            end
        end

        y = y - 30
    end

    trackedContent:SetHeight(math.max((-y) + 8, 1))

    local defaultY = -10
    for index, option in ipairs(BuildDefaultModifierEntries()) do
        local row = CreateFrame("Frame", nil, defaultsContent)
        row:SetPoint("TOPLEFT", 6, defaultY)
        row:SetPoint("TOPRIGHT", -6, defaultY)
        row:SetHeight(22)

        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", 0, 0)
        row.label:SetText(string.format("%s (%s, %s)", option.spellName, AbbreviateSpecName(option.specName), BuildModifierSummary(option)))

        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetPoint("RIGHT", 0, 0)
        check.spellID = option.spellID
        check.specID = option.specID
        check:SetChecked(addon.talents:GetDefaultModifierEnabled(option.spellID, option.specID))
        check:SetScript("OnClick", function(selfButton)
            addon.talents:SetDefaultModifierEnabled(
                selfButton.spellID,
                selfButton.specID,
                selfButton:GetChecked() and true or false
            )
            addon:Refresh()
            addon.config:RefreshControls()
        end)

        self.defaultModifierChecks[index] = check
        defaultY = defaultY - 24
    end

    defaultsContent:SetHeight(math.max((-defaultY) + 8, 1))

    self.spellsPage = page
end

function addon.config:CreateRosterPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local section = CreateSection(page, "Roster Overrides", 0, 0, 384, 320)
    self.rosterSection = section

    local description = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", 12, -40)
    description:SetPoint("TOPRIGHT", -12, -40)
    description:SetJustifyH("LEFT")
    description:SetText("Cycle each entry between Default, ON, and OFF. Defaults come from the Spells tab.")

    local scroll = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -62)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(348, 1)
    scroll:SetScrollChild(content)

    local emptyLabel = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyLabel:SetPoint("TOPLEFT", 10, -12)
    emptyLabel:SetText("No active roster entries found.")
    emptyLabel:Hide()

    self.rosterScroll = scroll
    self.rosterContent = content
    self.rosterEmptyLabel = emptyLabel
    self.rosterPage = page
end

function addon.config:CreateWindow()
    local f = CreateFrame("Frame", "TankExternalsConfigWindow", UIParent, "BackdropTemplate")
    local sizeConfig = addon:GetConfig("configWindow") or {}
    local initialWidth, initialHeight = GetClampedWindowSize(sizeConfig.width or 520, sizeConfig.height or 640)
    f:SetSize(initialWidth, initialHeight)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(420, 410, 900, 900)
    end

    ApplyPanelBackdrop(f, 0.97)

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(42)
    header:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
    })
    header:SetBackdropColor(0.09, 0.09, 0.12, 1)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", 14, 0)
    title:SetText(string.format("%s - v%s", addon.name or "Tank Externals", addon.version or "DEV"))

    local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    self.refreshRosterButton = CreateFrame("Button", nil, f, "BackdropTemplate")
    self.refreshRosterButton:SetSize(80, 22)
    self.refreshRosterButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -8, -2)
    self.refreshRosterButton.text = self.refreshRosterButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.refreshRosterButton.text:SetPoint("CENTER")
    self.refreshRosterButton.text:SetText("Refresh")
    self.refreshRosterButton:SetScript("OnClick", function()
        if addon.roster and addon.roster.Scan then
            addon.roster:Scan()
        end
        if addon.combatObserver and addon.combatObserver.RefreshWatches then
            addon.combatObserver:RefreshWatches()
        end
        if addon.combat and addon.combat.Reset then
            addon.combat:Reset()
        end
        addon.config:RefreshControls()
        addon:Refresh()
    end)
    StyleFlatButton(self.refreshRosterButton, false)
    self.refreshRosterButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.14, 0.14, 0.18, 1)
    end)
    self.refreshRosterButton:SetScript("OnLeave", function(self)
        StyleFlatButton(self, false)
    end)

    self.generalTab = CreateTabButton(f, "General", 90, 24, 14, -52, function()
        addon.config:ShowTab("GENERAL")
    end)

    self.textTab = CreateTabButton(f, "Text", 90, 24, 110, -52, function()
        addon.config:ShowTab("TEXT")
    end)

    self.spellsTab = CreateTabButton(f, "Spells", 90, 24, 206, -52, function()
        addon.config:ShowTab("SPELLS")
    end)

    self.rosterTab = CreateTabButton(f, "Roster", 90, 24, 302, -52, function()
        addon.config:ShowTab("ROSTER")
    end)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 18, -84)
    content:SetPoint("BOTTOMRIGHT", -18, 16)
    self.content = content

    local resizeButton = CreateFrame("Button", nil, f, "BackdropTemplate")
    resizeButton:SetSize(12, 12)
    resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeButton:EnableMouse(true)
    resizeButton:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    resizeButton:SetBackdropColor(0.10, 0.10, 0.13, 0.95)
    resizeButton:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)

    local gripLine1 = resizeButton:CreateTexture(nil, "ARTWORK")
    gripLine1:SetColorTexture(0.75, 0.75, 0.80, 0.75)
    gripLine1:SetSize(6, 1)
    gripLine1:SetPoint("BOTTOMRIGHT", -2, 3)
    -- gripLine1:SetRotation(0.75)

    local gripLine2 = resizeButton:CreateTexture(nil, "ARTWORK")
    gripLine2:SetColorTexture(0.75, 0.75, 0.80, 0.55)
    gripLine2:SetSize(6, 1)
    gripLine2:SetPoint("BOTTOMRIGHT", 0, 6)
    gripLine2:SetRotation(-1.2)

    resizeButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.14, 0.14, 0.18, 1)
    end)
    resizeButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.10, 0.10, 0.13, 0.95)
    end)
    resizeButton:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        addon.config:SaveWindowSize()
    end)
    self.resizeButton = resizeButton

    f:SetScript("OnSizeChanged", function(_, width, height)
        if width and height then
            local clampedWidth, clampedHeight = GetClampedWindowSize(width, height)
            if width ~= clampedWidth or height ~= clampedHeight then
                f:SetSize(clampedWidth, clampedHeight)
                return
            end

            addon.config:ApplyResponsiveLayout()
            addon.config:SaveWindowSize()
        end
    end)

    self:CreateGeneralPage(content)
    self:CreateTextPage(content)
    self:CreateSpellsPage(content)
    self:CreateRosterPage(content)

    self.window = f

    self:InitGrowDropdown()
    self:InitAnchorDropdown()
    self:ApplyResponsiveLayout()
    self:ShowTab("GENERAL")
    self:RefreshControls()
end

function addon.config:ToggleWindow()
    if not self.window then
        self:CreateWindow()
    end

    if self.window:IsShown() then
        self.window:Hide()
    else
        self:RefreshControls()
        self.window:Show()
    end
end

function addon.config:Init()
    self:CreateWindow()
end
