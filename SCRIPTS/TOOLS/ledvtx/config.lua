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


local function getMenuLength(menu)
  local result = 0
  for k, v in pairs(menu) do
    if k > result then
      result = k
    end
  end
  print(result)
  return result
end


local function loadConfig(menu)
  local menuLength = getMenuLength(menu)
  local f = io.open(configPath, "r")
  if f then
    for i = 1, menuLength do
      if menu[i] then
        val = tonumber(io.read(f, 2))
        io.read(f, 1)
        menu[i].pos = checkLimits(val, #menu[i].labels)
      end
    end
  else
    for i = 1, menuLength do
      if menu[i] then
        menu[i].pos = 1
      end
    end
  end
end


local function saveConfig(menu)
  local menuLength = getMenuLength(menu)
  local f = io.open(configPath, "w")
  for i = 1, menuLength do  
    if menu[i] then
      io.write(f, string.format("%2d ", menu[i].pos))
    end
  end
  io.close(f)
end


return { save=saveConfig, load_=loadConfig } 
