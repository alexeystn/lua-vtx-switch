local configPath = "config.txt"


local function checkLimits(value, maxValue)
  if not value then
    return 1
  elseif value > maxValue then
    return maxValue
  elseif value < 1 then
    return 1
  else
    return value
  end
end


local function loadConfig(colorsCount, bandsCount)
  local f = io.open(configPath, "r")
  if f then
    local savedColor = tonumber(io.read(f, 2))
    io.read(f, 1)
    local savedBand = tonumber(io.read(f, 1))
    io.read(f, 1)
    local savedChannel = tonumber(io.read(f, 1))
    savedColor = checkLimits(savedColor, colorsCount)
    savedBand = checkLimits(savedBand, bandsCount)
    savedChannel = checkLimits(savedChannel, 8)
    return savedColor, savedBand, savedChannel
  end
  return 1, 1, 1
end


local function saveConfig(color, band, channel)
  local f = io.open(configPath, "w")
  io.write(f, string.format("%2d %1d %1d",color, band, channel))
  io.close(f)
end


return { save=saveConfig, load_=loadConfig } 
