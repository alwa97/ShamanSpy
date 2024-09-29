ShamanStasiData = ShamanStasiData or {}

local totalCombatTime = 0
local totalGraceOfAirTime = 0
local totalWindfuryTime = 0

local combatStartTime = 0
local graceOfAirStartTime = 0
local graceOfAirIsActive = false
local windfuryStartTime = 0
local windfuryIsActive = false

local frameStart = CreateFrame("Frame")
local frameEnd = CreateFrame("Frame")
local buffFrame = CreateFrame("Frame")

local graceOfAirBigIconFrame
local graceOfAirBigIconTexture
local graceOfAirActiveTime = 0
local showModeEnabled = false

local playersName = UnitName("player")
local st_timer = 0.0
local st_timerOff = 0.0

local prevWepSpeed = nil
local prevOHSpeed = nil

local lastSwingUpdate = GetTime()

local lastUpdateTime = 0
local updateInterval = 0.1

local lastWhisperTime = 0
local whisperInterval = 600

local function IsPlayerInGroup(playerName)
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name == playerName and online then
                return true
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local unitID = "party"..i
            if UnitName(unitID) == playerName and UnitIsConnected(unitID) then
                return true
            end
        end
    end
    return false
end

local function GetSenderGroup()
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name == UnitName("player") then
                return subgroup
            end
        end
    else
        return 1
    end
    return nil
end

local function safePercentage(part, whole)
    if whole and whole > 0 then
        return math.ceil((part / whole) * 100)
    else
        return 0
    end
end

local function SendSimpleWhisperToMaraboom()
    playersName = "Maraboom"
    if IsPlayerInGroup(playersName) then
        local senderGroupNumber = GetSenderGroup()
        if senderGroupNumber then
            local graceOfAirPercentage = safePercentage(totalGraceOfAirTime, totalCombatTime)
            local windfuryPercentage = safePercentage(totalWindfuryTime, totalCombatTime)

            local message = string.format("G%d agi %d%% wf %d%%", senderGroupNumber, graceOfAirPercentage, windfuryPercentage)
            SendChatMessage(message, "WHISPER", nil, playersName)
        end
    end
end
local function IsSwinging()
    return (st_timer > 0 or (st_timerOff > 0 and isDualWield()))
end

local function GetWeaponSpeed(off)
    local speedMH, speedOH = UnitAttackSpeed("player")
    if off then
        return speedOH
    else
        return speedMH
    end
end

local function isDualWield()
    return (GetWeaponSpeed(true) ~= nil)
end

local function ResetTimer(off)
    prevWepSpeed = GetWeaponSpeed(false)
    if isDualWield() then
        prevOHSpeed = GetWeaponSpeed(true)
    end

    if not off then
        st_timer = prevWepSpeed
        if isDualWield() and st_timerOff <= 0 then
            st_timerOff = 0.2
        end
    else
        st_timerOff = prevOHSpeed
        if isDualWield() and st_timer <= 0 then
            st_timer = 0.2
        end
    end

    if not st_timer or st_timer <= 0 then
        st_timer = 0
    end
    if not st_timerOff or st_timerOff <= 0 then
        st_timerOff = 0
    end
end

local swingEventFrame = CreateFrame("Frame")

swingEventFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_COMBAT_SELF_HITS" then
        if (string.find(arg1, "You hit") or string.find(arg1, "You crit") or string.find(arg1, playersName.." hits") or string.find(arg1, playersName.." crits")) then
            local dmgtype = "hit"
            if string.find(arg1, "You crit") or string.find(arg1, playersName.." crits") then
                dmgtype = "crit"
            elseif string.find(arg1, "glancing") then
                dmgtype = "glancing"
            end
            ResetTimer(false) 
        end
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
        if (string.find(arg1, "Your") or string.find(arg1, "miss")) then
            ResetTimer(false) 
        end
    end
end)

swingEventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
swingEventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")

local function DisplayMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ShamanStasi]|r " .. message)
end

local function ResetData()
    ShamanStasiData.totalCombatTime = 0
    ShamanStasiData.totalGraceOfAirTime = 0
    ShamanStasiData.totalWindfuryTime = 0
    ShamanStasiData.showModeEnabled = showModeEnabled
end

