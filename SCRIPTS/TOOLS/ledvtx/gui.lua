local LCD_C = LCD_W / 2 + 1

local function drawArrow(arrX, arrY, dir)
  for i = 0, 4 do
    lcd.drawLine(arrX+i*dir, arrY-i, arrX+i*dir, arrY+i, SOLID, FORCE)
  end
end


local function drawSelector(pos, text, isSelected, isActive)
  local flags = 0 
  local off = math.floor(string.len(text) * 7 / 2) + 1
  if isSelected then
    flags = INVERS
    if isActive then
      drawArrow(LCD_C-57, 18*(pos-1)+13, 1) 
      drawArrow(LCD_C+56, 18*(pos-1)+13, -1) 
    end
      lcd.drawFilledRectangle(LCD_C-50, 18*(pos-1)+5 , 100, 17, SOLID)
  end
  lcd.drawText(LCD_C-off, (pos-1)*18+7 , text, flags + MIDSIZE)
end


local function drawButton(text, isSelected)
  if isSelected then
    flag = INVERS
    lcd.drawFilledRectangle(LCD_C-30, 46 , 60, 12, SOLID)
  else
    flag = 0
  end
  offset = math.floor((string.len(text)*5)/2)
  lcd.drawText(LCD_C-offset, 48, text, flag)  
end

return { drawSelector = drawSelector, drawButton = drawButton }
