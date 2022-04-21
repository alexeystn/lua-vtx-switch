local msp = assert(loadScript("msp.lua"))()

local MSP_VTX_SET_CONFIG = 89
local MSP_EEPROM_WRITE = 250
local MSP_SET_LED_STRIP = 49
local MSP_SET_RTC = 246

local isBusy = false
local retryCount = 0
local maxRetries = 4
local retryTimeout = 200
--local currentTime = 0
local nextTime = 0
--local nextRtcTime = 0

local commandSequence = {}
local commandPointer = 0
local currentCommand = {}


local buttonState = false

function testKey()
  if buttonState then
    buttonState = false
    return true
  else 
    return false
  end
end

function setDebugButtonState()
  buttonState = true
end


local function sendCurrentCommand()
  retryCount = retryCount + 1
  if retryCount > maxRetries then
    isBusy = false
  end
  if currentCommand.write then
    msp.write(currentCommand.header, currentCommand.payload)
  else
    msp.read(currentCommand.header, currentCommand.payload)
  end
  nextTime = getTime() + retryTimeout
  
end


local function gotoNextCommand()
  if commandPointer < #commandSequence then
    commandPointer = commandPointer + 1
    currentCommand = commandSequence[commandPointer]
    retryCount = 0
    sendCurrentCommand()
  else
    currentCommand = nil
    isBusy = false
  end
end


function processMspReply(cmd, rx_buf)
  local key = testKey()
  if (cmd == nil or rx_buf == nil) and not key then
    return
  end
  if ((cmd == currentCommand.header) or key) and isBusy then
    gotoNextCommand()
  end
end


local function startTransmission(commands) 
  commandSequence = commands
  commandPointer = 0
  isBusy = true
  gotoNextCommand()
end


local function prepareLedCommand(color)
  cmd = {}
  cmd.header = MSP_SET_LED_STRIP
  cmd.payload = { 0, 0, 0, color*4, 0 }
  cmd.write = true
  cmd.text = "LEDs"
  return cmd
end


local function prepareVtxCommand(band, channel)
  cmd = {}
  cmd.header = MSP_VTX_SET_CONFIG
  cmd.payload = { band*8 + channel, 0, 1, 0 }
  cmd.write = true
  cmd.text = "VTX"
  return cmd
end


local function prepareSaveCommand()
  cmd = {}
  cmd.header = MSP_EEPROM_WRITE
  cmd.payload = nil
  cmd.write = false
  cmd.text = "Saving"
  return cmd
end


local function prepareRtcCommand()
  local now = getRtcTime()
  local values = {}
  for i = 1, 4 do
    values[i] = bit32.band(now, 0xFF)
    now = bit32.rshift(now, 8)
  end
  values[5] = 0 
  values[6] = 0
  cmd = {}
  cmd.header = MSP_SET_RTC
  cmd.payload = values
  cmd.write = true
  cmd.text = "RTC"
  return cmd  
end


local function sendLedVtxConfig(color, band, channel)  
  retryCount = 0
  ledCommand = prepareLedCommand(color)
  vtxCommand = prepareVtxCommand(band, channel)
  saveCommand = prepareSaveCommand()
  startTransmission({ledCommand, vtxCommand , saveCommand})
end  


local function getStatus()
  if isBusy then
    if currentCommand then
      return currentCommand.text .. " " .. tostring(retryCount), 10
    else 
      return "text", 10
    end
  else
    return "Save", 10
  end
end


function comMainLoop()
  
  if isBusy then
    currentTime = getTime()
    if currentTime > nextTime then 
      sendCurrentCommand()
    end
  end
  
  msp.processTxQ()
  processMspReply(msp.pollReply())
end


return { sendLedVtxConfig = sendLedVtxConfig, loop = comMainLoop, getStatus=getStatus, setDebug=setDebugButtonState}
