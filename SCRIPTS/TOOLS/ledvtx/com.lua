local msp = assert(loadScript("msp.lua"))()

local MSP_VTX_SET_CONFIG = 89
local MSP_EEPROM_WRITE = 250
local MSP_SET_LED_STRIP = 49
local MSP_SET_RTC = 246

local isBusy = false
local retryCount = 0
local maxRetries = 4
local retryTimeout = 200
local nextTryTime = 0
local nextRtcTime = 0

local successFlag = false
local failedFlag = false

local commandSequence = {}
local commandPointer = 0
local currentCommand = {}


local debugButtonState = false

local function getDebugButtonState()
  if debugButtonState then
    debugButtonState = false
    return true
  else 
    return false
  end
end

local function setDebugButtonState()
  debugButtonState = true
end


local function sendCurrentCommand()
  retryCount = retryCount + 1
  if retryCount > maxRetries then
    isBusy = false
    failedFlag = true
  end
  if currentCommand.write then
    msp.write(currentCommand.header, currentCommand.payload)
  else
    msp.read(currentCommand.header, currentCommand.payload)
  end
  nextTryTime = getTime() + retryTimeout
  print(currentCommand.text)
end


local function gotoNextCommand()
  if commandPointer < #commandSequence then
    commandPointer = commandPointer + 1
    currentCommand = commandSequence[commandPointer]
    retryCount = 0
    sendCurrentCommand()
  else
    successFlag = true
    currentCommand = nil
    isBusy = false
  end
end


function processMspReply(cmd, rx_buf)
  local key = getDebugButtonState()
  if (cmd == nil or rx_buf == nil) and not key then
    return
  end
  if isBusy and (key or (cmd == currentCommand.header)) then
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
  local cmd = {}
  cmd.header = MSP_SET_LED_STRIP
  cmd.payload = { 0, 0, 0, color*4, 0 }
  cmd.write = true
  cmd.text = "Switching LEDs"
  return cmd
end


local function prepareVtxCommand(band, channel)
  local cmd = {}
  cmd.header = MSP_VTX_SET_CONFIG
  cmd.payload = { (band-1)*8 + (channel-1), 0, 1, 0 }
  cmd.write = true
  cmd.text = "Switching VTX"
  return cmd
end


local function prepareSaveCommand()
  local cmd = {}
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
  local text = nil
  local flag = 0
  if isBusy then 
    if currentCommand then
      text = currentCommand.text .. " (" .. tostring(retryCount) .. ")"
    end
  end
  if successFlag then
    flag = 1
    successFlag = false
  end
  if failedFlag then
    flag = -1
    failedFlag = false
  end
  return text, flag
end


function comMainLoop()
  if isBusy then
    currentTime = getTime()
    if currentTime > nextTryTime then 
      sendCurrentCommand()
    end
  end
  msp.processTxQ()
  processMspReply(msp.pollReply())
end


function cancel()
  isBusy = false
end


function comBgLoop()
  if getTime() > nextRtcTime then
    nextRtcTime = getTime() + 500
    rtcCommand = prepareRtcCommand()
    msp.write(rtcCommand.header, rtcCommand.payload)
    print(rtcCommand.text)
  end
  msp.processTxQ()
  processMspReply(msp.pollReply())  
end


return { sendLedVtxConfig = sendLedVtxConfig, mainLoop = comMainLoop, getStatus=getStatus, 
  cancel=cancel, bgLoop=comBgLoop, setDebug=setDebugButtonState}
