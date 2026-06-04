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
local ITEM_VTX_MODE = 9
local ITEM_BANDS = 10

local IDLE=1
local BUSY=2
local DONE=3
local FAIL=4

local VTX_MODE_MSP = 1
local VTX_MODE_ELRS = 2

local BANDS_ANALOG = 1
local BANDS_HDZERO = 2

local maxLedCount = 32

local colorLabels = { "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Violet", "Magenta", "White", "Black", "   * * * *" }
local colorIds = { 2, 3, 4, 6, 8, 10, 11, 12, 1, 0, nil }

local bandNames = { "Band A", "Band B", "Band E", "Fatshark", "Raceband", "Lowband"}
local bandIds = { 1, 2, 3, 4, 5, 6 }

local switchLabels = {"OFF", "ON"}
local switchIds = {0, 1}

local versionLabels = {"4.5+", "4.4-"}
local versionIds = {0, 1}

local vtxModeLabels = {"MSP", "ELRS"}
local vtxModeIds = {VTX_MODE_MSP, VTX_MODE_ELRS}

local bandsLabels = {"Analog", "HDZero"}
local bandsIds = {BANDS_ANALOG, BANDS_HDZERO}

local powerLabels = {}
local powerIds = {}
powerLabels[#powerLabels+1] = "-"
powerIds[#powerIds+1] = 0
for i = 1, 8 do
  powerLabels[#powerLabels+1] = tostring(i)
  powerIds[#powerIds+1] = i
end

local countLabels = {}
local countIds = {}
for i = 1, maxLedCount do
  countLabels[#countLabels+1] = tostring(i)
  countIds[#countIds+1] = i
end

local analogChannels = {}
local hdzeroChannels = {}
local channelLabels = {}
local channelIds = {}

local function addChannel(list, band, channel)
  list[#list+1] = {band, channel}
end

for iBand = 1, #bandNames do
  for iCh = 1, 8 do
    addChannel(analogChannels, bandIds[iBand], iCh)
  end
end

for iCh = 1, 8 do
  addChannel(hdzeroChannels, 5, iCh)
end
addChannel(hdzeroChannels, 3, 1)
addChannel(hdzeroChannels, 4, 1)
addChannel(hdzeroChannels, 4, 2)
addChannel(hdzeroChannels, 4, 4)
for iCh = 1, 8 do
  addChannel(hdzeroChannels, 6, iCh)
end

menu = {}

menu[ITEM_LED] = {labels = colorLabels, values = colorIds, pos = 1}
menu[ITEM_VTX] = {labels = channelLabels, values = channelIds, pos = 1}
menu[ITEM_POWER] = {labels = powerLabels, values = powerIds, pos = 1}
menu[ITEM_COUNT] = {labels = countLabels, values = countIds, pos = 1}
menu[ITEM_LARSON] = {labels = switchLabels, values = switchIds, pos = 1}
menu[ITEM_VERSION] = {labels = versionLabels, values = versionIds, pos = 1}
menu[ITEM_VTX_MODE] = {labels = vtxModeLabels, values = vtxModeIds, pos = 1}
menu[ITEM_BANDS] = {labels = bandsLabels, values = bandsIds, pos = 1}


local menuPosition = ITEM_LED
local isItemActive = false
local isOptionsMenuActive = false
local state = IDLE
local vtxConfigVersion = nil
local statusText = nil


local function getVtxMode()
  return menu[ITEM_VTX_MODE].values[menu[ITEM_VTX_MODE].pos]
end


local function getBandsMode()
  return menu[ITEM_BANDS].values[menu[ITEM_BANDS].pos]
end


local function getBandName(band)
  for i = 1, #bandIds do
    if bandIds[i] == band then
      return bandNames[i]
    end
  end
  return "Band " .. tostring(band)
end


local function channelLabel(band, channel)
  if band and channel then
    return getBandName(band) .. " " .. tostring(channel)
  end
  return "   * * * *"
end


local function fillChannelList(currentBand, currentChannel)
  local source = getBandsMode() == BANDS_HDZERO and hdzeroChannels or analogChannels
  channelLabels = {}
  channelIds = {}

  for i = 1, #source do
    local band = source[i][1]
    local channel = source[i][2]
    channelLabels[#channelLabels+1] = channelLabel(band, channel)
    channelIds[#channelIds+1] = {band, channel}
  end

  channelLabels[#channelLabels+1] = "   * * * *"
  channelIds[#channelIds+1] = {nil, nil}

  if currentBand and currentChannel then
    for i = 1, #channelIds do
      if channelIds[i][1] == currentBand and channelIds[i][2] == currentChannel then
        menu[ITEM_VTX].labels = channelLabels
        menu[ITEM_VTX].values = channelIds
        menu[ITEM_VTX].pos = i
        return
      end
    end

    channelLabels[#channelLabels+1] = channelLabel(currentBand, currentChannel)
    channelIds[#channelIds+1] = {currentBand, currentChannel}
    menu[ITEM_VTX].pos = #channelLabels
  end

  menu[ITEM_VTX].labels = channelLabels
  menu[ITEM_VTX].values = channelIds
  if menu[ITEM_VTX].pos > #channelLabels then
    menu[ITEM_VTX].pos = #channelLabels
  end
end


fillChannelList()


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
  if menuPosition ~= ITEM_SAVE and menuPosition ~= ITEM_BANDS then
    menuPosition = menuPosition + 1
  end
end


local function menuMoveUp()
  if menuPosition ~= 1 and menuPosition ~= ITEM_SAVE+1 then
    menuPosition = menuPosition - 1
  end
end


local function refreshStatus()
  local event
  statusText, event = com.getStatus()
  if statusText then
    state = BUSY
  elseif event == 1 then
    state = DONE
  elseif event == -1 then
    state = FAIL
  end
end


local function drawDisplay()
  lcd.clear()
  if isOptionsMenuActive then
    local firstOption = menuPosition - 3
    if firstOption < ITEM_POWER then
      firstOption = ITEM_POWER
    elseif firstOption > ITEM_BANDS - 3 then
      firstOption = ITEM_BANDS - 3
    end
    for row = 1, 4 do
      local item = firstOption + row - 1
      local label = ""
      local offset = nil
      if item == ITEM_POWER then
        label = "Power Level"
      elseif item == ITEM_COUNT then
        label = "LED Count"
      elseif item == ITEM_LARSON then
        label = "Larson Scanner"
      elseif item == ITEM_VERSION then
        label = "BF Version"
        offset = -4
      elseif item == ITEM_VTX_MODE then
        label = "VTX Mode"
      elseif item == ITEM_BANDS then
        label = "Bands"
      end
      gui.drawSmallSelector(row, label, menu[item].labels[menu[item].pos], menuPosition==item, isItemActive, offset)
    end
  else
    
    gui.drawSelector(1, colorLabels[menu[ITEM_LED].pos], menuPosition==ITEM_LED, isItemActive)
    gui.drawSelector(2, channelLabels[menu[ITEM_VTX].pos], menuPosition==ITEM_VTX, isItemActive)

    local btnText = statusText
    btnSelected = (not statusText) and (menuPosition == ITEM_SAVE)
    if not statusText then
      if state == DONE then
        btnText = "Done"
      elseif state == FAIL then
        btnText = "Failed"
      else
        btnText = "Save"
      end
    end
    gui.drawOptions(menuPosition == ITEM_OPTS)
    gui.drawButton(btnText, btnSelected)
  end
  gui.drawStatus()
end


local function applyVtxConfig(config_)
  if not config_ or config_.version == vtxConfigVersion then
    return
  end
  if menuPosition == ITEM_VTX or isItemActive or state ~= IDLE then
    return
  end
  -- Mirror the current TX-module VTX state into the menu without forcing a write.
  fillChannelList(config_.band, config_.channel)
  vtxConfigVersion = config_.version
  if config_.power then
    for i = 1, #powerIds do
      if powerIds[i] == config_.power then
        menu[ITEM_POWER].pos = i
        break
      end
    end
  end
end


local function prepareVtxArgs()
  return {
    band = menu[ITEM_VTX].values[menu[ITEM_VTX].pos][1],
    channel = menu[ITEM_VTX].values[menu[ITEM_VTX].pos][2],
    power = menu[ITEM_POWER].values[menu[ITEM_POWER].pos],
    vtxMode = getVtxMode()
  }
end


local function sendElrsVtxConfig()
  local args = prepareVtxArgs()
  if getVtxMode() ~= VTX_MODE_ELRS or not args.band then
    return
  end
  state = BUSY
  config.save(menu)
  com.sendLedVtxConfig(args)
end


local function processEnterPress()
  if menuPosition == ITEM_OPTS then
    menuPosition = ITEM_SAVE + 1
    isOptionsMenuActive = true
    return
  end
  if menuPosition ~= ITEM_SAVE and menuPosition ~= ITEM_OPTS then
    local wasActive = isItemActive
    isItemActive = not isItemActive
    if wasActive and menuPosition == ITEM_BANDS then
      local current = menu[ITEM_VTX].values[menu[ITEM_VTX].pos]
      fillChannelList(current[1], current[2])
    end
    if wasActive and (menuPosition == ITEM_VTX or menuPosition == ITEM_POWER) then
      sendElrsVtxConfig()
    end
  else
    state = BUSY
    state = DONE -- TODO: remove this line
    config.save(menu)

    local args = prepareVtxArgs()
    args.color = menu[ITEM_LED].values[menu[ITEM_LED].pos]
    args.count = menu[ITEM_COUNT].values[menu[ITEM_COUNT].pos]
    args.larson = menu[ITEM_LARSON].values[menu[ITEM_LARSON].pos]
    args.version = menu[ITEM_VERSION].values[menu[ITEM_VERSION].pos]
    com.sendLedVtxConfig(args)  -- TODO: transfer all parameters
  end
end


local function run_func(event)
  com.mainLoop(getVtxMode())
  refreshStatus()
  if getVtxMode() == VTX_MODE_ELRS then
    applyVtxConfig(com.getVtxConfig())
  end
  if state ~= BUSY then
    if isItemActive then
      if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
        itemIncrease()
      else
        if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
          itemDecrease()
        end
      end
      if event == EVT_EXIT_BREAK then
        isItemActive = false
      end
    else 
      if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
        menuMoveDown()
      else
        if event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
          menuMoveUp()
        end
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
  if ((state == DONE) or (state == FAIL)) and (event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_PREV) then 
    state = IDLE
  end
  drawDisplay()
  return 0
end


local function bg_func()
end


local function init_func()
  config.load_(menu)
  fillChannelList()
end


return { run=run_func, background=bg_func, init=init_func}
