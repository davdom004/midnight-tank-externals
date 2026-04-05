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

local function CreateRadio(parent, label, x, y, onClick)
    local button = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    button.text:SetPoint("LEFT", button, "RIGHT", 4, 0)
    button.text:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
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
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    button.label = label
    button.isOn = initialValue and true or false

    local function Refresh()
        if button.isOn then
            button:SetText(label .. ": ON")
        else
            button:SetText(label .. ": OFF")
        end
    end

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
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function addon.config:ShowTab(tabName)
    self.activeTab = tabName

    if self.generalPage then
        if tabName == "GENERAL" then
            self.generalPage:Show()
        else
            self.generalPage:Hide()
        end
    end

    if self.textPage then
        if tabName == "TEXT" then
            self.textPage:Show()
        else
            self.textPage:Hide()
        end
    end
end

function addon.config:RefreshOwnerNameVisibility()
    if not self.textPage then
        return
    end

    local enabled = ((addon:GetConfig("nameText") or {}).enabled ~= false)

    local controls = {
        self.nameAnchorLabel,
        self.nameAnchorDropdown,
        self.nameXLabel,
        self.nameXBox,
        self.nameYLabel,
        self.nameYBox,
        self.truncateLabel,
        self.nameTruncateBox,
        self.fontSizeLabel,
        self.nameFontSizeBox,
    }

    for _, control in ipairs(controls) do
        if control then
            if enabled then
                control:Show()
            else
                control:Hide()
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

    self.testModeButton = CreateToggleButton(
        page,
        "Test Mode",
        140,
        24,
        16,
        -16,
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
        page,
        "Lock Frame",
        140,
        24,
        170,
        -16,
        addon:GetConfig("locked"),
        function(value)
            addon:SetConfig("locked", value)
            addon:Refresh()
        end
    )

    local layoutLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    layoutLabel:SetPoint("TOPLEFT", 16, -58)
    layoutLabel:SetText("Layout")

    self.layoutDropdown = CreateDropdown(page, 140)
    self.layoutDropdown:SetPoint("TOPLEFT", layoutLabel, "TOPRIGHT", 20, 10)

    local iconSizeLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    iconSizeLabel:SetPoint("TOPLEFT", 16, -106)
    iconSizeLabel:SetText("Icon Size")

    self.iconSizeSlider = CreateFrame("Slider", "TankExternalsIconSizeSlider", page, "OptionsSliderTemplate")
    self.iconSizeSlider:SetPoint("TOPLEFT", 16, -126)
    self.iconSizeSlider:SetWidth(220)
    self.iconSizeSlider:SetMinMaxValues(24, 80)
    self.iconSizeSlider:SetValueStep(1)
    self.iconSizeSlider:SetObeyStepOnDrag(true)

    _G[self.iconSizeSlider:GetName() .. "Low"]:SetText("24")
    _G[self.iconSizeSlider:GetName() .. "High"]:SetText("80")
    _G[self.iconSizeSlider:GetName() .. "Text"]:SetText("")

    self.iconSizeValue = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.iconSizeValue:SetPoint("LEFT", self.iconSizeSlider, "RIGHT", 12, 0)

    self.iconSizeSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        addon:SetConfig("iconSize", value)
        self.iconSizeValue:SetText(tostring(value))
        addon:Refresh()
    end)

    local spacingLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spacingLabel:SetPoint("TOPLEFT", 16, -172)
    spacingLabel:SetText("Spacing")

    self.spacingSlider = CreateFrame("Slider", "TankExternalsSpacingSlider", page, "OptionsSliderTemplate")
    self.spacingSlider:SetPoint("TOPLEFT", 16, -192)
    self.spacingSlider:SetWidth(220)
    self.spacingSlider:SetMinMaxValues(0, 20)
    self.spacingSlider:SetValueStep(1)
    self.spacingSlider:SetObeyStepOnDrag(true)

    _G[self.spacingSlider:GetName() .. "Low"]:SetText("0")
    _G[self.spacingSlider:GetName() .. "High"]:SetText("20")
    _G[self.spacingSlider:GetName() .. "Text"]:SetText("")

    self.spacingValue = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
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

    self.enableName = CreateCheckbox(
        page,
        "Enable Owner Name",
        16,
        -16,
        (addon:GetConfig("nameText") or {}).enabled ~= false,
        function(value)
            local nameText = addon:GetConfig("nameText") or {}
            nameText.enabled = value
            addon:SetConfig("nameText", nameText)
            addon.config:RefreshControls()
            addon:Refresh()
        end
    )

    self.nameAnchorLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.nameAnchorLabel:SetPoint("TOPLEFT", 16, -52)
    self.nameAnchorLabel:SetText("Anchor")

    self.nameAnchorDropdown = CreateDropdown(page, 140)
    self.nameAnchorDropdown:SetPoint("TOPLEFT", self.nameAnchorLabel, "TOPRIGHT", 20, 10)

    self.nameXLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.nameXLabel:SetPoint("TOPLEFT", 16, -96)
    self.nameXLabel:SetText("X Offset")

    self.nameXBox = CreateNumberEditBox(page, 60, 22, 120, -90, function(selfBox)
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

    self.nameYLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.nameYLabel:SetPoint("TOPLEFT", 16, -130)
    self.nameYLabel:SetText("Y Offset")

    self.nameYBox = CreateNumberEditBox(page, 60, 22, 120, -124, function(selfBox)
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

    self.truncateLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.truncateLabel:SetPoint("TOPLEFT", 16, -164)
    self.truncateLabel:SetText("Character Limit")

    self.nameTruncateBox = CreateNumberEditBox(page, 60, 22, 120, -158, function(selfBox)
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

    self.fontSizeLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.fontSizeLabel:SetPoint("TOPLEFT", 16, -198)
    self.fontSizeLabel:SetText("Font Size")

    self.nameFontSizeBox = CreateNumberEditBox(page, 60, 22, 120, -192, function(selfBox)
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

function addon.config:CreateWindow()
    local f = CreateFrame("Frame", "TankExternalsConfigWindow", UIParent, "BackdropTemplate")
    f:SetSize(420, 360)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.95)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(string.format("%s - %s", addon.name or "Tank Externals", addon.version or "DEV"))

    local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    local subtitle = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("/te to open or close")

    self.generalTab = CreateTabButton(f, "General", 90, 22, 16, -46, function()
        addon.config:ShowTab("GENERAL")
    end)

    self.textTab = CreateTabButton(f, "Text", 90, 22, 112, -46, function()
        addon.config:ShowTab("TEXT")
    end)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 12, -76)
    content:SetPoint("BOTTOMRIGHT", -12, 12)

    self:CreateGeneralPage(content)
    self:CreateTextPage(content)

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
