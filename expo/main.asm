/*
 * ������ ���������� �����������
 * ��� AVR: ATtiny2313
 * ������� �����������:4 ��� (����.�����)
 * ����� ������� �� 4-��������� �������������� ��������� � ����� �������,
 * ���������� ����� �������
 */

.include "2313def.inc"

.def tmp = r16    //������� ��������� ������
.def dig0 = r17    //������ 0-�� ������� ����������
.def dig1 = r18    //������ 1-�� �.
.def dig2 = r19    //������ 2-�� �.
.def dig3 = r20    //������ 3-�� �.
.def adrL = r21    //����� EEPROM ��. ������� �����
.def adrH = r22    //��. ������ �����
.def seconds = r23    //�������
.def minutes = r24    //������
.def event = r25    //������� ������ �������
.def delay = r26    //������� ������� ������� �� ������

.equ UF = 1    //��������
//���� ���������� ��������� ����������
.equ SEG0 = 3
.equ SEG1 = 4
.equ SEG2 = 5
.equ SEG3 = 6
.equ DP = 7

//����� �������
.equ TURN = 0x01    //��������� �������
.equ DOWN = 0x03    //������ ������
.equ LONG = 0x07    //������� ������� ������

.equ TCH = 0xF0    //��������� ����������� � TCNT1H
.equ TCL = 0xBE    //��������� ����������� � TCNT1L

.equ T0 = 0xD9    //��������� ����������� � TCNT0
.equ CK = 0x05    //����������� 1024

.equ RISE = 0x03    //�� ������ (������� ������)
.equ FALL = 0x02    //�� ����� (������� ������)

// ������� ������ EEPROM
.eseg
.org 0

Digit: .db 0xC0 , 0xF9 , 0xA4 , 0xB0 , 0x99 , 0x92 , 0x82 , 0xF8 , 0x00 , 0x90 , 0xFF , 0x3F
//         -0-    -1-    -2-    -3-    -4-    -5-    -6-    -7-    -8-    -9-    -  -   " - "

//���������
.cseg
.org 0 rjmp Init
.org 0x0001 rjmp Control
.org 0x0005 rjmp Timer
.org 0x0006 rjmp Display

Init:
    ldi tmp, RAMEND
    out SPL, tmp
    //��������� ������
    ldi tmp , 0xFF
    out DDRB , tmp
	ldi tmp, 0x00
	out PORTB, tmp
    ldi tmp , 0b01111010
    out DDRD , tmp
    ldi tmp , 0b01111100
    out PORTD , tmp
    //��������� �������-��������0
    ldi tmp , CK
    out TCCR0 , tmp
    ldi tmp , T0
    out TCNT0 , tmp
    ldi tmp , (1 << TOIE0)|(0 << TOIE1)
    out TIMSK , tmp
    //��������� �������� ����������
    ldi tmp , FALL
    out MCUCR ,tmp
    ldi tmp , (1 << INT0)
    out GIMSK , tmp
    sei
    //��������� ���������
    rcall HelloUser
    //������� ���� ���������
Main:
    rjmp Main


/*
 * Display
 * ���������� ���������� �������-��������-0 
 * �� ������� ������������ �������� ��������
 * ����������� ��������� �������� � 10 ��.���.
 * ������������ ��������� � ��������� ������� ������
 * ����� ������� � ������� "MM.SS"
 */
Display:
    ldi tmp , T0
    out TCNT0 , tmp

    cpi event , DOWN    //���� ���� ������ ������
    brne DynInd
    inc delay    //������ ������� ������� �������
    cpi delay , 200    //���� ������ ������ � ������� 2 ������
    brlo DynInd
    ldi event , LONG    //�������� ������, ���������� ��������

//������������ ���������
DynInd:
    sbic PORTD , SEG0    //���� ���������� 0-� ������
    rjmp SetSeg1
    sbi PORTD , SEG0    //�������� 0-�
    cbi PORTD , SEG1    //���������� 1-�
    out PORTB , dig1    //������� �������� 1-�� �������
    //cbi PORTB , DP
    rjmp End    //��������� �����
SetSeg1:
    sbic PORTD , SEG1    //���� ���������� 1-�
    rjmp SetSeg0
    sbi PORTD , SEG1    //����� 1-��
    cbi PORTD , SEG2    //���������� 2-�
    out PORTB , dig2    //������� �������� 2-�� �������
    cpi event , TURN    //���� ���� ���������
    brne ClrDp
    sbi PORTB , DP    //�������� ����� ��� ���������� ������
    rjmp End
ClrDp:
    cbi PORTB , DP    //����� ���������� �����
    rjmp End    //��������� �����
SetSeg0:    //����� ���������� 2-�
    sbic PORTD , SEG2
    rjmp SetSeg3
    sbi PORTD , SEG2    //�������� 2-�
    cbi PORTD , SEG3    //���������� 3-�
    out PORTB , dig3    //������� �������� 3-�� �������
    //sbi PORTB , DP
    rjmp End
SetSeg3:
    sbi PORTD , SEG3    //����� �������� 3-�
    cbi PORTD , SEG0    //���������� 1-�
    out PORTB , dig0    //������� �������� 0-�� �������
    //sbi PORTB , DP
End:    //��������� �����
    reti    //����� �� �����������


