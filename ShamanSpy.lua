ShamanSpyData = ShamanSpyData or {}

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

local function DisplayMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ShamanSpy]|r " .. message)
end

local function SaveData()
    ShamanSpyData.totalCombatTime = totalCombatTime
    ShamanSpyData.totalGraceOfAirTime = totalGraceOfAirTime
    ShamanSpyData.totalWindfuryTime = totalWindfuryTime
end

local function ResetData()
    ShamanSpyData.totalCombatTime = 0
    ShamanSpyData.totalGraceOfAirTime = 0
    ShamanSpyData.totalWindfuryTime = 0
end

local function LoadData()
    totalCombatTime = ShamanSpyData.totalCombatTime or 0
    totalGraceOfAirTime = ShamanSpyData.totalGraceOfAirTime or 0
    totalWindfuryTime = ShamanSpyData.totalWindfuryTime or 0
end

local function onCombatStart()
    combatStartTime = GetTime()
end

local function onCombatEnd()
    totalCombatTime = totalCombatTime + (GetTime() - combatStartTime)
    
    if graceOfAirIsActive then
        totalGraceOfAirTime = totalGraceOfAirTime + (GetTime() - graceOfAirStartTime)
        graceOfAirIsActive = false
    end
    if windfuryIsActive then
        totalWindfuryTime = totalWindfuryTime + (GetTime() - windfuryStartTime)
        windfuryIsActive = false
    end
    SaveData()
end

local graceOfAirIcon = "Interface\\Icons\\Spell_Nature_InvisibilityTotem"

local function checkForGraceOfAir()
    local graceOfAirFound = false
    local i = 1
    local buffIcon = UnitBuff("player", i)

    while buffIcon do
        if buffIcon == graceOfAirIcon then
            graceOfAirFound = true
            if not graceOfAirIsActive and UnitAffectingCombat("player") then
                graceOfAirStartTime = GetTime()
                graceOfAirIsActive = true
            end
            break
        end
        i = i + 1
        buffIcon = UnitBuff("player", i)
    end

    if not graceOfAirFound and graceOfAirIsActive then
        if UnitAffectingCombat("player") then
            totalGraceOfAirTime = totalGraceOfAirTime + (GetTime() - graceOfAirStartTime)
        end
        graceOfAirIsActive = false
        graceOfAirStartTime = 0
        SaveData()
    end
end

local function checkForWindfury()
    local hasMainHandEnchant, _, _, enchantId = GetWeaponEnchantInfo()
    if hasMainHandEnchant then
        if not windfuryIsActive and UnitAffectingCombat("player") then
            windfuryStartTime = GetTime()
            windfuryIsActive = true
        end
    else
        if windfuryIsActive then
            if UnitAffectingCombat("player") then
                totalWindfuryTime = totalWindfuryTime + (GetTime() - windfuryStartTime)
            end
            windfuryIsActive = false
            windfuryStartTime = 0
            SaveData()
        end
    end
end

local statsFrame
local statsText

local function CreateStatsFrame()
    local statsFrame = CreateFrame("Frame", "ShamanSpyFrame", UIParent)
   
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
    headerText:SetText("ShamanSpy")
   
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
   
    closeButton:SetScript("OnClick", function() statsFrame:Hide() end)
   
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

local function safePercentage(part, whole)
    if whole and whole > 0 then
        return math.ceil((part / whole) * 100)
    else
        return 0
    end
end

local function updateStatsFrame()
    local currentTime = GetTime()
    
    if UnitAffectingCombat("player") then
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
    end
    
    local formattedCombatTime = formatTime(totalCombatTime)
    local graceOfAirPercentage = safePercentage(totalGraceOfAirTime, totalCombatTime)
    local windfuryPercentage = safePercentage(totalWindfuryTime, totalCombatTime)
    
    statsText:SetText(
        "Combat Time: " .. formattedCombatTime .. "\n" ..
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

local lastUpdateTime = 0
local updateInterval = 0.5

buffFrame:SetScript("OnUpdate", function()
    local currentTime = GetTime()
    if (currentTime - lastUpdateTime) >= updateInterval then
        if UnitAffectingCombat("player") then
            checkForGraceOfAir()
            checkForWindfury()
            updateStatsFrame()
        end
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
        if statsFrame then statsFrame:Show() end
    elseif msg == "hide" then
        if statsFrame then statsFrame:Hide() end
    else
        DisplayMessage("Unknown command. '/ss show' to show the UI, or '/ss hide' to hide the UI.")
    end
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loadFrame:SetScript("OnEvent", function(self, event, addonName)
    LoadData()
    if UnitAffectingCombat("player") then
        combatStartTime = GetTime()
        DisplayMessage("Entered world in combat, setting combat start time.")
    end
    updateStatsFrame()
    DisplayMessage("ShamanSpy loaded with saved data. Use '/ss show' or '/ss hide' to toggle the display.")
end)