local addonName, ns = ...

local controller = ns.Controller
local panel
local statusFields = {}
local sliders = {}
local refreshTicker
local UpdateStatus

local COLORS = {
    wood = { 0.13, 0.075, 0.035, 0.98 },
    woodLight = { 0.24, 0.13, 0.055, 1 },
    gold = { 0.86, 0.68, 0.30, 1 },
    goldSoft = { 0.69, 0.49, 0.20, 1 },
    ink = { 0.20, 0.12, 0.07, 1 },
    paper = { 0.90, 0.82, 0.64, 1 },
}

local MOOD_LABELS = {
    pastoral = "Pastoral",
    verdant = "Forest",
    civilized = "City",
    haunted = "Haunted",
    wild = "Wilds",
    arid = "Arid",
    snow = "Snow",
    cave = "Caves",
    sacred = "Sacred",
    battle = "Battle",
    epilogueBad = "Epilogue — Bad",
    epilogueGood = "Epilogue — Good",
}

local function FormatNumber(value, decimals)
    return string.format("%." .. tostring(decimals) .. "f", tonumber(value) or 0)
end

local function FormatSliderValue(key, value, decimals)
    if key == "volume" then
        return string.format("%d%%", math.floor(((tonumber(value) or 0) * 100) + 0.5))
    end
    local text = FormatNumber(value, decimals)
    if key == "fadeOut" or key == "fadeIn" or key == "zoneDelay" then return text .. " s" end
    if key == "silenceMinutes" then return text .. " min" end
    return text
end

local function StyleText(text, color)
    text:SetTextColor(color[1], color[2], color[3], color[4])
end

local function PlayUISound()
    local soundKit = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    if soundKit and PlaySound then
        PlaySound(soundKit, "SFX")
    end
end

local function FormatTrackName(trackID)
    if not trackID then return "Waiting for a track" end
    return (trackID:gsub("(%l)(%u)", "%1 %2"))
end

local function FormatMoodName(mood)
    return MOOD_LABELS[mood] or tostring(mood or "Unknown")
end

local function SetStatusText(fontString, text, color)
    fontString:SetText(text)
    StyleText(fontString, color)
end

local function CreateLabel(parent, template, text, color, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", template)
    label:SetText(text)
    StyleText(label, color)
    label:SetPoint(point, relativeTo, relativePoint, x, y)
    return label
end

local function CreateSectionTitle(text, y)
    local label = CreateLabel(panel, "GameFontNormal", text, COLORS.goldSoft,
        "TOPLEFT", panel, "TOPLEFT", 38, y)
    label:SetFont(label:GetFont(), 15, "OUTLINE")
    local ruleOutline = panel:CreateTexture(nil, "BORDER")
    ruleOutline:SetColorTexture(0.035, 0.022, 0.012, 0.95)
    ruleOutline:SetPoint("LEFT", label, "RIGHT", 11, 0)
    ruleOutline:SetPoint("RIGHT", panel, "RIGHT", -37, 0)
    ruleOutline:SetHeight(6)

    local rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(COLORS.goldSoft[1], COLORS.goldSoft[2], COLORS.goldSoft[3], 0.7)
    rule:SetPoint("LEFT", label, "RIGHT", 12, 0)
    rule:SetPoint("RIGHT", panel, "RIGHT", -38, 0)
    rule:SetHeight(4)
end

local function CreateCheckbox(labelText, settingKey, y, setter)
    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(25, 25)
    checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 31, y)
    checkbox:SetHitRectInsets(0, -250, 0, 0)
    local function ApplySetting()
        setter(not not checkbox:GetChecked())
        local settings = controller.GetSettings()
        checkbox:SetChecked(settings[settingKey])
        UpdateStatus()
        PlayUISound()
    end
    checkbox:SetScript("OnClick", ApplySetting)

    local label = CreateLabel(panel, "GameFontNormal", labelText, COLORS.ink,
        "LEFT", checkbox, "RIGHT", 3, 1)
    label:SetFont(label:GetFont(), 14, "")
    return checkbox
end

