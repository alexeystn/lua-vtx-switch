SCRIPT_HOME = "/SCRIPTS/BF"

protocol = assert(loadScript(SCRIPT_HOME.."/protocols.lua"))()
radio = assert(loadScript(SCRIPT_HOME.."/radios.lua"))()

assert(loadScript(radio.preLoad))()
assert(loadScript(protocol.transport))()
assert(loadScript(SCRIPT_HOME.."/MSP/common.lua"))()

local MSP_VTX_CONFIG = 88 
local MSP_VTX_SET_CONFIG = 89
local MSP_EEPROM_WRITE = 250

local newChannel = 1
local isSaving = false
local isSaved = false
local saveRetries = 0
local saveMaxRetries = protocol.saveMaxRetries or 2
local saveTimeout = protocol.saveTimeout or 150
local saveTimestamp = 0
local currentTime = 0

function processMspReply(cmd, rx_buf)
  if cmd == nil or rx_buf == nil then
	  return
  end
  if cmd == MSP_VTX_SET_CONFIG then
    protocol.mspRead(MSP_EEPROM_WRITE)
  end
	if cmd == MSP_EEPROM_WRITE then
	  isSaving = false
    isSaved = true
	end
end

local function saveSettings()
  -- RaceBand (5 - 1) * 8, 25 mW, PitMode Off
  protocol.mspWrite(MSP_VTX_SET_CONFIG, { 32 + newChannel - 1, 0, 1, 0 } )
	saveTimestamp = getTime()
  if isSaving then
    saveRetries = saveRetries + 1
  else
    isSaving = true
    saveRetries = 0
  end
end

local function drawDisplay()
  lcd.clear()
  lcd.drawFilledRectangle(0, 0, LCD_W, 10)
  lcd.drawText(34, 1, "VTX channel", INVERS)
  
  lcd.drawText(20, 28, "RaceBand", MIDSIZE)
  lcd.drawFilledRectangle(90, 25, 16, 18, SOLID)
  lcd.drawText(94, 26, tostring(newChannel), DBLSIZE + INVERS)
  if isSaving then
    lcd.drawText(45, 56, "Saving...")
    --lcd.drawNumber(121, 1, saveRetries, INVERS)
  elseif isSaved then
    lcd.drawText(52, 56, "Done")
  else
    lcd.drawText(8, 56, "Press [ENTER] to save")
  end
  arrX = 97
  arrY = 34
  for i = 0, 3 do
    lcd.drawLine(arrX-i, arrY-16+i, arrX+i+1, arrY-16+i, SOLID, FORCE)
    lcd.drawLine(arrX-i, arrY+15-i, arrX+i+1, arrY+15-i, SOLID, FORCE)
  end
end

local function run_func(event)  
	currentTime = getTime()
  if isSaving then
		if (saveTimestamp + saveTimeout < currentTime) then
      if saveRetries < saveMaxRetries then
        saveSettings()
      else
        isSaving = false
      end
    end
	else
    if event == EVT_ROT_RIGHT then
      if newChannel < 8 then
        newChannel = newChannel + 1
      end
      isSaved = false
    end
    if event == EVT_ROT_LEFT then
      if newChannel > 1 then
        newChannel = newChannel - 1
      end
      isSaved = false
    end 
    if event == EVT_ENTER_BREAK then
      saveSettings()
      isSaving = true
    end
  end
	drawDisplay()
  mspProcessTxQ()
	processMspReply(mspPollReply())
  return 0
end

return { run=run_func }

--[[
  protocol.mspRead(MSP_VTX_CONFIG)
  if cmd == MSP_VTX_CONFIG then
    if #rxBuf >= 3 then
      currentChannel = rxBuf[3]
    end
  end
]]--