chdir("/SCRIPTS/TOOLS/LEDVTX")

local toolName = "TNS|LED & VTX setup|TNE"

local gui = assert(loadScript("gui.lua"))()
local config = assert(loadScript("config.lua"))()
local com = assert(loadScript("com.lua"))()

local ITEM_OPTS = 1
local ITEM_LED = 2
local ITEM_VTX = 3
local ITEM_SAVE = 4

local ITEM_POWER = 5
local ITEM_COUNT = 6
local ITEM_LARSON = 7
local ITEM_VERSION = 8

local IDLE=1
local BUSY=2
local DONE=3
local FAIL=4


local colorLabels = { "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Violet", "White", "Black", "   * * * *" }
local colorIds = { 2, 3, 4, 6, 8, 10, 13, 1, 0, nil }

local bandNames = { "Raceband", "Fatshark", "Lowband"}
local bandIds = { 5, 4, 6 }

local switchLabels = {"OFF", "ON"}
local switchIds = {0, 1}

local versionLabels = {" 4.4", " 4.5", " 4.6"}
local versionIds = {44, 45, 46}

local powerLabels = {}
local powerIds = {}
for i = 0, 4 do
  powerLabels[#powerLabels+1] = tostring(i)
  powerIds[#powerIds+1] = i
end

local countLabels = {}
local countIds = {}
for i = 1, 10 do
  countLabels[#countLabels+1] = tostring(i)
  countIds[#countIds+1] = i
end

local channelLabels = {}
local channelIds = {}
for iBand = 1, 3 do
  for iCh = 1, 8 do
    channelLabels[#channelLabels+1] = bandNames[iBand] .. " " .. tostring(iCh)
    channelIds[#channelIds+1] = {bandIds[iBand], iCh}
  end
end
channelLabels[#channelLabels+1] = "   * * * *"
channelIds[#channelIds+1] = nil

menu = {}

menu[ITEM_LED] = {labels = colorLabels, values = colorIds, pos = 1}
menu[ITEM_VTX] = {labels = channelLabels, values = channelIds, pos = 1}

menu[ITEM_POWER] = {labels = powerLabels, values = powerIds, pos = 1}
menu[ITEM_COUNT] = {labels = countLabels, values = countIds, pos = 1}
menu[ITEM_LARSON] = {labels = switchLabels, values = switchIds, pos = 1}
menu[ITEM_VERSION] = {labels = versionLabels, values = versionIds, pos = 1}


local menuPosition = ITEM_LED
local isItemActive = false
local isOptionsMenuActive = false
local state = IDLE


local function itemIncrease()

  if menu[menuPosition] then
    if menu[menuPosition].pos < #menu[menuPosition].labels then
      menu[menuPosition].pos = menu[menuPosition].pos + 1
    end
  end
end


local function itemDecrease()
  if menu[menuPosition] then
    if menu[menuPosition].pos > 1 then
      menu[menuPosition].pos = menu[menuPosition].pos - 1
    end
  end
end


local function menuMoveDown()
  if menuPosition ~= ITEM_SAVE and menuPosition ~= ITEM_VERSION then
    menuPosition = menuPosition + 1
  end
end


local function menuMoveUp()
  if menuPosition ~= 1 and menuPosition ~= ITEM_SAVE+1 then
    menuPosition = menuPosition - 1
  end
end


local function drawDisplay()
  lcd.clear()
  if isOptionsMenuActive then
    gui.drawSmallSelector(1, "Power Level",   menu[ITEM_POWER].labels[menu[ITEM_POWER].pos], menuPosition==ITEM_POWER, isItemActive)
    gui.drawSmallSelector(2, "LED Count",   menu[ITEM_COUNT].labels[menu[ITEM_COUNT].pos], menuPosition==ITEM_COUNT, isItemActive)
    gui.drawSmallSelector(3, "Larson Scan",   menu[ITEM_LARSON].labels[menu[ITEM_LARSON].pos], menuPosition==ITEM_LARSON, isItemActive)
    gui.drawSmallSelector(4, "BF Version",   menu[ITEM_VERSION].labels[menu[ITEM_VERSION].pos], menuPosition==ITEM_VERSION, isItemActive)
  else
    
    gui.drawSelector(1, colorLabels[menu[ITEM_LED].pos], menuPosition==ITEM_LED, isItemActive)
    gui.drawSelector(2, channelLabels[menu[ITEM_VTX].pos], menuPosition==ITEM_VTX, isItemActive)

    local btnText, event
    btnText, event = com.getStatus()
    btnSelected = (not btnText) and (menuPosition == ITEM_SAVE)
    if not btnText then
      if event == 1 then
        state = DONE
      elseif event == -1 then
        state = FAIL
      end
      if state == DONE then
        btnText = "Done"
      elseif state == FAIL then
        btnText = "Failed"
      else
        btnText = "Save"
      end
    else 
      state = BUSY
    end
    gui.drawOptions(menuPosition == ITEM_OPTS)
    gui.drawButton(btnText, btnSelected)
  end
  gui.drawStatus()
end


local function processEnterPress()
  if menuPosition == ITEM_OPTS then
    menuPosition = ITEM_SAVE + 1
    isOptionsMenuActive = true
    return
  end
  if menuPosition ~= ITEM_SAVE and menuPosition ~= ITEM_OPTS then
    isItemActive = not isItemActive
  else
    state = BUSY
    state = DONE -- TODO: remove this line
    config.save(menu)
    --com.sendLedVtxConfig(colorIds[ledColor], bandIds[vtxBand], vtxChannel, ledCount, mspApiVersion)  -- TODO: transfer all parameters
  end
end


local function run_func(event)
  com.mainLoop()
  if state ~= BUSY then
    if isItemActive then
      if event == EVT_ROT_RIGHT or event == EVT_PLUS_FIRST or event == EVT_PLUS_REPT then
        itemIncrease()
      end
      if event == EVT_ROT_LEFT or event == EVT_MINUS_FIRST or event == EVT_MINUS_REPT then
        itemDecrease()
      end
      if event == EVT_EXIT_BREAK then
        isItemActive = false
      end
    else 
      if event == EVT_ROT_RIGHT or event == EVT_MINUS_FIRST or event == EVT_MINUS_REPT then
        menuMoveDown()
      end
      if event == EVT_ROT_LEFT or event == EVT_PLUS_FIRST or event == EVT_PLUS_REPT then
        menuMoveUp()
      end
      if event == EVT_EXIT_BREAK then
        if isOptionsMenuActive then
          isOptionsMenuActive = false
          menuPosition = ITEM_LED
        else
          return -1
        end
      end
    end
  end
  if event == EVT_ENTER_BREAK then
    processEnterPress()
  end
  if event == EVT_MENU_BREAK then
    com.setDebug()
  end
  if event == EVT_EXIT_BREAK then
    com.cancel()
    state = IDLE
  end  
  if ((state == DONE) or (state == FAIL)) and (event == EVT_ROT_LEFT or event == EVT_ROT_RIGHT) then 
    state = IDLE
  end
  drawDisplay()
  return 0
end


local function bg_func()
  com.bgLoop()
end


local function init_func()

  limits = {}
  for i = 1, 10 do
    if menu[i] then
      limits[#limits+1] = #menu[i].labels
    end
  end

  positions = config.load_(limits)
  for i = 1, #positions do
    print(positions[i])
  end
  p = 1
  for i = 1, 10 do
    if menu[i] then
      menu[i].pos = positions[p]
      p = p+1
    end
  end
end


return { run=run_func, background=bg_func, init=init_func}
