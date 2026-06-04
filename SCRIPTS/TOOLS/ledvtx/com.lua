local msp = assert(loadScript("msp.lua"))()
local elrs = assert(loadScript("elrs.lua"))()

local VTX_MODE_MSP = 1
local VTX_MODE_ELRS = 2

local MSP_VTX_SET_CONFIG = 89
local MSP_EEPROM_WRITE = 250
local MSP_SET_LED_STRIP = 49

local isBusy = false
local retryCount = 0
local maxRetries = 4
local retryTimeout = 200
local nextTryTime = 0

local successFlag = false
local failedFlag = false
local transactionActive = false
local mspResult = 1
local elrsResult = 1
local pendingMspCommands = nil

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
    mspResult = -1
    failedFlag = true
    return
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
    mspResult = 1
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


local function prepareLedCommand(color, n, larson, version)
  local cmd = {}
  cmd.header = MSP_SET_LED_STRIP
  -- check offsets in 'src/main/io/ledstrip.h'
  if version == 0 then -- BF 4.5+
    cmd.payload = { n-1, (n-1)*16, 64*larson, bit32.lshift(bit32.band(color, 0x03), 6), bit32.rshift(color, 2)}
  else  -- BF 4.4-
    cmd.payload = { n-1, (n-1)*16, 0, color*4, 0 }
  end 
  cmd.write = true
  cmd.text = "Switching LED " .. tostring(n)
  return cmd
end


local function prepareVtxCommand(band, channel, power)
  local cmd = {}
  cmd.header = MSP_VTX_SET_CONFIG
  cmd.payload = { (band-1)*8 + (channel-1), 0, power, 0 }
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


local function sendLedVtxConfig(args)
  retryCount = 0
  transactionActive = true
  mspResult = (args.color or (args.band and args.vtxMode == VTX_MODE_MSP)) and 0 or 1
  elrsResult = (args.band and args.vtxMode == VTX_MODE_ELRS) and 0 or 1
  pendingMspCommands = nil
  print('Config')
  print('VTX:', args.band, args.channel)
  print('LED:', args.color, args.count, args.larson)
  print('API:', args.version)
  print('VTX mode:', args.vtxMode)

  local cmd = {}
  if args.band and args.vtxMode == VTX_MODE_ELRS then
    -- VTX config goes to the ELRS TX module; it forwards the change itself.
    elrs.sendVtxConfig(args)
  elseif args.band then
    -- Original path: write VTX directly to Betaflight over MSP.
    cmd[#cmd+1] = prepareVtxCommand(args.band, args.channel, args.power)
  end
  if args.color then
    for i = 1, args.count do
      cmd[#cmd+1] = prepareLedCommand(args.color, i, args.larson, args.version)
    end
  end
  if #cmd > 0 then
    cmd[#cmd+1] = prepareSaveCommand()
  end
  if #cmd > 0 then
    pendingMspCommands = cmd
    if args.vtxMode ~= VTX_MODE_ELRS or not args.band then
      startTransmission(pendingMspCommands)
      pendingMspCommands = nil
    end
  end
end  


local function getStatus()
  local text = nil
  local flag = 0
  local elrsText, elrsEvent = elrs.getStatus()
  if isBusy then 
    if currentCommand then
      text = currentCommand.text .. " (" .. tostring(retryCount) .. ")"
    end
  elseif elrsText then
    text = elrsText
  end

  if elrsEvent ~= 0 then
    elrsResult = elrsEvent
  end
  if failedFlag or mspResult < 0 or elrsResult < 0 then
    flag = -1
    failedFlag = false
    successFlag = false
    transactionActive = false
  elseif transactionActive and mspResult > 0 and elrsResult > 0 then
    flag = 1
    successFlag = false
    transactionActive = false
  elseif successFlag then
    successFlag = false
  end
  return text, flag
end


function comMainLoop(vtxMode)
  if isBusy then
    currentTime = getTime()
    if currentTime > nextTryTime then 
      sendCurrentCommand()
    end
    msp.processTxQ()
    processMspReply(msp.pollReply())
  elseif elrs.isBusy() then
    -- Keep pumping ELRS telemetry while it resolves discovery/read/write.
    elrs.mainLoop()
  else
    -- LED MSP commands stay on the existing Betaflight path.
    if vtxMode == VTX_MODE_ELRS then
      elrs.mainLoop()
    end
    if pendingMspCommands then
      startTransmission(pendingMspCommands)
      pendingMspCommands = nil
    end
  end
end


function cancel()
  isBusy = false
  pendingMspCommands = nil
  transactionActive = false
end


return { sendLedVtxConfig = sendLedVtxConfig, mainLoop = comMainLoop, getStatus=getStatus, 
  cancel=cancel, setDebug=setDebugButtonState, getVtxConfig=elrs.getVtxConfig}
