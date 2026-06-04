local CRSF_ADDRESS_TX_MODULE = 0xEE
local CRSF_ADDRESS_HANDSET = 0xEF
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA

local CRSF_FRAMETYPE_DEVICE_PING = 0x28
local CRSF_FRAMETYPE_DEVICE_INFO = 0x29
local CRSF_FRAMETYPE_PARAMETER_READ = 0x2C
local CRSF_FRAMETYPE_PARAMETER_WRITE = 0x2D
local CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY = 0x2B

local TYPE_UINT8 = 0
local TYPE_TEXT_SELECTION = 9

local fallbackFieldIds = {
  band = 11,
  channel = 12,
  power = 13,
  send = 15
}

local fieldIds = {
  band = fallbackFieldIds.band,
  channel = fallbackFieldIds.channel,
  power = fallbackFieldIds.power,
  send = fallbackFieldIds.send
}

local fields = {}
local readQueue = {}
local writeQueue = {}
local nextPushTime = 0
local nextDiscoveryTime = 0
local statusText = nil
local doneFlag = false
local failFlag = false
local configVersion = 0
local txFound = false
local fieldsCount = 0
local fieldScanStarted = false
local pendingVtxArgs = nil


local function getValue(data, offset, size)
  local result = 0
  for i = 0, size-1 do
    result = bit32.lshift(result, 8) + data[offset+i]
  end
  return result
end


local function getString(data, offset, isOptions)
  local result = isOptions and {} or ""
  local option = ""
  local b = 0
  repeat
    b = data[offset]
    offset = offset + 1
    if isOptions then
      if b == 59 or b == 0 then
        result[#result+1] = option
        option = ""
      else
        option = option .. string.char(b)
      end
    else
      if b ~= 0 then
        result = result .. string.char(b)
      end
    end
  until b == 0
  return result, offset
end


local function parseDeviceInfo(data)
  local id = data[2]
  if id ~= CRSF_ADDRESS_TX_MODULE then
    return
  end

  -- Discovery confirms the ELRS TX module before we touch its parameter tree.
  local _, offset = getString(data, 3, false)
  if getValue(data, offset, 4) ~= 0x454C5253 then
    return
  end

  fieldsCount = data[offset+12]
  txFound = true
end


local function fieldMatches(field, name)
  return field and field.name == name
end


local function applyKnownField(field)
  if fieldMatches(field, "Band/Enable") or fieldMatches(field, "Band") then
    fieldIds.band = field.id
  elseif fieldMatches(field, "Channel") then
    fieldIds.channel = field.id
  elseif fieldMatches(field, "Pwr Lvl") then
    fieldIds.power = field.id
  elseif fieldMatches(field, "Send VTx") or fieldMatches(field, "Send VTX") then
    fieldIds.send = field.id
  end
end


local function parseParameter(data)
  if data[2] ~= CRSF_ADDRESS_TX_MODULE then
    return
  end

  local id = data[3]
  local chunksRemain = data[4]
  if chunksRemain ~= 0 or #data < 8 then
    return
  end

  local offset = 5
  local field = { id = id }
  field.parent = data[offset]
  field.type = bit32.band(data[offset+1], 0x7f)
  field.name, offset = getString(data, offset+2, false)

  if field.type == TYPE_UINT8 then
    field.value = getValue(data, offset, 1)
    field.min = getValue(data, offset+1, 1)
    field.max = getValue(data, offset+2, 1)
  elseif field.type == TYPE_TEXT_SELECTION then
    field.values, offset = getString(data, offset, true)
    field.value = data[offset]
  end

  fields[id] = field
  applyKnownField(field)

  if id == fieldIds.band or id == fieldIds.channel or id == fieldIds.power then
    configVersion = configVersion + 1
  end
end


local function queueRead(id)
  readQueue[#readQueue+1] = id
end


local function discoverFields()
  if fieldScanStarted or not txFound then
    return
  end
  fieldScanStarted = true
  for id = 1, fieldsCount do
    queueRead(id)
  end
end


local function queueWrite(id, value)
  writeQueue[#writeQueue+1] = { id = id, value = value }
end


local function sendVtxConfig(args)
  doneFlag = false
  failFlag = false
  pendingVtxArgs = args
  statusText = txFound and "Reading VTX" or "Finding TX"
end


local function pushPendingVtxConfig()
  if not pendingVtxArgs or not txFound or #readQueue > 0 then
    return false
  end

  -- Send the final VTX write to the TX module; it handles the downstream update.
  queueWrite(fieldIds.band or fallbackFieldIds.band, pendingVtxArgs.band)
  queueWrite(fieldIds.channel or fallbackFieldIds.channel, pendingVtxArgs.channel)
  if pendingVtxArgs.power then
    queueWrite(fieldIds.power or fallbackFieldIds.power, pendingVtxArgs.power)
  end
  queueWrite(fieldIds.send or fallbackFieldIds.send, 1)
  pendingVtxArgs = nil
  statusText = "Switching VTX"
  return true
end


local function mainLoop()
  local command, data
  repeat
    command, data = crossfireTelemetryPop()
    if command == CRSF_FRAMETYPE_DEVICE_INFO then
      parseDeviceInfo(data)
    elseif command == CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY then
      parseParameter(data)
    end
  until command == nil

  local now = getTime()
  if now < nextPushTime then
    return
  end

  if not txFound then
    if now > nextDiscoveryTime then
      crossfireTelemetryPush(CRSF_FRAMETYPE_DEVICE_PING, { 0x00, CRSF_ADDRESS_RADIO_TRANSMITTER })
      nextDiscoveryTime = now + 100
    end
    return
  end

  discoverFields()

  if pushPendingVtxConfig() then
    return
  end

  if #writeQueue > 0 then
    local item = table.remove(writeQueue, 1)
    crossfireTelemetryPush(CRSF_FRAMETYPE_PARAMETER_WRITE,
      { CRSF_ADDRESS_TX_MODULE, CRSF_ADDRESS_HANDSET, item.id, item.value })
    nextPushTime = now + 5
    if #writeQueue == 0 then
      doneFlag = true
      statusText = nil
      queueRead(fieldIds.band)
      queueRead(fieldIds.channel)
      queueRead(fieldIds.power)
    end
    return
  end

  if #readQueue > 0 then
    local id = table.remove(readQueue, 1)
    if id then
      crossfireTelemetryPush(CRSF_FRAMETYPE_PARAMETER_READ,
        { CRSF_ADDRESS_TX_MODULE, CRSF_ADDRESS_HANDSET, id, 0 })
      nextPushTime = now + 5
    end
  end
end


local function isBusy()
  return #writeQueue > 0 or pendingVtxArgs ~= nil or statusText ~= nil
end


local function getStatus()
  local event = 0
  if doneFlag then
    event = 1
    doneFlag = false
  elseif failFlag then
    event = -1
    failFlag = false
  end
  return statusText, event
end


local function getVtxConfig()
  local band = fields[fieldIds.band]
  local channel = fields[fieldIds.channel]
  local power = fields[fieldIds.power]

  if not band or not channel then
    return nil
  end

  return {
    version = configVersion,
    band = band.value,
    channel = channel.value,
    power = power and power.value or nil
  }
end


return {
  mainLoop = mainLoop,
  sendVtxConfig = sendVtxConfig,
  getStatus = getStatus,
  getVtxConfig = getVtxConfig,
  isBusy = isBusy
}
