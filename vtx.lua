chdir("/SCRIPTS/BF")

protocol = assert(loadScript("protocols.lua"))()
assert(loadScript(protocol.transport))()
assert(loadScript("MSP/common.lua"))()

local FATSHARK_BAND = 4
local RACEBAND_BAND = 5

local MSP_VTX_CONFIG = 88 
local MSP_VTX_SET_CONFIG = 89
local MSP_EEPROM_WRITE = 250

local newChannel = 1
local fatsharkBandEnabled = true

local retryCount = 0
local maxRetries = 4
local retryTimeout = 200
local currentTime = 0
local nextTime = 0

local IDLE=1
local SWITCHING=2
local SAVING=3
local DONE=4

local state = IDLE

local buttonState = false


function getButtonState()
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


local function sendSaveCommand()
  protocol.mspRead(MSP_EEPROM_WRITE)
  print("MSP_EEPROM_WRITE")
  nextTime = getTime() + retryTimeout
  state = SAVING
end


local function sendSwitchCommand()
  local channelIndex
  if newChannel <= 8 then
    channelIndex = (RACEBAND_BAND - 1) * 8 + newChannel - 1
  else
    channelIndex = (FATSHARK_BAND - 1) * 8 + newChannel - 8 - 1
  end
  -- channel, 25 mW, PitMode Off
  protocol.mspWrite(MSP_VTX_SET_CONFIG, { channelIndex, 0, 1, 0 } )
  print("MSP_VTX_SET_CONFIG")
  nextTime = getTime() + retryTimeout
  state = SWITCHING
end

function processMspReply(cmd, rx_buf)
--[[  if getButtonState() then
    if state == SWITCHING then
      sendSwitchCommand()
      retryCount = 0
      state = SAVING
    elseif state == SAVING then 
      state = DONE
    end
  end]]--
  if cmd == nil or rx_buf == nil then
    return
  end
  if cmd == MSP_VTX_SET_CONFIG and state == SWITCHING then
    sendSwitchCommand()
    retryCount = 0
    state = SAVING
  end
  if cmd == MSP_EEPROM_WRITE and state == SAVING then
    state = DONE
  end
end


local function drawDisplay()
  lcd.clear()
  lcd.drawFilledRectangle(0, 0, LCD_W, 10)
  lcd.drawText(34, 1, "VTX channel", INVERS)
  if newChannel <= 8 then
    lcd.drawText(20, 28, "RaceBand", MIDSIZE)
  else
    lcd.drawText(20, 28, "FatShark", MIDSIZE)
  end
  lcd.drawFilledRectangle(90, 25, 16, 18, SOLID)
  lcd.drawText(94, 26, tostring(((newChannel - 1) % 8) + 1), DBLSIZE + INVERS)
  if state == IDLE then
    lcd.drawText(8, 56, "Press [ENTER] to save")
  elseif state == SWITCHING then 
    lcd.drawText(35, 56, "Switching...")
    lcd.drawNumber(121, 1, retryCount + 1, INVERS)
  elseif  state == SAVING then 
    lcd.drawText(45, 56, "Saving...")
    lcd.drawNumber(121, 1, retryCount + 1, INVERS)
  else
    lcd.drawText(52, 56, "Done")
  end
  arrX = 97
  arrY = 34
  for i = 0, 3 do
    lcd.drawLine(arrX-i, arrY-16+i, arrX+i+1, arrY-16+i, SOLID, FORCE)
    lcd.drawLine(arrX-i, arrY+15-i, arrX+i+1, arrY+15-i, SOLID, FORCE)
  end
end


local function run_func(event)    
  if event == EVT_MENU_BREAK then
    setButtonState()
  end
  print(state)
  currentTime = getTime()
  if (state ~= IDLE) and (state ~= DONE) then
    if currentTime > nextTime then
      if retryCount < maxRetries then
        if state == SAVING then 
          sendSaveCommand()
        elseif state == SWITCHING then
          sendSwitchCommand()
        end
        retryCount = retryCount + 1
      else
        state = IDLE
      end
    end
  else
    if event == EVT_ROT_RIGHT then
      if (newChannel < 8) or (fatsharkBandEnabled and (newChannel < 16)) then
        newChannel = newChannel + 1
      end
      state = IDLE
    end
    if event == EVT_ROT_LEFT then
      if newChannel > 1 then
        newChannel = newChannel - 1
      end
      state = IDLE
    end 
    if event == EVT_ENTER_BREAK then
      retryCount = 0
      sendSwitchCommand()
    end
  end
  drawDisplay()
  mspProcessTxQ()
  processMspReply(mspPollReply())
  return 0
end


return { run=run_func }
