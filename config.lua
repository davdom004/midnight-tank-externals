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

local LAYOUT_OPTIONS = {
    "HORIZONTAL",
    "VERTICAL",
}

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

    if self.generalTab and self.textTab and self.spellsTab then
        StyleFlatButton(self.generalTab, tabName == "GENERAL")
        StyleFlatButton(self.textTab, tabName == "TEXT")
        StyleFlatButton(self.spellsTab, tabName == "SPELLS")
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
    if not self.spellRows then
        return
    end

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

function addon.config:RefreshControls()
    if not self.window then
        return
    end

    self.testModeButton:SetState(addon:GetConfig("testMode"))
    self.lockedButton:SetState(addon:GetConfig("locked"))

    local iconSize = addon:GetConfig("iconSize")
    self.iconSizeSlider:SetValue(iconSize)
    self.iconSizeValue:SetText(tostring(iconSize))

    local spacing = addon:GetConfig("spacing") or 0
    self.spacingSlider:SetValue(spacing)
    self.spacingValue:SetText(tostring(spacing))

    UIDropDownMenu_SetText(self.layoutDropdown, addon:GetConfig("layout") or "HORIZONTAL")

    local nameText = addon:GetConfig("nameText") or {}
    self.enableName:SetChecked(nameText.enabled ~= false)
    UIDropDownMenu_SetText(self.nameAnchorDropdown, nameText.anchor or "BOTTOMLEFT")
    self.nameXBox:SetText(tostring(nameText.x or 0))
    self.nameYBox:SetText(tostring(nameText.y or 0))
    self.nameTruncateBox:SetText(tostring(nameText.truncate or 0))
    self.nameFontSizeBox:SetText(tostring(nameText.fontSize or 10))

    self:RefreshOwnerNameVisibility()
    self:RefreshSpellControls()
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

    local layoutSection = CreateSection(page, "Layout", 0, -84, 384, 74)
    local layoutLabel = layoutSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    layoutLabel:SetPoint("TOPLEFT", 12, -40)
    layoutLabel:SetText("Direction")

    self.layoutDropdown = CreateDropdown(layoutSection, 140)
    self.layoutDropdown:SetPoint("TOPLEFT", layoutLabel, "TOPRIGHT", 20, 10)

    local sizingSection = CreateSection(page, "Sizing", 0, -170, 384, 142)

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

    local section = CreateSection(page, "Tracked Spells", 0, 0, 384, 320)

    self.spellRows = {}

    local y = -42
    for _, entry in ipairs(addon:GetSpellList()) do
        local spellID = entry.spellID
        local info = entry.info

        local row = CreateFrame("Frame", nil, section)
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

                local specCheck = CreateFrame("CheckButton", nil, section, "UICheckButtonTemplate")
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

    self.spellsPage = page
end

function addon.config:CreateWindow()
    local f = CreateFrame("Frame", "TankExternalsConfigWindow", UIParent, "BackdropTemplate")
    f:SetSize(420, 410)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()

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

    self.generalTab = CreateTabButton(f, "General", 90, 24, 14, -52, function()
        addon.config:ShowTab("GENERAL")
    end)

    self.textTab = CreateTabButton(f, "Text", 90, 24, 110, -52, function()
        addon.config:ShowTab("TEXT")
    end)

    self.spellsTab = CreateTabButton(f, "Spells", 90, 24, 206, -52, function()
        addon.config:ShowTab("SPELLS")
    end)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 18, -84)
    content:SetPoint("BOTTOMRIGHT", -18, 16)

    self:CreateGeneralPage(content)
    self:CreateTextPage(content)
    self:CreateSpellsPage(content)

    self.window = f

    self:InitLayoutDropdown()
    self:InitAnchorDropdown()
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