local function LoadData()
    totalCombatTime = ShamanStasiData.totalCombatTime or 0
    totalGraceOfAirTime = ShamanStasiData.totalGraceOfAirTime or 0
    totalWindfuryTime = ShamanStasiData.totalWindfuryTime or 0
    showModeEnabled = ShamanStasiData.showModeEnabled or false
end

local function onCombatEnd()
    graceOfAirIsActive = false
    windfuryIsActive = false

    --DisplayMessage("totalCombatTime" .. totalCombatTime)
    --DisplayMessage("totalGraceOfAirTime" .. totalGraceOfAirTime)
    --DisplayMessage("totalWindfuryTime" .. totalWindfuryTime)

    st_timer = 0
    st_timerOff = 0
    combatStartTime = 0
    SaveData()
end

local graceOfAirIcon = "Interface\\Icons\\Spell_Nature_InvisibilityTotem"

local function createGraceOfAirBigIcon()
    graceOfAirBigIconFrame = CreateFrame("Frame", nil, UIParent)
    graceOfAirBigIconFrame:SetHeight(128)
    graceOfAirBigIconFrame:SetWidth(128)
    graceOfAirBigIconFrame:SetPoint("CENTER", UIParent, "CENTER")
    graceOfAirBigIconFrame:Hide()

    graceOfAirBigIconTexture = graceOfAirBigIconFrame:CreateTexture(nil, "ARTWORK")
    graceOfAirBigIconTexture:SetAllPoints()
    graceOfAirBigIconTexture:SetTexture("Interface\\Icons\\Spell_Nature_Windfury")
end

local function checkForGraceOfAirAlways()
    local graceOfAirAlwaysFound = false
    local i = 1
    local buffIcon = UnitBuff("player", i)

    while buffIcon do
        if buffIcon == graceOfAirIcon then
            graceOfAirAlwaysFound = true
            break
        end
        i = i + 1
        buffIcon = UnitBuff("player", i)
    end

    if graceOfAirAlwaysFound then
        graceOfAirActiveTime = graceOfAirActiveTime + 0.1
        if showModeEnabled and graceOfAirActiveTime >= 8 then
            graceOfAirBigIconFrame:Show()
        end
    else
        graceOfAirActiveTime = 0
        graceOfAirBigIconFrame:Hide()
    end
end

local function checkForGraceOfAir()
    if st_timer <= 0 and st_timerOff <= 0 then
        graceOfAirIsActive = false
    end

    local graceOfAirFound = false
    local i = 1
    local buffIcon = UnitBuff("player", i)

    while buffIcon do
        if buffIcon == graceOfAirIcon then
            graceOfAirFound = true
            if not graceOfAirIsActive and IsSwinging() then
                graceOfAirStartTime = GetTime()
                graceOfAirIsActive = true
            end
            break
        end
        i = i + 1
        buffIcon = UnitBuff("player", i)
    end

    if not graceOfAirFound and graceOfAirIsActive then
        graceOfAirIsActive = false
        graceOfAirStartTime = 0
    end
end


local function checkForWindfury()
    if st_timer <= 0 and st_timerOff <= 0 then
        windfuryIsActive = false
    end

    local hasMainHandEnchant, _, _, enchantId = GetWeaponEnchantInfo()
    if hasMainHandEnchant then
        if not windfuryIsActive and IsSwinging() then
            windfuryStartTime = GetTime()
            windfuryIsActive = true
        end
    else
        if windfuryIsActive then
            windfuryIsActive = false
            windfuryStartTime = 0
        end
    end
end

local function onCombatStart()
    if IsSwinging() then
        checkForGraceOfAir()
        checkForWindfury()
        combatStartTime = GetTime()
    end
end


local statsFrame
local statsText

