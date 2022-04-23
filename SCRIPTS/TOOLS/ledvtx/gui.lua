local LCD_C = LCD_W / 2 + 1


local function drawArrow(x, y, dir)
  for i = 0, 4 do
    lcd.drawLine(x+i*dir, y-i, x+i*dir, y+i, SOLID, FORCE)
  end
end


local function drawSelector(pos, text, isSelected, isActive)
  local flags = 0 
  local offset = math.floor(string.len(text) * 7 / 2) + 1
  if isSelected then
    flags = INVERS
    if isActive then
      drawArrow(LCD_C-57, 18*(pos-1)+13, 1) 
      drawArrow(LCD_C+56, 18*(pos-1)+13, -1) 
    end
    lcd.drawFilledRectangle(LCD_C-50, 18*(pos-1)+5 , 100, 17, SOLID)
  end
  lcd.drawText(LCD_C-offset, (pos-1)*18+7 , text, flags + MIDSIZE)
end


local function drawButton(text, isSelected)
  local flag = 0
  local offset = math.floor((string.len(text)*5)/2)
  if isSelected then
    flag = INVERS
    lcd.drawFilledRectangle(LCD_C-30, 46 , 60, 12, SOLID)
  end
  lcd.drawText(LCD_C-offset, 48, text, flag)  
end


return { drawSelector = drawSelector, drawButton = drawButton }