/*
 * Control
 * ���������� �������� ���������� INT0
 * ��������� � ���������� ��������
 */
Control:
//�������� �������
    cpi event , LONG    //���� ������ ���� ������ ������
    breq StartTimer    //������ �������

    cpi event , DOWN    //���� ������ ������
    breq Config    //������� � ���������
    ldi event , DOWN    //����� ������� ���� "������ ������"
    ldi tmp , RISE    //����, ����� ������������ �� ��������
    out MCUCR , tmp
    rjmp WaitUp
//��������� ������� ������
Config:
    clr event    //����� ������
    subi seconds , -20    //�������� ����������� ������ � ����� 20
    cpi seconds , 60    //���� �� �������� 60
    breq SetMin
    rjmp EndControl    //������� ������� �������� �������
SetMin:    //����� ������� � ��������� �����
    ldi seconds , 0    //����� ������
    inc minutes    //��������� ����������� �����
    cpi minutes , 10    //���� �� �������� ������������� �������� �������
    brne EndControl    //������� ������� ��������
    rcall GetMinutes    //����� ����� ������������� ��������
    ldi minutes , 0    //����� �����
    rjmp DispSec    //����� ������
//������ �������
StartTimer:
    ldi tmp , TCH
    out TCNT1H , tmp
    ldi tmp , TCL
    out TCNT1L , tmp
    ldi tmp , (1 << TOIE1)|(1 << TOIE0)
    out TIMSK , tmp
    ldi tmp , CK
    out TCCR1B , tmp    //��������� �������� ������
    ldi tmp , (0 << INT0)    //������������� ������
    out GIMSK , tmp
    sbi PORTD , UF    //���������� ��������
EndControl:
    rcall GetMinutes    //����� �� ���������
DispSec:
    rcall GetSeconds
    ldi tmp , FALL    //��������� ��������
    out MCUCR , tmp    //���� ���������� �������
WaitUp:
    clr delay
    reti    //����� �� �����������

/*
 * Timer
 * ���������� ���������� �������-��������-1 
 * �� ������� ������������ �������� ��������
 * ����������� ��������� �������� � 1 ���. � ��������� �������
 */
Timer:
    ldi tmp , TCH
    out TCNT1H , tmp
    ldi tmp , TCL
    out TCNT1L , tmp
//�������� ������
    cpi seconds , 0    //���� ����������� 0 ������
    breq DecMin    //������� � �������� �����
    dec seconds    //����� ��������� ����� ������
    rcall GetSeconds    //����� �� ���������
    reti    //����� �� �����������
DecMin:
    cpi minutes , 0    //���� ��������� ������ �������
    breq StopTimer    //��������� ������ �������
    dec minutes    //����� ��������� ����� �����
    ldi seconds , 59    //������� ����� 0
    rcall GetMinutes    //����� �������
    rcall GetSeconds    //�� ���������
    reti    //���� �� �����������
//����� ������ �������
StopTimer:
    ldi tmp , (0 << TOIE1)|(1 << TOIE0)    //��������� ������ �������-��������1
    out TIMSK , tmp
    ldi tmp , (1 << INTF0)    //����� ����� �������� ���������� INT0
    out GIFR , tmp
    ldi tmp , (1 << INT0)    //�������������� ������
    out GIMSK , tmp
    cbi PORTD , UF    //��������� ��������
    rcall HelloUser    //��������� � ��������� ����������
    reti    //����� �� �����������


/*
 * GetMinutes
 * ����������� ��������� ����������� ������������� 
 * �������� ����������� �����
 */
GetMinutes:
    mov tmp , minutes
    rcall DevideNumber
    mov tmp , adrL
    rcall ReadEEPROM
    mov dig2 , tmp
    cpi adrH , 0    //���� ����� ������ 10
    brne ReadDig3    //�������� ������� ������
    ldi adrH , 10
ReadDig3:
    mov tmp , adrH
    rcall ReadEEPROM
    mov dig3 , tmp
    ret


/*
 * GetSeconds
 * ����������� ��������� ����������� ������������� 
 * �������� ����������� ������
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
 * ������������ ������� ����� �� �������
 */
DevideNumber:
    clr adrH    //����� �������� ��������
    mov adrL , tmp    //��������� �����
Devide:
    cpi adrL , 10    //���� ����� ������ 10
    brmi Stop    //��������� �������
    subi adrL , 10    //����� ������ 10
    inc adrH    //��������� ������� ��������
    rjmp Devide    //���������� �������
Stop:
    ret    //����� �� ������������


/*
 * HelloUser
 * ������������ ��������� ��������� ��������
 */
HelloUser:
    ldi seconds , 0
    ldi minutes , 1

    ldi tmp , 11    //����� " - - - - "
    rcall ReadEEPROM
    mov dig0 , tmp
    mov dig1 , tmp
    mov dig2 , tmp
    mov dig3 , tmp
    ldi event , TURN    //�������� �����
    ret    //����� �� ������������


/*
 * ReadEEPROM
 * ������������ ������ ������ �� EEPROM
 */
ReadEEPROM:
    out EEARL , tmp    //������ ������ �������
    sbi EECR , EERE    //��������� ������
    in tmp , EEDR    //������� �������� ������
    ret    //����� �� ������������

