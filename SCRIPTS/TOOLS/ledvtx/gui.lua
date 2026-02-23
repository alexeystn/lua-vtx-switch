local LCD_C = LCD_W / 2 + 1

local w = 0  -- large screen flag
if LCD_H > 96 then w = 1 end


local function drawArrow(x, y, dir)
  for i = 0, 4+w*6 do
    lcd.drawLine(x+i*dir, y-i, x+i*dir, y+i, SOLID, 0)
  end
end


local function drawSelector(pos, text, isSelected, isActive)
  local flags = 0
  local offset = 0
  if w == 0 then
    flags = MIDSIZE 
    offset = math.floor(string.len(text) * 7 / 2) + 1
    if isSelected then
      flags = flags + INVERS
      lcd.drawFilledRectangle(LCD_C-50, 18*(pos-1)+5, 100, 17, SOLID)
    end
  else 
    flags = DBLSIZE + CENTER
    if isSelected then 
      lcd.drawRectangle(LCD_C-120, 50*(pos-1)+62, 240, 44, SOLID, 2)
    end
  end
  if isActive and isSelected then
    drawArrow(LCD_C-57-83*w, (18+32*w)*(pos-1)+13+68*w, 1)
    drawArrow(LCD_C+56+83*w, (18+32*w)*(pos-1)+13+68*w, -1) 
  end
  lcd.drawText(LCD_C-offset, (pos-1)*(18+32*w)+7+57*w, text, flags)
end


local function drawSmallSelector(pos, label, text, isSelected, isActive, offset)
  local flags = 0
  local y = 0
  if w == 0 and #label > 11 then
    label = string.sub(label, 1, 11)
  end
  if offset == nil then
    offset = 0
  end
  if w == 0 then
    y = (pos-1)*14+2
    offset = offset + (string.len(text)-1) * 3
    if isSelected then
      lcd.drawFilledRectangle(LCD_C+15, y+1, 36, 13, SOLID)
      flags = INVERS
    end
  else 
    offset = 0
    y = (pos-1)*30+60
    flags = CENTER
    if isSelected then
      lcd.drawRectangle(LCD_C+30, y, 60, 28, SOLID, 2)
    end
  end
  if isSelected and isActive then
    drawArrow(LCD_C+8+5*w, y+7 + 7*w, 1)
    drawArrow(LCD_C+57+34*w+15*w, y+7 +7*w, -1)
  end
  lcd.drawText(LCD_C-60-40*w, y+4, label)
  lcd.drawText(LCD_C+30+30*w-offset, y+4, text, flags)
end


local function drawButton(text, isSelected)
  local flags = 0
  local offset = 0
  if w == 0 then
    offset = math.floor((string.len(text)*5)/2)
    if isSelected then
      flags = INVERS
      lcd.drawFilledRectangle(LCD_C-30, 46, 60, 12, SOLID)
    end
  else
    flags = MIDSIZE + CENTER
    if isSelected then 
      lcd.drawRectangle(LCD_C-50, 169, 100, 32, SOLID, 2)
    end
  end
  lcd.drawText(LCD_C-offset, 48+122*w, text, flags) 
end


local function drawOptions(isSelected)
  local flags = 0
  if w == 0 then
    if isSelected then
      flags = ERASE
      lcd.drawFilledRectangle(0, 0, 9, 9, SOLID)
    end
    for i = 0, 2 do
      lcd.drawLine(2, 2+i*2, 6, 2+i*2, SOLID, flags)
    end
  else
    if isSelected then 
      lcd.drawRectangle(0, 0, 18, 18, SOLID, 2)
    end
    for i = 0, 2 do
      lcd.drawLine(4, 4+i*4, 13, 4+i*4, SOLID, flags)
      lcd.drawLine(4, 5+i*4, 13, 5+i*4, SOLID, flags)
    end
  end
end


local function drawStatus()
  if getRSSI() > 0 then
    if w == 0 then
      for i = 0, 3 do
        x = LCD_W + (i*2 - 7)
        lcd.drawLine(x, 7, x, 7 - i*2, SOLID, 0)
      end
    else
      for i = 0, 3 do
        x = LCD_W + (i*4 - 16)
        lcd.drawRectangle(x, 14-i*4+1, 2, i*4+2, SOLID, 1)
      end
    end
  end
end

return { drawSelector = drawSelector, drawButton = drawButton, drawStatus = drawStatus, drawOptions = drawOptions, drawSmallSelector = drawSmallSelector }