local function CreateStatsFrame()
    local statsFrame = CreateFrame("Frame", "ShamanStasiFrame", UIParent)
   
    statsFrame:SetWidth(180)
    statsFrame:SetHeight(110)
    statsFrame:SetPoint("CENTER", UIParent, "CENTER")
    statsFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    statsFrame:SetBackdropColor(0, 0, 0, 0.6)
    statsFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
   
    statsFrame:SetMovable(true)
    statsFrame:EnableMouse(true)
   
    local header = CreateFrame("Frame", nil, statsFrame)
    header:SetHeight(25)
    header:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", statsFrame, "TOPRIGHT", 0, 0)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() statsFrame:StartMoving() end)
    header:SetScript("OnDragStop", function() statsFrame:StopMovingOrSizing() end)
   
    local headerTexture = header:CreateTexture(nil, "BACKGROUND")
    headerTexture:SetAllPoints()
    headerTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerTexture:SetTexCoord(0.31, 0.67, 0, 0.63)
   
    local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("CENTER", header, "CENTER")
    headerText:SetText("ShamanStasi")
   
    local statsText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    statsText:SetPoint("TOP", header, "BOTTOM", 0, -5)
    statsText:SetText("Combat Stats")
   
    local closeButton = CreateFrame("Button", nil, header)
    closeButton:SetWidth(32)
    closeButton:SetHeight(32)
    closeButton:SetPoint("RIGHT", header, "RIGHT", 0, 0)
   
    local normalTexture = closeButton:CreateTexture(nil, "ARTWORK")
    normalTexture:SetAllPoints()
    normalTexture:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
   
    local hoverTexture = closeButton:CreateTexture(nil, "ARTWORK")
    hoverTexture:SetAllPoints()
    hoverTexture:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    hoverTexture:SetVertexColor(1, 0, 0)
    hoverTexture:Hide()
   
    closeButton:SetNormalTexture(normalTexture)
    closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
   
    closeButton:SetScript("OnEnter", function()
        normalTexture:Hide()
        hoverTexture:Show()
    end)
    closeButton:SetScript("OnLeave", function()
        hoverTexture:Hide()
        normalTexture:Show()
    end)
   
    closeButton:SetScript("OnClick", function() 
        statsFrame:Hide() 
        ShamanStasiData.isWindowVisible = 0
        SaveData()
    end)
   
    local clickArea = CreateFrame("Frame", nil, closeButton)
    clickArea:SetAllPoints(closeButton)
    clickArea:EnableMouse(true)
    clickArea:SetScript("OnMouseDown", function() closeButton:GetScript("OnClick")() end)
   
    clickArea:SetScript("OnEnter", function()
        closeButton:GetScript("OnEnter")()
    end)
    clickArea:SetScript("OnLeave", function()
        closeButton:GetScript("OnLeave")()
    end)
   
    local resetButton = CreateFrame("Button", nil, statsFrame, "UIPanelButtonTemplate")
    resetButton:SetWidth(100)
    resetButton:SetHeight(22)
    resetButton:SetPoint("BOTTOM", statsFrame, "BOTTOM", 0, 10)
    resetButton:SetText("Reset Timers")
    resetButton:SetScript("OnClick", function()
        resetTimers()
    end)
   
    statsFrame:Show()
    return statsFrame, statsText
end

statsFrame, statsText = CreateStatsFrame()

local function formatTime(timeInSeconds)
    local minutes = math.floor(timeInSeconds / 60)
    local seconds = math.mod(math.floor(timeInSeconds), 60)
    return string.format("%d:%02dm", minutes, seconds)
end

local function SaveData()
    ShamanStasiData.totalCombatTime = totalCombatTime
    ShamanStasiData.totalGraceOfAirTime = totalGraceOfAirTime
    ShamanStasiData.totalWindfuryTime = totalWindfuryTime
    ShamanStasiData.showModeEnabled = showModeEnabled
end

local function updateStatsFrame()
    local currentTime = GetTime()

    if UnitAffectingCombat("player") and IsSwinging() then
        totalCombatTime = totalCombatTime + (currentTime - combatStartTime)
        combatStartTime = currentTime

        if graceOfAirIsActive then
            totalGraceOfAirTime = totalGraceOfAirTime + (currentTime - graceOfAirStartTime)
            graceOfAirStartTime = currentTime
        end

        if windfuryIsActive then
            totalWindfuryTime = totalWindfuryTime + (currentTime - windfuryStartTime)
            windfuryStartTime = currentTime
        end
    else
        combatStartTime = currentTime
        graceOfAirStartTime = currentTime
        windfuryStartTime = currentTime
        graceOfAirIsActive = false
        windfuryIsActive = false
    end

    local formattedCombatTime = formatTime(totalCombatTime)
    local graceOfAirPercentage = safePercentage(totalGraceOfAirTime, totalCombatTime)
    local windfuryPercentage = safePercentage(totalWindfuryTime, totalCombatTime)

    statsText:SetText(
        "Total Swing Time: " .. formattedCombatTime .. "\n" ..
        "Grace of Air Uptime: " .. graceOfAirPercentage .. "%\n" ..
        "Windfury Uptime: " .. windfuryPercentage .. "%"
    )

    SaveData()
