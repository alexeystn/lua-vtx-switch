chdir("/SCRIPTS/TELEMETRY")
assert(loadScript("/SCRIPTS/TELEMETRY/ledvtx_crsf.lua"))()

local colorNames = { "Red", "Yellow", "Green", "Cyan", "Blue", "Violet", "White", "Black" }
local colorIds = { 2, 3, 6, 8, 10, 13, 1, 0 }

local bandNames = { "Raceband", "Fatshark" }
local bandIds = { 5, 4 }

local menuPosition = 1
local menuLength = 3
local isItemSelected = false

local ledColor = 1
local vtxChannel = 1

local ITEM_LED = 1
local ITEM_VTX = 2

local retryCount = 0
local maxRetries = 4
local retryTimeout = 200
local currentTime = 0
local nextTime = 0

local IDLE=1
local SWITCHING_LED=2
local SWITCHING_VTX=3
local SAVING=4
local DONE=5

local state = IDLE

local MSP_VTX_SET_CONFIG = 89
local MSP_EEPROM_WRITE = 250
local MSP_SET_LED_STRIP = 49

local buttonState = false


function testKey()
  if buttonState then
    buttonState = false
    return true
  else 
    return false
  end
end


function setButtonState()
  buttonState = true
end


local function itemIncrease()
  if menuPosition == ITEM_LED then 
    if ledColor < #colorNames then
      ledColor = ledColor + 1
    end
  end
  if menuPosition == ITEM_VTX then
    if vtxChannel < (#bandNames * 8) then
      vtxChannel = vtxChannel + 1
    end
  end
end


local function itemDecrease()
  if menuPosition == ITEM_LED then 
    if ledColor > 1 then
      ledColor = ledColor - 1
    end
  end
  if menuPosition == ITEM_VTX then
    if vtxChannel > 1 then
      vtxChannel = vtxChannel - 1
    end
  end
end


local function menuMoveDown()
  if menuPosition < menuLength then
    menuPosition = menuPosition + 1
  end
end


local function menuMoveUp()
  if menuPosition > 1 then
    menuPosition = menuPosition - 1
  end
end



local function getBandName()
  local vtxChanNum =  tostring((vtxChannel - 1) % 8 + 1)
  local vtxBandNum = bandNames[math.floor((vtxChannel - 1) / 8) + 1]
  return vtxBandNum .. " " .. vtxChanNum
end



local function getStatusText()
  local result
  if state == IDLE then
   result = "Press [ENTER] to save"
  elseif state == SWITCHING_LED then 
    result = "Switching LED...  " .. tostring(retryCount + 1)
  elseif state == SWITCHING_VTX then 
    result = "Switching VTX...  " .. tostring(retryCount + 1)
  elseif  state == SAVING then 
    result = "Saving...  " ..  tostring(retryCount + 1)
  else
    result = "Done"
  end
  return result
end


local function drawDisplay()
  local d = 16
  lcd.clear()
  lcd.drawText(20, 0, colorNames[ledColor], MIDSIZE)
  lcd.drawText(20, d, getBandName(), MIDSIZE)
  lcd.drawText(20, d*2, "Save", MIDSIZE)
  lcd.drawText(5, d*3, getStatusText())
  if isItemSelected then
    text = ">"
  else
    text = "-"
  end
  lcd.drawText(10, (menuPosition-1)*d, text, MIDSIZE)  
end


local function sendSaveCommand()
  mspRead(MSP_EEPROM_WRITE)
  print("MSP_EEPROM_WRITE")
  nextTime = getTime() + retryTimeout
  state = SAVING
end


local function sendSwitchVtxCommand()
  local channelIndex = (bandIds[math.floor((vtxChannel - 1) / 8) + 1] - 1) * 8 + ((vtxChannel - 1) % 8 )
  mspWrite(MSP_VTX_SET_CONFIG, { channelIndex, 0, 1, 0 } )
  print("MSP_VTX_SET_CONFIG")
  nextTime = getTime() + retryTimeout
  state = SWITCHING_VTX
end


local function sendSwitchLedCommand()
  mspWrite(MSP_SET_LED_STRIP, { 0, 0, 0, (colorIds[ledColor])*4, 0 } )
  print("MSP_SET_LED_STRIP")
  nextTime = getTime() + retryTimeout
  state = SWITCHING_LED
end


function processMspReply(cmd, rx_buf)
  
  local key = testKey()
  if (cmd == nil or rx_buf == nil) and not key then
    return
  end
  if ((cmd == MSP_VTX_SET_CONFIG)or key) and state == SWITCHING_VTX then
    sendSwitchLedCommand()
    retryCount = 0
    state = SWITCHING_LED
  elseif ((cmd == MSP_SET_LED_STRIP) or key) and state == SWITCHING_LED then
    sendSaveCommand()
    retryCount = 0
    state = SAVING
  elseif ((cmd == MSP_EEPROM_WRITE) or key) and state == SAVING then
    state = DONE
  end
end



local function pressSave()
  retryCount = 0
  sendSwitchVtxCommand()
end


local function processEnterPress()
  if menuPosition < menuLength then
    isItemSelected = not isItemSelected
  else
    pressSave()
  end
end


local function run_func(event)   
  currentTime = getTime()
  if (state ~= IDLE) and (state ~= DONE) then
    if currentTime > nextTime then
      if retryCount < maxRetries then
        if state == SAVING then 
          sendSaveCommand()
        elseif state == SWITCHING_LED then
          sendSwitchLedCommand()
        elseif state == SWITCHING_VTX then
          sendSwitchVtxCommand()
        end
        retryCount = retryCount + 1
      else
        state = IDLE
      end
    end
  end

  if event == EVT_ROT_RIGHT then
    if isItemSelected then
      itemIncrease()
    else
      menuMoveDown()
    end
  end
  if event == EVT_ROT_LEFT then
    if isItemSelected then
      itemDecrease()
    else
      menuMoveUp()
    end
  end  
  if event == EVT_ENTER_BREAK then
    processEnterPress()
  end
  if event == EVT_MENU_BREAK then
    setButtonState()
  end
  if event == EVT_ENTER_LONG then
    pressSave()
  end
  if event == EVT_EXIT_BREAK then
    state = IDLE
    retryCount = retryCount + 1
  end  
  if state == DONE and (event == EVT_ROT_LEFT or event == EVT_ROT_RIGHT) then 
    state = IDLE
  end
  
  drawDisplay()
  mspProcessTxQ()
  processMspReply(mspPollReply())
  
  return 0
end


return { run=run_func }
