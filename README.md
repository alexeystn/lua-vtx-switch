## Lua LED & VTX Switch

Скрипт для переключения каналов видеопередатчика и цвета светодиодов с экрана аппаратуры.

![Screenshot](https://github.com/alexeystn/lua-vtx-switch/blob/master/screenshot.png?raw=true)

### Установка скрипта OpenTX

1) Скачать [zip-архив](https://github.com/alexeystn/lua-vtx-switch/archive/refs/heads/master.zip) и распаковать.
2) Скопировать содержимое папки `SCRIPTS/TOOLS` из архива в папку `SCRIPTS/TOOLS` на SD карте.
3) На аппаратуре открыть меню `TOOLS` (долгим нажатием кнопки `Menu`) и выбрать `LED & VTX setup`

<details>
  <summary> <i>Дополнительно</i> </summary>
  Для быстрого доступа к скрипту на экране телеметрии (не обязательно):
  
  1) Положить `ledvtx.lua` из папки `SCRIPTS/TELEMETRY` из архива в папку `SCRIPTS/TELEMETRY` на SD-карте.
  2) В настройках модели на странице `DISPLAY` выбрать `Script: ledvtx` для любого из экранов.  
</details>

### Настройка Betaflight

1) Настроить режим светодиодов `set ledstrip_profile = STATUS`

<details>
  <summary> <i>Рекомендуемые оттенки</i> </summary>
  
```
color 1 30,100,120
color 2 0,0,240
color 3 10,0,220
color 4 30,0,180
color 5 90,0,180
color 6 120,0,240
color 7 150,0,180
color 8 180,0,120
color 9 210,0,180
color 10 240,0,240
color 11 270,0,180
color 12 300,0,120
color 13 330,0,180
```
  
</details>
