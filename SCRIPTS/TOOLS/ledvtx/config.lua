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


local function loadConfig(limits)

  local f = io.open(configPath, "r")
  local result = {}
  if f then
    for i = 1, #limits do 
      val = tonumber(io.read(f, 2))
      io.read(f, 1)
      val = checkLimits(val, limits[i])
      result[#result+1] = val
    end
  else
    for i = 1, #limits do 
      result[#result+1] = 1
    end
  end
  return result
end


local function saveConfig(menu)
  local f = io.open(configPath, "w")
  for i = 1, 10 do  -- TODO: check max menu id
    if menu[i] then
      io.write(f, string.format("%2d ", menu[i].pos))
    end
  end
  io.close(f)
end


return { save=saveConfig, load_=loadConfig } 
