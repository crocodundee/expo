/*
 * Таймер экспозиции фоторезиста
 * Для AVR: ATtiny2313
 * Частота контроллера:4 МГц (внеш.кварц)
 * Вывод времени на 4-разрядный семисегментный индикатор с общим катодом,
 * управление одной кнопкой
 */

.include "2313def.inc"

.def tmp = r16    //регистр временных данных
.def dig0 = r17    //символ 0-го разряда индикатора
.def dig1 = r18    //символ 1-го р.
.def dig2 = r19    //символ 2-го р.
.def dig3 = r20    //символ 3-го р.
.def adrL = r21    //адрес EEPROM мл. разряда числа
.def adrH = r22    //ст. разряд числа
.def seconds = r23    //секунды
.def minutes = r24    //минуты
.def event = r25    //регистр флагов событий
.def delay = r26    //счетчик времени нажатия на кнопку

.equ UF = 1    //нагрузка
//биты управления разрядами индикатора
.equ SEG0 = 3
.equ SEG1 = 4
.equ SEG2 = 5
.equ SEG3 = 6
.equ DP = 7

//Флаги событий
.equ TURN = 0x01    //настройка таймера
.equ DOWN = 0x03    //кнопка нажата
.equ LONG = 0x07    //длинное нажатие кнопки

.equ TCH = 0xF0    //константа загружаемая в TCNT1H
.equ TCL = 0xBE    //константа загружаемая в TCNT1L

.equ T0 = 0xD9    //константа загружаемая в TCNT0
.equ CK = 0x05    //пределитель 1024

.equ RISE = 0x03    //по фронту (отжатие кнопки)
.equ FALL = 0x02    //по срезу (нажатие кнопки)

// Сегмент данных EEPROM
.eseg
.org 0

Digit: .db 0xC0 , 0xF9 , 0xA4 , 0xB0 , 0x99 , 0x92 , 0x82 , 0xF8 , 0x00 , 0x90 , 0xFF , 0x3F
//         -0-    -1-    -2-    -3-    -4-    -5-    -6-    -7-    -8-    -9-    -  -   " - "

//Программа
.cseg
.org 0 rjmp Init
.org 0x0001 rjmp Control
.org 0x0005 rjmp Timer
.org 0x0006 rjmp Display

Init:
    ldi tmp, RAMEND
    out SPL, tmp
    //настройка портов
    ldi tmp , 0xFF
    out DDRB , tmp
	ldi tmp, 0x00
	out PORTB, tmp
    ldi tmp , 0b01111010
    out DDRD , tmp
    ldi tmp , 0b01111100
    out PORTD , tmp
    //настройка таймера-счетчика0
    ldi tmp , CK
    out TCCR0 , tmp
    ldi tmp , T0
    out TCNT0 , tmp
    ldi tmp , (1 << TOIE0)|(0 << TOIE1)
    out TIMSK , tmp
    //настройка внешнего прерывания
    ldi tmp , FALL
    out MCUCR ,tmp
    ldi tmp , (1 << INT0)
    out GIMSK , tmp
    sei
    //Стартовые настройки
    rcall HelloUser
    //главный цикл программы
Main:
    rjmp Main


/*
 * Display
 * Обработчик прерывания таймера-счетчика-0 
 * по событию переполнения счетного регистра
 * Организация временной задержки в 10 мл.сек.
 * Динамическая индикация и обработка нажатия кнопки
 * Вывод времени в формате "MM.SS"
 */
Display:
    ldi tmp , T0
    out TCNT0 , tmp

    cpi event , DOWN    //если была нажата кнопка
    brne DynInd
    inc delay    //начать подсчет времени нажатия
    cpi delay , 200    //если кнопка нажата в течении 2 секунд
    brlo DynInd
    ldi event , LONG    //включить таймер, подключить нагрузку

//динамическая индикация
DynInd:
    sbic PORTD , SEG0    //если установлен 0-й разряд
    rjmp SetSeg1
    sbi PORTD , SEG0    //сбросить 0-й
    cbi PORTD , SEG1    //установить 1-й
    out PORTB , dig1    //вывести значение 1-го разряда
    //cbi PORTB , DP
    rjmp End    //закончить вывод
SetSeg1:
    sbic PORTD , SEG1    //если установлен 1-й
    rjmp SetSeg0
    sbi PORTD , SEG1    //сброс 1-го
    cbi PORTD , SEG2    //установить 2-й
    out PORTB , dig2    //вывести значение 2-го разряда
    cpi event , TURN    //если ждем настройки
    brne ClrDp
    sbi PORTB , DP    //погасить точку для стартового вывода
    rjmp End
ClrDp:
    cbi PORTB , DP    //иначе установить точку
    rjmp End    //закончить вывод
SetSeg0:    //иначе установлен 2-й
    sbic PORTD , SEG2
    rjmp SetSeg3
    sbi PORTD , SEG2    //сбросить 2-й
    cbi PORTD , SEG3    //установить 3-й
    out PORTB , dig3    //вывести значение 3-го разряда
    //sbi PORTB , DP
    rjmp End
SetSeg3:
    sbi PORTD , SEG3    //иначе сбросить 3-й
    cbi PORTD , SEG0    //установить 1-й
    out PORTB , dig0    //вывести значение 0-го разряда
    //sbi PORTB , DP
End:    //закончить вывод
    reti    //выход из обработчика


/*
 * Control
 * Обработчик внешнего прерывания INT0
 * Настройка и управление таймером
 */