local function CreateSlider(key, labelText, minValue, maxValue, step, decimals, y, setter)
    local label = CreateLabel(panel, "GameFontNormal", labelText, COLORS.ink,
        "TOPLEFT", panel, "TOPLEFT", 39, y)
    label:SetFont(label:GetFont(), 13, "")

    local valueBadge = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    valueBadge:SetSize(92, 26)
    valueBadge:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -39, y + 5)
    valueBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    valueBadge:SetBackdropColor(COLORS.wood[1], COLORS.wood[2], COLORS.wood[3], 0.98)
    valueBadge:SetBackdropBorderColor(COLORS.goldSoft[1], COLORS.goldSoft[2], COLORS.goldSoft[3], 1)
    local valueText = CreateLabel(valueBadge, "GameFontNormal", "", COLORS.gold,
        "CENTER", valueBadge, "CENTER", 0, 1)
    valueText:SetFont(valueText:GetFont(), 15, "OUTLINE")
    valueText:SetJustifyH("CENTER")

    local slider = CreateFrame("Slider", nil, panel, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 43, y - 19)
    slider:SetSize(492, 24)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetHitRectInsets(0, 0, -12, -12)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    slider:SetBackdropColor(0.22, 0.14, 0.075, 0.9)
    slider:SetBackdropBorderColor(COLORS.goldSoft[1], COLORS.goldSoft[2], COLORS.goldSoft[3], 0.9)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb then
        -- Scale only the thumb texture: the slider's 492x24 track stays put.
        thumb:SetSize(28, 34)
        thumb:SetVertexColor(1, 0.88, 0.62, 1)
    end

    local sliderSoundTimer
    slider:SetScript("OnValueChanged", function(self, value)
        value = tonumber(value) or minValue
        valueText:SetText(FormatSliderValue(key, value, decimals))
        if not self.suppressCallback then
            setter(value)
            if sliderSoundTimer then sliderSoundTimer:Cancel() end
            if C_Timer and C_Timer.NewTimer then
                sliderSoundTimer = C_Timer.NewTimer(0.18, function()
                    sliderSoundTimer = nil
                    PlayUISound()
                end)
            end
        end
    end)

    sliders[key] = {
        slider = slider,
        valueText = valueText,
        decimals = decimals,
        cancelSound = function()
            if sliderSoundTimer then
                sliderSoundTimer:Cancel()
                sliderSoundTimer = nil
            end
        end,
    }
    return slider
end

local function CreateThemedButton(label, width, onClick)
    local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
    local normalColor = { COLORS.wood[1], COLORS.wood[2], COLORS.wood[3], COLORS.wood[4] }
    local normalBorder = { COLORS.goldSoft[1], COLORS.goldSoft[2], COLORS.goldSoft[3], 0.95 }
    button:SetSize(width, 32)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(normalColor[1], normalColor[2], normalColor[3], normalColor[4])
    button:SetBackdropBorderColor(normalBorder[1], normalBorder[2], normalBorder[3], normalBorder[4])

    local clickFlash = button:CreateTexture(nil, "BORDER")
    clickFlash:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    clickFlash:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    clickFlash:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.32)
    clickFlash:SetAlpha(0)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.18)
    button:SetHighlightTexture(highlight)

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("CENTER", button, "CENTER", 0, 1)
    text:SetText(label)
    text:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
    text:SetFont(text:GetFont(), 12, "OUTLINE")
    button.label = text
    button.clickFlash = clickFlash
    button.normalBackdropColor = normalColor
    button.normalBorderColor = normalBorder

    local function SetPressed(pressed)
        button.isPressed = pressed
        button:SetBackdropColor(pressed and 0.07 or normalColor[1],
            pressed and 0.035 or normalColor[2], pressed and 0.015 or normalColor[3], 1)
        text:ClearAllPoints()
        text:SetPoint("CENTER", button, "CENTER", 0, pressed and 0 or 1)
        if pressed then
            text:SetTextColor(1, 0.88, 0.48, 1)
        else
            text:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        end
    end

    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then SetPressed(true) end
    end)
    button:SetScript("OnMouseUp", function() SetPressed(false) end)
    button:SetScript("OnLeave", function()
        if button.isPressed then SetPressed(false) end
    end)
    button:SetScript("OnClick", function(self, ...)
        PlayUISound()
        self.clickFeedbackGeneration = (self.clickFeedbackGeneration or 0) + 1
        local generation = self.clickFeedbackGeneration
        self.clickFlash:SetAlpha(0.32)
        self:SetBackdropColor(0.30, 0.20, 0.08, 1)
        self:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        self.label:SetTextColor(1, 0.92, 0.62, 1)
        onClick(...)
        C_Timer.After(0.22, function()
            if self.clickFeedbackGeneration ~= generation then return end
            self.clickFlash:SetAlpha(0)
            local normal = self.normalBackdropColor
            local border = self.normalBorderColor
            self:SetBackdropColor(normal[1], normal[2], normal[3], normal[4])
            self:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
            self.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        end)
    end)
    return button
