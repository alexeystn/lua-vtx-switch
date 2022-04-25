chdir("/SCRIPTS/TOOLS/LEDVTX")

local toolName = "TNS|LED & VTX setup|TNE"

local gui = assert(loadScript("gui.lua"))()
local config = assert(loadScript("config.lua"))()
local com = assert(loadScript("com.lua"))()
assert(loadScript("ledcount.lua"))()

local colorNames = { "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Violet", "White", "Black" }
local colorIds = { 2, 3, 4, 6, 8, 10, 13, 1, 0 }

local bandNames = { "Raceband", "Fatshark", "Lowband" }
local bandIds = { 5, 4, 6 }

local ledColor = 1
local vtxBand = 1
local vtxChannel = 1

local menuPosition = 1
local menuLength = 3
local isItemActive = false

local ITEM_LED = 1
local ITEM_VTX = 2
local ITEM_SAVE = 3

local IDLE=1
local BUSY=2
local DONE=3
local FAIL=4

local state = IDLE


local function itemIncrease()
  if menuPosition == ITEM_LED then 
    if ledColor < #colorNames then
      ledColor = ledColor + 1
    end
  end
  if menuPosition == ITEM_VTX then
    if vtxChannel < 8 then
      vtxChannel = vtxChannel + 1
    elseif vtxBand < #bandNames then
      vtxBand = vtxBand + 1
      vtxChannel = 1
    end
  end
end


local function itemDecrease()
  if menuPosition == ITEM_LED then 
    if ledColor > 1 then
      ledColor = ledColor - 1
    end
  end
  if menuPosition == ITEM_VTX then
    if vtxChannel > 1 then
      vtxChannel = vtxChannel - 1
    elseif vtxBand > 1 then
      vtxBand = vtxBand - 1
      vtxChannel = 8
    end
  end
end


local function menuMoveDown()
  if menuPosition < menuLength then
    menuPosition = menuPosition + 1
  end
end


local function menuMoveUp()
  if menuPosition > 1 then
    menuPosition = menuPosition - 1
  end
end


local function drawDisplay()
  lcd.clear()
  gui.drawSelector(1, colorNames[ledColor], menuPosition==1, isItemActive)
  gui.drawSelector(2, bandNames[vtxBand] .. " " .. tostring(vtxChannel), menuPosition==2, isItemActive)
  local text, event
  text, event = com.getStatus()
  sel = (not text) and (menuPosition == ITEM_SAVE)
  if not text then
    if event == 1 then
      state = DONE
    elseif event == -1 then
      state = FAIL
    end
    if state == DONE then
      text = "Done"
    elseif state == FAIL then
      text = "Failed"
    else
      text = "Save"
    end
  else 
    state = BUSY
  end
  gui.drawButton(text, sel)
end


local function processEnterPress()
  if menuPosition < menuLength then
    isItemActive = not isItemActive
  else
    state = BUSY
    config.save(ledColor, vtxBand, vtxChannel)
    com.sendLedVtxConfig(colorIds[ledColor], bandIds[vtxBand], vtxChannel, ledCount)
  end
end


local function run_func(event) 
  com.mainLoop()
  if event == EVT_PLUS_BREAK then
    event = EVT_ROT_RIGHT
  end
  if event == EVT_MINUS_BREAK then
    event = EVT_ROT_LEFT
  end    
  if state ~= BUSY then
    if event == EVT_ROT_RIGHT then
      if isItemActive then
        itemIncrease()
      else
        menuMoveDown()
      end
    end
    if event == EVT_ROT_LEFT then
      if isItemActive then
        itemDecrease()
      else
        menuMoveUp()
      end
    end  
  end  
  if event == EVT_ENTER_BREAK then
    processEnterPress()
  end
  if event == EVT_MENU_BREAK then
    com.setDebug()
  end
  if event == EVT_EXIT_BREAK then
    com.cancel()
    state = IDLE
  end  
  if ((state == DONE) or (state == FAIL)) and (event == EVT_ROT_LEFT or event == EVT_ROT_RIGHT) then 
    state = IDLE
  end
  drawDisplay()
  return 0
end


local function bg_func()
  com.bgLoop()
end


local function init_func()
  ledColor, vtxBand, vtxChannel = config.load_(#colorNames, #bandNames)
end


return { run=run_func, background=bg_func, init=init_func}