end


frameStart:RegisterEvent("PLAYER_REGEN_DISABLED")
frameStart:SetScript("OnEvent", function(self, event)
    onCombatStart()
end)

frameEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
frameEnd:SetScript("OnEvent", function(self, event)
    onCombatEnd()
end)

buffFrame:SetScript("OnUpdate", function()
    local currentTime = GetTime()
    local elapsed = currentTime - lastSwingUpdate
    lastSwingUpdate = currentTime

    if st_timer > 0 then
        st_timer = st_timer - elapsed
        if st_timer < 0 then st_timer = 0 end
    end
    if st_timerOff > 0 then
        st_timerOff = st_timerOff - elapsed
        if st_timerOff < 0 then st_timerOff = 0 end
    end

    if (currentTime - lastUpdateTime) >= updateInterval then
        if UnitAffectingCombat("player") and IsSwinging() then
            checkForGraceOfAir()
            checkForWindfury()

            if totalCombatTime >= lastWhisperTime + whisperInterval then
                SendSimpleWhisperToMaraboom()
                lastWhisperTime = totalCombatTime
            end
        end

        updateStatsFrame()
        checkForGraceOfAirAlways()
        lastUpdateTime = currentTime
    end
end)


function resetTimers()
    ResetData()
    totalGraceOfAirTime = 0
    totalWindfuryTime = 0
    totalCombatTime = 0
    if UnitAffectingCombat("player") then
        combatStartTime = GetTime()
    else
        combatStartTime = 0
    end
    graceOfAirIsActive = false
    windfuryIsActive = false
    checkForGraceOfAir()
    checkForWindfury()
    DisplayMessage("All timers (Combat, Grace of Air, Windfury) have been reset!")
    updateStatsFrame()
end

SLASH_SS1 = "/ss"
SlashCmdList["SS"] = function(msg)
    if msg == "show" then
        if statsFrame then 
            statsFrame:Show() 
            ShamanStasiData.isWindowVisible = 1
        end
    elseif msg == "hideagi" then
        graceOfAirBigIconFrame:Hide()
    elseif msg == "hide" then
        if statsFrame then 
            statsFrame:Hide() 
            ShamanStasiData.isWindowVisible = 0
        end
    elseif msg == "smode" then
        showModeEnabled = not showModeEnabled
        ShamanStasiData.showModeEnabled = showModeEnabled
        if showModeEnabled then
            DisplayMessage("Show mode enabled. Grace of Air big icon will be displayed when active for 8+ seconds.")
        else
            DisplayMessage("Show mode disabled. Grace of Air big icon will not be displayed.")
            graceOfAirBigIconFrame:Hide()
        end
        SaveData()
    else
        DisplayMessage("Unknown command. Use '/ss reset' to reset all timers, '/ss show' to show the UI, '/ss hide' to hide the UI, or '/ss smode' to toggle show mode.")
    end
end

local loadFrame = CreateFrame("Frame")
local addonLoadedFrame = CreateFrame("Frame")
addonLoadedFrame:RegisterEvent("ADDON_LOADED")
addonLoadedFrame:SetScript("OnEvent", function()
    LoadData()
    createGraceOfAirBigIcon()
    print("ShamanStasiData.isWindowVisible: " .. tostring(ShamanStasiData.isWindowVisible))
    if ShamanStasiData.isWindowVisible == 0 then
        statsFrame:Hide()
    else
        statsFrame:Show()
    end
    if UnitAffectingCombat("player") then
        combatStartTime = GetTime()
        DisplayMessage("Entered world in combat, setting combat start time.")
    end
    updateStatsFrame()
    DisplayMessage("ShamanStasi loaded with saved data. Use '/ss show' or '/ss hide' to toggle the display, and '/ss smode' to toggle show mode for when agi totem has been alove too long.")
end)

local enteringWorldFrame = CreateFrame("Frame")
enteringWorldFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
enteringWorldFrame:SetScript("OnEvent", function()
    graceOfAirActiveTime = 0
    if graceOfAirBigIconFrame then
        graceOfAirBigIconFrame:Hide()
    end
end)