end

UpdateStatus = function()
    if not panel or not panel:IsShown() or not statusFields.location then return end
    local status = controller.GetStatus()
    local location = status.zone ~= "" and status.zone or "Unknown area"
    if status.subzone and status.subzone ~= "" and status.subzone ~= status.zone then
        location = location .. "  ·  " .. status.subzone
    end
    local track = status.silent and "Quiet interlude" or FormatTrackName(status.trackID)
    SetStatusText(statusFields.location, location, COLORS.paper)
    if status.enabled then
        SetStatusText(statusFields.summaryLabel, "Mood:", COLORS.gold)
        SetStatusText(statusFields.summary, FormatMoodName(status.mood), COLORS.paper)
        SetStatusText(statusFields.cueLabel, "Currently playing:", COLORS.gold)
        SetStatusText(statusFields.cue, track, COLORS.paper)
    else
        SetStatusText(statusFields.summaryLabel, "Status:", COLORS.gold)
        SetStatusText(statusFields.summary, "Music override is off.", COLORS.paper)
        SetStatusText(statusFields.cueLabel, "", COLORS.gold)
        SetStatusText(statusFields.cue, "", COLORS.paper)
    end
end

local function RefreshControls()
    if not panel then return end
    local settings = controller.GetSettings()
    if panel.enabledCheck then panel.enabledCheck:SetChecked(settings.enabled) end
    if panel.combatCheck then panel.combatCheck:SetChecked(settings.combatMusic) end
    if panel.questWinCheck then panel.questWinCheck:SetChecked(settings.questWinSound) end
    for key, data in pairs(sliders) do
        local value = settings[key]
        if value ~= nil then
            data.slider.suppressCallback = true
            data.slider:SetValue(value)
            data.slider.suppressCallback = false
            data.valueText:SetText(FormatSliderValue(key, value, data.decimals))
        end
    end
    UpdateStatus()
end

ns.RefreshVolumeControl = function()
    if not panel or not panel:IsShown() then return end
    local data = sliders.volume
    local value = controller.GetSettings().volume
    if not data or value == nil then return end
    data.slider.suppressCallback = true
    data.slider:SetValue(value)
    data.slider.suppressCallback = false
    data.valueText:SetText(FormatSliderValue("volume", value, data.decimals))
end

