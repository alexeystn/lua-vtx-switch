chdir("/SCRIPTS/TOOLS/LEDVTX")

local toolName = "TNS|LED & VTX setup|TNE"

local gui = assert(loadScript("gui.lua"))()
local config = assert(loadScript("config.lua"))()
local com = assert(loadScript("com.lua"))()

local ITEM_OPTS = 1
local ITEM_LED = 2
local ITEM_VTX = 3
local ITEM_SAVE = 4

local ITEM_POWER = 5
local ITEM_COUNT = 6
local ITEM_LARSON = 7
local ITEM_VERSION = 8


local IDLE=1
local BUSY=2
local DONE=3
local FAIL=4


local ledCount = 1   -- Default: 1.
local mspApiVersion = 46  -- Default: 46. Set 45 if using BF4.4 or earlier.

local colorNames = { "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Violet", "White", "Black", "   * * * *" }
local colorIds = { 2, 3, 4, 6, 8, 10, 13, 1, 0, nil }

local bandNames = { "Raceband", "Fatshark", "Lowband", "   * * * *" }
local bandIds = { 5, 4, 6, nil }

local ledColor = 1
local vtxBand = 1
local vtxChannel = 1



--local ledCount = 1
--local powerLevel = 1
--local larsonScaner = 1
--local apiVersion = 1


local menuPosition = ITEM_SAVE+1--ITEM_LED
--local menuLength = 4
local isItemActive = false
local isOptionsMenuActive = true --false


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
    if bandIds[vtxBand] == nil then
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
  if menuPosition ~= ITEM_SAVE and menuPosition ~= ITEM_VERSION then
    menuPosition = menuPosition + 1
  end
end


local function menuMoveUp()
  if menuPosition ~= 1 and menuPosition ~= ITEM_SAVE+1 then
    menuPosition = menuPosition - 1
  end
end


local function drawDisplay()
  lcd.clear()
  if isOptionsMenuActive then
    gui.drawSmallSelector(1, "Power Level", "2",   menuPosition==ITEM_POWER, isItemActive)
    gui.drawSmallSelector(2, "LED Count",   "3",   menuPosition==ITEM_COUNT, isItemActive)
    gui.drawSmallSelector(3, "Larson",      "OFF", menuPosition==ITEM_LARSON, isItemActive)
    gui.drawSmallSelector(4, "Version",     "4.5", menuPosition==ITEM_VERSION, isItemActive)
  else
    gui.drawSelector(1, colorNames[ledColor], menuPosition==ITEM_LED, isItemActive)
    if bandIds[vtxBand] then
      gui.drawSelector(2, bandNames[vtxBand] .. " " .. tostring(vtxChannel), menuPosition==ITEM_VTX, isItemActive)
    else 
      gui.drawSelector(2, bandNames[vtxBand], menuPosition==ITEM_VTX, isItemActive)
    end
    local btnText, event
    btnText, event = com.getStatus()
    btnSelected = (not btnText) and (menuPosition == ITEM_SAVE)
    if not btnText then
      if event == 1 then
        state = DONE
      elseif event == -1 then
        state = FAIL
      end
      if state == DONE then
        btnText = "Done"
      elseif state == FAIL then
        btnText = "Failed"
      else
        btnText = "Save"
      end
    else 
      state = BUSY
    end
    gui.drawOptions(menuPosition == ITEM_OPTS)
    gui.drawButton(btnText, btnSelected)
  end
  gui.drawStatus()
end


local function processEnterPress()
  if menuPosition == ITEM_OPTS then
    menuPosition = ITEM_SAVE + 1
    isOptionsMenuActive = true
    return
  end
  if menuPosition ~= ITEM_SAVE and menuPosition ~= ITEM_OPTS then
    isItemActive = not isItemActive
  else
    state = BUSY
    -- TODO: transfer full structure
    config.save(ledColor, vtxBand, vtxChannel)
    com.sendLedVtxConfig(colorIds[ledColor], bandIds[vtxBand], vtxChannel, ledCount, mspApiVersion)
  end
end


local function run_func(event) 
  print(menuPosition)
  com.mainLoop()
  if state ~= BUSY then
    if isItemActive then
      if event == EVT_ROT_RIGHT or event == EVT_PLUS_FIRST or event == EVT_PLUS_REPT then
        itemIncrease()
      end
      if event == EVT_ROT_LEFT or event == EVT_MINUS_FIRST or event == EVT_MINUS_REPT then
        itemDecrease()
      end
      if event == EVT_EXIT_BREAK then
        isItemActive = false
      end
    else 
      if event == EVT_ROT_RIGHT or event == EVT_MINUS_FIRST or event == EVT_MINUS_REPT then
        menuMoveDown()
      end
      if event == EVT_ROT_LEFT or event == EVT_PLUS_FIRST or event == EVT_PLUS_REPT then
        menuMoveUp()
      end
      if event == EVT_EXIT_BREAK then
        if isOptionsMenuActive then
          isOptionsMenuActive = false
          menuPosition = ITEM_LED
        else
          return -1
        end
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
