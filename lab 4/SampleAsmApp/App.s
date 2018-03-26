; Definitions  -- references to 'UM' are to the User Manual.

; Timer Stuff -- UM, Table 173

T0	equ	0xE0004000		; Timer 0 Base Address
T1	equ	0xE0008000

IR	equ	0			; Add this to a timer's base address to get actual register address
TCR	equ	4
MCR	equ	0x14
MR0	equ	0x18

TimerCommandReset	equ	2
TimerCommandRun	equ	1
TimerModeResetAndInterrupt	equ	3
TimerResetTimer0Interrupt	equ	1
TimerResetAllInterrupts	equ	0xFF

; VIC Stuff -- UM, Table 41
VIC	equ	0xFFFFF000		; VIC Base Address
IntEnable	equ	0x10
VectAddr	equ	0x30
VectAddr0	equ	0x100
VectCtrl0	equ	0x200

Timer0ChannelNumber	equ	4	; UM, Table 63
Timer0Mask	equ	1<<Timer0ChannelNumber	; UM, Table 63
IRQslot_en	equ	5		; UM, Table 58

IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C
IO1PIN	EQU	0xE0028010
IO0DIR	EQU	0xE0028008
IO0SET	EQU	0xE0028004
IO0CLR	EQU	0xE002800C


	AREA	InitialisationAndMain, CODE, READONLY
	IMPORT	main

	EXPORT	start
start

; Initialise the VIC
	ldr	r0,=VIC			; looking at you, VIC!

	ldr	r1,=irqhan
	str	r1,[r0,#VectAddr0] 	; associate our interrupt handler with Vectored Interrupt 0

	mov	r1,#Timer0ChannelNumber+(1<<IRQslot_en)
	str	r1,[r0,#VectCtrl0] 	; make Timer 0 interrupts the source of Vectored Interrupt 0

	mov	r1,#Timer0Mask
	str	r1,[r0,#IntEnable]	; enable Timer 0 interrupts to be recognised by the VIC

	mov	r1,#0
	str	r1,[r0,#VectAddr]   	; remove any pending interrupt (may not be needed)

; Initialise Timer 0
	ldr	r0,=T0			; looking at you, Timer 0!

	mov	r1,#TimerCommandReset
	str	r1,[r0,#TCR]

	mov	r1,#TimerResetAllInterrupts
	str r1,[r0,#IR]

	ldr	r1,=(14745600/200)-1	 ; 5 ms = 1/200 second
	str	r1,[r0,#MR0]

	mov	r1,#TimerModeResetAndInterrupt
	str	r1,[r0,#MCR]

	mov	r1,#TimerCommandRun
	str	r1,[r0,#TCR]


;thread0 will begin here the first time
thread0Start
	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
; r1 points to the SET register
; r2 points to the CLEAR register

	;Lab one here but polling the count
	ldr	r5,=0x00100000	; end when the mask reaches this value
	
wloop	ldr	r3,=0x00010000	; start with P1.16.
floop	str	r3,[r2]	   	; clear the bit -> turn on the LED

delay0
	;delay for about a half second
	ldr	R8,=0x2000000
dloop0	subs	R8,R8,#1
	bne	dloop0

	str	r3,[r1]		;set the bit -> turn off the LED
	mov	r3,r3,lsl #1	;shift up to next bit. P1.16 -> P1.17 etc.
	cmp	r3,r5
	bne	floop
	b	wloop


;thread1 will begin here the first time
thread1Start
	LDR	R1,=IO0DIR
	LDR	R2,=0x0001B780
;   0000 0000 0000 0001 1011 0111 1000 0000
;   31   27   23   19   15   11   7    3
	STR	R2,[R1]		
	LDR	R1,=IO0SET
	STR	R2,[R1]		
	LDR	R2,=IO0CLR

	LDR R3, =4
	LDR R4, =ttb
	LDR R5, =0x000FFFF0 ;all leds
restart
	LDR	R6, =15    		;end of table
	MUL R7, R6, R3		; multiply by 4 for memory sized jumpe
while
	CMP R6, #0			;for loop counting down from 15
	BLT restart
	ADD R8, R4, R7		;start of table plus memory offset
	LDR R8, [R4, R7]	;load value from table
	STR R5, [R2]		;turn off all led that are on
	STR R8, [R1]		;turn on bits specified by value
;delay for about a half second
	LDR	R9, =2000000
dloop	SUBS	R9, R9, #1
	BNE	dloop
	SUB R6, R6, #1
	SUB R7, R7, #4
	B while

stop	b	stop  		; branch always



	AREA	InterruptStuff, CODE, READONLY
irqhan	sub	lr,lr,#4
	STMFD SP!, {R0 - R1}; LR in this case is the place to return to when we store it 
	LDR R0, =threads
	LDR R1, =threadIndex
	LDR R1, [R1]
	LSL R1, R1, #2
	ADD R0, R0, R1
	;R0 contains the pointer to the thread stack of current process
	;ADD R1, R0, #8 ;adjust the stact pointer to the apropriate place in the stack
	LDR R0, [R0]
	ADD R1, R0, #8
	STMEA R1, {R2 - R12, LR}
	LDMFD SP!, {R2 - R3} ;load the saved registers back
	STMEA R0, {R2 - R3}
	;the regs are now saved onto the thread stack

;change the mode
	;MRS R0, CPSR
	;LDR R1, =0x0000000F
	;ORR R0, R0, R1
	;MSR CPSR_cxsf, R0

;go to next thread in array if end go to begining
	LDR R0, =threads
	LDR R1, =threadIndex
	LDR R2, =threadNum
	LDR R3, [R1]
	LDR R2, [R2]
	ADD R3, R3, #1
	CMP R3, R2
	BLT endIterate
	LDR R3, =0
endIterate
	STR R3, [R1]

;changes to the next stack pointer 
	LSL R3, R3, #2
	ADD R0, R0, R3
	LDR R0, [R0]
	;R0 is now the pointer to the next thread stack
	LDR R2, =13
	LDR R4, [R0, R2, LSL #2] ;load the pc to R4
	LDMFD R0!, {R2 - R3}
	STMFD SP!, {R2 - R4} ; stores R0 - R1 and the PC
	LDMFD R0!, {R2 - R12} ;Load the saved registers of the thread stack
	
;this is where we stop the timer from making the interrupt request to the VIC
	ldr	r0,=T0
	mov	r1,#TimerResetTimer0Interrupt
	str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
	ldr	r0,=VIC
	mov	r1,#0
	str	r1,[r0,#VectAddr]	; reset VIC
	
	LDMFD SP!, {R0 - R1, PC}^ ;load the rest of the registers and change the program counter

	AREA	Subroutines, CODE, READONLY

	AREA	Stuff, DATA, READWRITE
	
	
ttb DCD 0x00003780,0x00000300,0x00009580,0x00008780,0x0000A300,0x0000A680,0x0000B680,0x00000380,0x0000B780,0x0000A380,0x0000B380,0x0000B600,0x00003480,0x0009700,0x0000B480,0x0000B080	

	
thread0 DCD 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, thread0Start ;last element is the pc of the thread
thread1 DCD 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, thread1Start 

threadNum DCD 2
	
threadIndex DCD 0	
	
threads DCD thread0, thread1

	
	END