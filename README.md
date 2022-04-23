## Lua LED & VTX Switch

Minimalistic OpenTX Lua script for switching VTX channels and LED colors.

![Screenshot](https://github.com/alexeystn/lua-vtx-switch/blob/master/screenshot.png?raw=true)

### Установка скрипта OpenTX

1) Скачать [zip-архив](https://github.com/alexeystn/lua-vtx-switch/archive/refs/heads/master.zip) со скриптами.
2) Положить содержимое папки `SCRIPTS/TOOLS` из архива в папку `SCRIPTS/TOOLS` на SD-карте аппаратуры.
3) Запустить скрипт из меню `TOOLS` на аппаратуре.

<details>
  <summary> <i>Дополнительно</i> </summary>
  Для быстрого доступа к скрипту на экране телеметрии:
  
  4) Положить `ledvtx.lua` из папки `SCRIPTS/TELEMETRY` из архива в папку `SCRIPTS/TELEMETRY` на SD-карте.
  5) В настройках модели на странице [DISPLAY] выбрать `Script: ledvtx` для любого из экранов.  
</details>

### Настройка Betaflight

1) Настроить режим светодиодов `set ledstrip_profile = STATUS`
2) Убедиться, что в VTX-таблице Band Fatshark записан под номером 4, Raceband - под номером 5 (Дополнительно: Lowband 6)
