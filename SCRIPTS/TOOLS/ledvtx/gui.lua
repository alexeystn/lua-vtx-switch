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
      lcd.drawRectangle(LCD_C-120, 50*(pos-1)+60, 240, 44, SOLID, 2)
    end
  end
  if isActive and isSelected then
    drawArrow(LCD_C-57-83*w, (18+32*w)*(pos-1)+13+68*w, 1)
    drawArrow(LCD_C+56+83*w, (18+32*w)*(pos-1)+13+68*w, -1) 
  end
  lcd.drawText(LCD_C-offset, (pos-1)*(18+32*w)+7+57*w, text, flags)
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


return { drawSelector = drawSelector, drawButton = drawButton }
