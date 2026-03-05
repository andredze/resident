# Резидент

Программа выводит на экран значение всех регистров и флагов в рамке каждый тик таймера (активация/выключение рамки происходит по клавише)
с помощью резидентов для прерывания таймера и клавиатуры

Должна быть запущена на DOSBox-е

## Компиляция программы
```powershell
    makeregs.bat
```
или
```powershell
    tasm /la regs.asm
    tlink /t regs.obj
```

# Запуск программы

```powershell
    regs.com
```

Нажатие '~'   --> включить показ рамки с регистрами

Нажатие 'ESC' --> убрать показ рамки с регистрами

## Пример

Если запущена программа test.com, получаемая при компиляции следующего кода "test.asm"

Программа выставляет значение регистров:<br>
BX = 2222h<br>
CX = 3333h<br>
DX = 4444h<br>
SI = 5555h<br>
DI = 6666h<br>
BP = 7777h<br>
SP = 8888h<br>
DS = 0DEDh<br>
ES = 0DEDh<br>
SS = 0DEDh<br>
IP находится в порядке 9999h

![example](https://github.com/andredze/resident/raw/master/example.png)

# Буферизация экрана
Программа сохраняет экран, находящийся за рамкой с помощью тройной буферизации. Таким образом, рамка не стирает изменения экрана, происходящие под ней

После нажатия '~'
![pressed](https://github.com/andredze/resident/raw/master/pressed.png)

После нажатия 'ESC'
![closed](https://github.com/andredze/resident/raw/master/closed.png)