Control:
//контроль нажатия
    cpi event , LONG    //если кнопка была нажата длинно
    breq StartTimer    //запуск таймера

    cpi event , DOWN    //если кнопка нажата
    breq Config    //перейти к настройке
    ldi event , DOWN    //иначе поднять флаг "кнопка нажата"
    ldi tmp , RISE    //ждем, когда пользователь ее отпустит
    out MCUCR , tmp
    rjmp WaitUp
//обработка нажатой кнопки
Config:
    clr event    //сброс флагов
    subi seconds , -20    //увеличть колличество секунд с шагом 20
    cpi seconds , 60    //если не достигли 60
    breq SetMin
    rjmp EndControl    //вывести текущее значение времени
SetMin:    //иначе перейти к настройке минут
    ldi seconds , 0    //сброс секунд
    inc minutes    //увеличить колличество минут
    cpi minutes , 10    //если не достигли максимального значения времени
    brne EndControl    //вывести текущее значение
    rcall GetMinutes    //иначе вывод максимального значения
    ldi minutes , 0    //сброс минут
    rjmp DispSec    //вывод секунд
//запуск таймера
StartTimer:
    ldi tmp , TCH
    out TCNT1H , tmp
    ldi tmp , TCL
    out TCNT1L , tmp
    ldi tmp , (1 << TOIE1)|(1 << TOIE0)
    out TIMSK , tmp
    ldi tmp , CK
    out TCCR1B , tmp    //запустить обратный отсчет
    ldi tmp , (0 << INT0)    //заблокировать кнопку
    out GIMSK , tmp
    sbi PORTD , UF    //подключить нагрузку
EndControl:
    rcall GetMinutes    //вывод на индикатор
DispSec:
    rcall GetSeconds
    ldi tmp , FALL    //закончить настроку
    out MCUCR , tmp    //ждем следующего нажатия
WaitUp:
    clr delay
    reti    //выход из обработчика

/*
 * Timer
 * Обработчик прерывания таймера-счетчика-1 
 * по событию переполнения счетного регистра
 * Организация временной задержки в 1 сек. и обратного отсчета
 */
Timer:
    ldi tmp , TCH
    out TCNT1H , tmp
    ldi tmp , TCL
    out TCNT1L , tmp
//обратный отсчет
    cpi seconds , 0    //если установлено 0 секунд
    breq DecMin    //перейти к проверке минут
    dec seconds    //иначе уменьшить число секунд
    rcall GetSeconds    //вывод на индикатор
    reti    //выход из обработчика
DecMin:
    cpi minutes , 0    //если закончили отсчет времени
    breq StopTimer    //закончить работу таймера
    dec minutes    //иначе уменьшить число минут
    ldi seconds , 59    //переход через 0
    rcall GetMinutes    //вывод времени
    rcall GetSeconds    //на инжикатор
    reti    //выод из обработчика
//конец работы таймера
StopTimer:
    ldi tmp , (0 << TOIE1)|(1 << TOIE0)    //запретить работу таймера-счетчика1
    out TIMSK , tmp
    ldi tmp , (1 << INTF0)    //сброс флага внешнего прерывания INT0
    out GIFR , tmp
    ldi tmp , (1 << INT0)    //разблокировать кнопку
    out GIMSK , tmp
    cbi PORTD , UF    //отключить нагрузку
    rcall HelloUser    //вернуться к стартовым настройкам
    reti    //выход из обработчика


/*
 * GetMinutes
 * Подрограмма получения символьного представления 
 * текущего колличества минут
 */
GetMinutes:
    mov tmp , minutes
    rcall DevideNumber
    mov tmp , adrL
    rcall ReadEEPROM
    mov dig2 , tmp
    cpi adrH , 0    //если число меньше 10
    brne ReadDig3    //погасить старший разряд
    ldi adrH , 10
ReadDig3:
    mov tmp , adrH
    rcall ReadEEPROM
    mov dig3 , tmp
    ret


/*
 * GetSeconds
 * Подрограмма получения символьного представления 
 * текущего колличества секунд
 */
GetSeconds:
    mov tmp , seconds
    rcall DevideNumber
    mov tmp , adrL
    rcall ReadEEPROM
    mov dig0 , tmp
    mov tmp , adrH
    rcall ReadEEPROM
    mov dig1 , tmp
    ret


/*
 * DevideNumber
 * Подпрограмма деления числа на разряды
 */
DevideNumber:
    clr adrH    //сброс счетчика десятков
    mov adrL , tmp    //сохранить цисло
Devide:
    cpi adrL , 10    //если число меньше 10
    brmi Stop    //закончить деление
    subi adrL , 10    //иначе вчесть 10
    inc adrH    //увеличить счетчик десятков
    rjmp Devide    //продолжить деление
Stop:
    ret    //выход из подпрограммы


/*
 * HelloUser
 * Подпрограмма установки стартовых настроек
 */
HelloUser:
    ldi seconds , 0
    ldi minutes , 1

    ldi tmp , 11    //вывод " - - - - "
    rcall ReadEEPROM
    mov dig0 , tmp
    mov dig1 , tmp
    mov dig2 , tmp
    mov dig3 , tmp
    ldi event , TURN    //погасить точку
    ret    //выход из подпрограммы


/*
 * ReadEEPROM
 * Подпрограмма чтения данных из EEPROM
 */
ReadEEPROM:
    out EEARL , tmp    //задать адресс символа
    sbi EECR , EERE    //разрешить чтение
    in tmp , EEDR    //забрать значение ячейки
    ret    //выход из подпрограммы