local function BuildPanel()
    panel = CreateFrame("Frame", "FableForeverOptionsFrame", UIParent, "BackdropTemplate")
    panel:SetSize(620, 720)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 28,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    panel:SetBackdropColor(COLORS.paper[1], COLORS.paper[2], COLORS.paper[3], 0.96)
    panel:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)

    local header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 17, -15)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -17, -15)
    header:SetHeight(72)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(COLORS.wood[1], COLORS.wood[2], COLORS.wood[3], 0.97)
    local lowerRule = header:CreateTexture(nil, "ARTWORK")
    lowerRule:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.9)
    lowerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    lowerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    lowerRule:SetHeight(2)

    local title = CreateLabel(header, "GameFontNormalLarge", "Fable Forever", COLORS.gold,
        "TOPLEFT", header, "TOPLEFT", 22, -13)
    title:SetFont(title:GetFont(), 22, "OUTLINE")
    local subtitle = CreateLabel(header, "GameFontHighlightSmall", "A different song for every corner of Azeroth", COLORS.paper,
        "TOPLEFT", header, "TOPLEFT", 24, -43)
    subtitle:SetFont(subtitle:GetFont(), 11, "")

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -1, -2)
    close:SetScript("OnClick", function()
        PlayUISound()
        panel:Hide()
    end)

    panel.enabledCheck = CreateCheckbox("Replace Azeroth's music", "enabled", -103, controller.SetEnabled)
    panel.combatCheck = CreateCheckbox("Use a battle cue while in combat", "combatMusic", -137, controller.SetCombatMusic)
    panel.questWinCheck = CreateCheckbox("Replace WoW's quest-complete sound", "questWinSound", -171, controller.SetQuestWinSound)
    CreateSectionTitle("The music of Albion", -207)

    CreateSlider("volume", "Fable music level", 0, 1, 0.05, 0, -238, controller.SetVolume)
    CreateSlider("fadeOut", "Fade out before changing a cue", 0, 15, 0.5, 1, -299, controller.SetFadeOut)
    CreateSlider("fadeIn", "Fade in after entering an area", 0, 15, 0.5, 1, -360, controller.SetFadeIn)
    CreateSlider("zoneDelay", "Wait for the zone change to settle", 0, 5, 0.1, 1, -421, controller.SetZoneDelay)
    CreateSlider("silenceMinutes", "Quiet time between tracks (minutes)", 0, 10, 0.5, 1, -482, controller.SetSilenceMinutes)

    CreateSectionTitle("Where you are now", -530)
    local statusCard = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    statusCard:SetPoint("TOPLEFT", panel, "TOPLEFT", 37, -550)
    statusCard:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -37, -550)
    statusCard:SetHeight(70)
    statusCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    statusCard:SetBackdropColor(COLORS.wood[1], COLORS.wood[2], COLORS.wood[3], 0.64)
    statusCard:SetBackdropBorderColor(COLORS.goldSoft[1], COLORS.goldSoft[2], COLORS.goldSoft[3], 0.9)

    local statusAccent = statusCard:CreateTexture(nil, "ARTWORK")
    statusAccent:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.95)
    statusAccent:SetPoint("TOPLEFT", statusCard, "TOPLEFT", 8, -10)
    statusAccent:SetPoint("BOTTOMLEFT", statusCard, "BOTTOMLEFT", 8, 10)
    statusAccent:SetWidth(3)

    local function CreateStatusField(text, color)
        local field = statusCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        field:SetFont(field:GetFont(), 13, "")
        field:SetText(text)
        StyleText(field, color)
        field:SetJustifyH("LEFT")
        return field
    end

    statusFields.locationLabel = CreateStatusField("Location:", COLORS.gold)
    statusFields.locationLabel:SetPoint("TOPLEFT", statusCard, "TOPLEFT", 20, -14)
    statusFields.location = CreateStatusField("", COLORS.paper)
    statusFields.location:SetPoint("LEFT", statusFields.locationLabel, "RIGHT", 7, 0)
    statusFields.location:SetPoint("RIGHT", statusCard, "RIGHT", -14, 0)

    statusFields.summaryLabel = CreateStatusField("Mood:", COLORS.gold)
    statusFields.summaryLabel:SetPoint("TOPLEFT", statusCard, "TOPLEFT", 20, -40)
    statusFields.summary = CreateStatusField("", COLORS.paper)
    statusFields.summary:SetPoint("LEFT", statusFields.summaryLabel, "RIGHT", 7, 0)

    statusFields.cueLabel = CreateStatusField("Currently playing:", COLORS.gold)
    statusFields.cueLabel:SetPoint("TOPLEFT", statusCard, "TOPLEFT", 218, -40)
    statusFields.cue = CreateStatusField("", COLORS.paper)
    statusFields.cue:SetPoint("LEFT", statusFields.cueLabel, "RIGHT", 7, 0)
    statusFields.cue:SetPoint("RIGHT", statusCard, "RIGHT", -14, 0)

    local note = CreateLabel(panel, "GameFontDisableSmall", "Local MP3s are read from the Music folder.", COLORS.woodLight,
        "BOTTOM", panel, "BOTTOM", 0, 67)
    note:SetJustifyH("CENTER")

    local nextButton = CreateThemedButton("Next track", 142, function()
        controller.NextTrack()
        C_Timer.After(0.1, RefreshControls)
    end)
    nextButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 65, 25)

    local refreshButton = CreateThemedButton("Refresh zone", 142, function()
        controller.Refresh()
        C_Timer.After(0.2, RefreshControls)
    end)
    refreshButton:SetPoint("LEFT", nextButton, "RIGHT", 18, 0)

    local closeButton = CreateThemedButton("Close", 142, function() panel:Hide() end)
    closeButton:SetPoint("LEFT", refreshButton, "RIGHT", 18, 0)

    panel:SetScript("OnShow", function()
        RefreshControls()
        if C_Timer and C_Timer.NewTicker and not refreshTicker then
            refreshTicker = C_Timer.NewTicker(1, UpdateStatus)
        end
    end)
    panel:SetScript("OnHide", function()
        if refreshTicker then
            refreshTicker:Cancel()
            refreshTicker = nil
        end
        for _, data in pairs(sliders) do
            if data.cancelSound then data.cancelSound() end
        end
    end)

    panel:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, "FableForeverOptionsFrame")
    end
end

function ns.OpenOptions()
    if not panel then BuildPanel() end
    RefreshControls()
    panel:Show()
end
