--[[
  The following code is the part of Betaflight TX Lua Scripts:
  https://github.com/betaflight/betaflight-tx-lua-scripts
]]

    
-- Protocol version
local MSP_VERSION = bit32.lshift(1,5)
local MSP_STARTFLAG = bit32.lshift(1,4)

-- Sequence number for next MSP packet
local mspSeq = 0
local mspRemoteSeq = 0
local mspRxBuf = {}
local mspRxSize = 0
local mspRxCRC = 0
local mspRxReq = 0
local mspStarted = false
local mspLastReq = 0
local mspTxBuf = {}
local mspTxIdx = 1
local mspTxCRC = 0

local maxTxBufferSize = 8
local maxRxBufferSize = 58

function mspProcessTxQ()
    if (#(mspTxBuf) == 0) then
        return false
    end
    if not crossfireTelemetryPush() then
        return true
    end
    local payload = {}
    payload[1] = mspSeq + MSP_VERSION
    mspSeq = bit32.band(mspSeq + 1, 0x0F)
    if mspTxIdx == 1 then
        -- start flag
        payload[1] = payload[1] + MSP_STARTFLAG
    end
    local i = 2
    while (i <= maxTxBufferSize) and mspTxIdx <= #mspTxBuf do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        mspTxCRC = bit32.bxor(mspTxCRC,payload[i])  
        i = i + 1
    end
    if i <= maxTxBufferSize then
        payload[i] = mspTxCRC
        mspSend(payload)
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
        return false
    end
    mspSend(payload)
    return true
end

function mspSendRequest(cmd, payload)
    -- busy
    if #(mspTxBuf) ~= 0 or not cmd then
        return nil
    end
    mspTxBuf[1] = #(payload)
    mspTxBuf[2] = bit32.band(cmd,0xFF)  -- MSP command
    for i=1,#(payload) do
        mspTxBuf[i+2] = bit32.band(payload[i],0xFF)
    end
    mspLastReq = cmd
    return mspProcessTxQ()
end

function mspReceivedReply(payload)
    local idx = 1
    local status = payload[idx]
    local err = bit32.btest(status, 0x80)
    local version = bit32.rshift(bit32.band(status, 0x60), 5)
    local start = bit32.btest(status, 0x10)
    local seq = bit32.band(status, 0x0F)
    idx = idx + 1
    if err then
        mspStarted = false
        return nil
    end
    if start then
        mspRxBuf = {}
        mspRxSize = payload[idx]
        mspRxReq = mspLastReq
        idx = idx + 1
        if version == 1 then
            mspRxReq = payload[idx]
            idx = idx + 1
        end
        mspRxCRC = bit32.bxor(mspRxSize, mspRxReq)
        if mspRxReq == mspLastReq then
            mspStarted = true
        end
    elseif not mspStarted then
        return nil
    elseif bit32.band(mspRemoteSeq + 1, 0x0F) ~= seq then
        mspStarted = false
        return nil
    end
    while (idx <= maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        mspRxCRC = bit32.bxor(mspRxCRC, payload[idx])
        idx = idx + 1
    end
    if idx > maxRxBufferSize then
        mspRemoteSeq = seq
        return true
    end
    mspStarted = false
    -- check CRC
    if mspRxCRC ~= payload[idx] and version == 0 then
        return nil
    end
    return mspRxBuf
end

function mspPollReply()
    while true do
        local ret = mspPoll()
        if type(ret) == "table" then
            mspLastReq = 0
            return mspRxReq, ret
        else
            break
        end
    end
    return nil
end

    
-- CRSF Devices
local CRSF_ADDRESS_BETAFLIGHT          = 0xC8
local CRSF_ADDRESS_RADIO_TRANSMITTER   = 0xEA
-- CRSF Frame Types
local CRSF_FRAMETYPE_MSP_REQ           = 0x7A      -- response request using msp sequence as command
local CRSF_FRAMETYPE_MSP_RESP          = 0x7B      -- reply with 60 byte chunked binary
local CRSF_FRAMETYPE_MSP_WRITE         = 0x7C      -- write with 60 byte chunked binary 

crsfMspCmd = 0

function mspSend(payload)
    local payloadOut = { CRSF_ADDRESS_BETAFLIGHT, CRSF_ADDRESS_RADIO_TRANSMITTER }
    for i=1, #(payload) do
        payloadOut[i+2] = payload[i]
    end
    return crossfireTelemetryPush(crsfMspCmd, payloadOut)
end

function mspRead(cmd)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_REQ
    return mspSendRequest(cmd, {})
end

function mspWrite(cmd, payload)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_WRITE
    return mspSendRequest(cmd, payload)
end

function mspPoll()
    local command, data = crossfireTelemetryPop()
    if command == CRSF_FRAMETYPE_MSP_RESP then
        if data[1] == CRSF_ADDRESS_RADIO_TRANSMITTER and data[2] == CRSF_ADDRESS_BETAFLIGHT then
            local mspData = {}
            for i=3, #(data) do
                mspData[i-2] = data[i]
            end
            return mspReceivedReply(mspData)
        end
    end
    if command == 0x2B then    
      processElrsReply(data)
    end
    return nil
end




local elrsIds = { 0, 0, 0 }

function getElrsIds()
  return elrsIds
end

function processElrsReply(data)
  char1 = string.char(data[7])
  char2 = string.char(data[8])
  fieldId = data[3]
  if char1 == 'B' and char2 == 'a' then
    elrsIds[1] = fieldId
  end
  if char1 == 'C' and char2 == 'h' then
    elrsIds[2] = fieldId
  end
  if char1 == 'P' and char2 == 'w' then
    elrsIds[3] = fieldId
  end
  --  elrsFieldCounter = elrsFieldCounter + 1
  -- elrsIsBusy = 0
end



return { processTxQ = mspProcessTxQ, pollReply = mspPollReply, write = mspWrite, read = mspRead, getElrsIds = getElrsIds }
