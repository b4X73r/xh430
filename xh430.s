;/ xH regulator
;/
;/ Christophe Duverger, 2016-2022
;/
;/			.set	DEBUG,	1	// Debug features
;/			.set	DSIM,	1	// Simulator
;/			.set	DIBIT,	1	// IBIT
;/			.set	FARC,	1	// Feature archive
;/			.set	FDPAR,	1	// Feature display params
;/			.set	FDHIS,	1	// Feature display history
;/			.set	FLIQO,	1	// Feature manual motor
;/			.set	FDUMP,	1	// Feature dump ram
;/
;{
;/ JTAG pins
;/	Facing LCD, the pins are on top of the board
;/	From left to right:(MSP430-JTAG pin numbers in ())
;/		RST (11)
;/		GND (9)
;/		VCC (2)
;/		TST (8)
;/		TDO (1)
;/		TDI (3)
;/		TMS (5)
;/		TCK (7)
;/
;/ Bus wiring
;/  P1.0 dot
;/  P1.1 medium segment, SET button if P2.1 is set
;/  P1.2 up left segment, CAL button if P2;& is set
;/  P1.3 down left segment
;/  P1.4 upper segment
;/  P1.5 up right segment
;/  P1.6 down right segment
;/  P1.7 downer segment
;/  P2.0 reference 0 for pH (0V = 512), 1 for rH (0V = 0)
;/  P2.1 set for keys input on P1, reset for display on P1
;/  P2.2 A2 = ADC10 input
;/  P2.3 set for left digit, reset for right digit
;/  P2.4 red LED
;/  P2.5 motor
;/
;/ Registers:
;/  R4:	 functions: first argument
;/  R5:	 functions: second argument
;/  R6:	 functions: result
;/  R7:	 IBIT step counter / multi purpose
;/  R8:	 wait counter
;/  R9:	 simulator pointer
;/  R10: Timer A1 entropy
;/  R11: calibration reference
;/  R12: number of cycles with motor ON
;/  R13: entropy counter
;/  R14: segments (MSB left, LSB right)
;/  R15: status:
;/		00: SPD: suspend action
;/		01: SET pressed
;/		02: CAL pressed
;/		03: RAW: raw xH
;/		04: LGT: set LED
;/		05: DEBUG: NLE: empty liquid
;/		06: VAL: xH valid
;/		07: DEBUG: PRE: probe broken
;/		08:	DEBUG: MOV: multiplication overflow
;/		09: ACT: dose effect not finished
;/		10: EFF: dose effect in progress
;/		11: END: end of dose effect
;/		12: none
;/		13: DSIM: STP: stop
;/		14: MAN: set if manual calibration
;/		15: SGN: sign store
;/
;/ Permanent status:
;/	01: DI: direction (reset for +, set for -)
;/	02: LQ: reset for pH, set for rH
;/	12: DO: divide overflow
;/	13: FV: flash violation
;/	14: WR: incorrect IBIT result
;/	15: IB: correct IBIT result and finished
;/
;/ Segments organisation
;/	 -  10
;/	| | 04 20
;/	 -  02
;/	| | 08 40
;/	 -. 80 01
;/
;/ Time calibration
;/   H0: 16 values each 2,06s, total of 33s (automatic by ADC10 DTC)
;/   H1: 16 values of each 33s, total of 8m47s
;/   H2: 16 values of each 8m47s, total of 2h20m38s
;/
;/ Probes behaviors and formulas:
;/   pH probe:
;/     gives negative values for acid and positive values for basic
;/     cross 0 at pH=7
;/     needs 2 calibrations:
;/       V1pH to compensate the drift aroud pH=7
;/       V2pH to calculate the rate of the slope
;/   rH probe:
;/     gives a voltage value corresponding to redox
;/     no need to compensate a drift, since 0V is rH=0
;/     needs 1 calibration:
;/       V1rH or v2rH to compensate the rate of the slope
;/   Vm: measured value directly from ADC10
;/       domain: 0 to 1023
;/   Probes formulas that gives raw values:
;/     RpH = (ADCMax - Vm) - ADCMax / 2 + V1pH
;/     RrH = Vm
;/     domain 10 to 990 for each
;/
;/ Calibration calculus
;/   V1r or V2r: reference value for 1st or 2nd calibration
;/   RV1 of RV2: measured raw values for reference values
;/   CxH: computed xH value after taking account of calibration
;/        domain 10 to 990
;/   To avoid integer overflow, the rate A is computed on a reference
;/   The operation that can be overflowed is RxH * A > 32767
;/     Ar: rate reference = 32 (990 * 32 < 32767)
;/     AxH: rate computed
;/   Computed xH formulas:
;/     CpH = V1r + (RpH - RV1) * ApH / Ar
;/     CrH = RrH * ArH / Ar
;/   pH calibration:
;/     ApH = Ar with only V1 calibration
;/     ApH = (V1r - V2r) * Ar / (RV1 - RV2) with V2 calibration
;/   rH calibration:
;/     ArH = Vxr * Ar / RVx (Vx = V1 or V2)
;/
;/ Menus
;/	Reset:			"xH"
;/		none		Main
;/		SET			Features menu
;/		CAL			Features menu
;/		SET + CAL	Features menu
;/
;/	Main:			value
;/		SET			Setpoint
;/		CAL			Calibration
;/		SET + CAL	Reset
;/
;/	Setpoint:		"SP"
;/		SET			Cancel
;/		CAL			FDUMP: Dump RAM
;/		SET + CAL	Cancel
;/
;/	Calibration:	"CA"
;/		SET			Manual calibration
;/		CAL			Cancel
;/		SET + CAL	Cancel
;/
;/	Simulator
;/		Bloc:
;/			number of cycles (if null value, end of simulation)
;/			start value
;/			end value
;/		Number of seconds:
;/			total of cycles x 0,254
;}
			.ifdef	DSIM
			.set	BCMDIV2,	0			;/ 0-3 (0: rapid)
			.set	SAMDIV2,	0			;/ 0-3 (0: rapid)
			.set	ADCDIV3,	0			;/ 0-7 (0: rapid)
			.endif
			.ifdef	DIBIT
			.set	Start,		IBIT		;/ Entry point
			.else
			.set	Start,		Main		;/ Entry point
			.endif
			.set	DosIni,		20			;/ Empiric value (11mn)
			.set	MOTStr,		3			;/ Motor ON cycles at reset

;/ Pre-processing constants
;{
;/ P2 register
;{
			.set	REF,		0x01		;/ Reference
			.set	SKY,		0x02		;/ Key select
			.set	ADC,		0x04		;/ A2 input
			.set	SLR,		0x08		;/ Left Right select
			.set	LED,		0x10		;/ LED
			.set	MOT,		0x20		;/ Motor
;}
;/ R15 status
;{
			.set	SPD,		0x0001		;/ Suspend action
			.set	SET,		0x0002		;/ P1: SET key
			.set	CAL,		0x0004		;/ P1: CAL key
			.set	RAW,		0x0008		;/ Raw xH
			.set	LGT,		0x0010		;/ Set LED
			.set	NLE,		0x0020		;/ Empty liquid
			.set	VAL,		0x0040		;/ xH valid
			.set	PRE,		0x0080		;/ Probe broken
			.set	ACT,		0x0100		;/ Waiting for dose effect finished
			.set	EFF,		0x0200		;/ Dose effect
			.set	END,		0x0400		;/ End of dose effect
			.set	STP,		0x0800		;/ Stop
			.set	MOV,		0x2000		;/ Multiplication overflow
			.set	MAN,		0x4000		;/ Manual calibration
			.set	SGN,		0x8000		;/ Sign storage
;}
;/ Permanent status
;{
			.set	DI,			0x0002		;/ Direction (1 for -)
			.set	LQ,			0x0004		;/ Liquid (1 for rH)
			.set	DO,			0x1000		;/ Division by 0
			.set	FV,			0x2000		;/ Flash violation
			.set	IB,			0x4000		;/ IBIT finished
			.set	WR,			0x8000		;/ Wrong result
;}
;/ Default parameters
;{
			.set	SPpH,		740
			.set	SPrH,		650
			.set	V1pH,		700
			.set	V2pH,		400
			.set	V1rH,		650
			.set	V2rH,		468
			.set	Ar,			32
			.ifdef	DSIM
			.set	ADpH,		Ar
			.set	ADrH,		Ar
			.else
			.set	ADpH,		7 * Ar / 4
			.set	ADrH,		6 * Ar / 5
			.endif
;}
;/ Constant values
;{
			.set	MAX,		0x7FFF			;/ Maximum positive integer value

			.set	APer,		0x0200			;/ Timer A0 period
			.ifdef	DSIM
			.set	SPer,		APer			;/ Timer A1 period for ADC10 sample trigger
			.endif
			.set	ADCMax,		1024			;/ ADC10 on 10bits
			.set	ADCZero,	ADCMax / 2		;/ 0V for pH

			.set	LPWait,		0x0800			;/ Wait loop unit
			.set	DPWait,		0x0400			;/ Wait time for display
			.set	LDWait,		0x0100			;/ Wait time for LED flash
			.set	KYWait,		0x0080			;/ Wait time between key check
			.set	FLWait,		0x0080			;/ Wait time before memory flash

			.set	KeyCpt,		0x0020			;/ Number of cycle to wait key
			.set	CalCpt,		2 * 8			;/ Number of calibration tries

			.set	HisNb,		16				;/ Number of values in history
			.set	CalNb,		HisNb / 2		;/ Age of samples for convergence

			.set	Step,		10				;/ Step for manual change
			.set	xHMin,		10				;/ Minimum value of xH
			.set	xHMax,		990				;/ Maximum value of xH

			.set	xHDom,		300				;/ Absolute domain of xH
			.set	SPDom,		xHDom / 2		;/ Absolute domain of SP

			.set	pHMin,		V1pH - xHDom
			.set	pHMax,		V1pH + xHDom
			
			.set	rHMin,		V1rH - xHDom
			.set	rHMax,		V1rH + xHDom

			.set	SPpHMin,	SPpH - SPDom
			.set	SPpHMax,	SPpH + SPDom

			.set	SPrHMin,	SPrH - SPDom
			.set	SPrHMax,	SPrH + SPDom

			.set	ValHis,		3				;/ History for probe stabilization
			.set	EffHis,		6				;/ History for effect check (53mn)
			.set	EndHis,		2				;/ History for end of effect check (18mn)

			.set	CalTol,		5				;/ Variance tolerance for declaring end of calibration
			.set	ValTol,		2				;/ Variance tolerance for declaring valid value
			.set	ActTol,		5				;/ Variance tolerance for declaring action
			.set	DosTol,		15				;/ Variance tolerance for enabling dose calibration
			.set	EffTol,		5				;/ Variance tolerance for declaring effect
			.set	EndTol,		2				;/ Variance tolerance for declaring end of effect

			.set	AMax,		32768 / xHDom	;/ Maximum acceptable value for A
;}
;}
;/ RAM segment
;{
			.section ".bss"

VAR_beg:
;/ Copies of constants
v_Status:	.space 2
v_xHSP:		.space 2
v_CalV1:	.space 2
v_CalV2:	.space 2
v_CalA:		.space 2
v_DosCnt:	.space 2
VAR_end:
			.set	VarSiz,		VAR_end - VAR_beg

			.set	HisSiz,		2 * HisNb
v_H0:
v_H0Nb:		.space 2
v_H0Pos:	.space 2
v_H0Val:	.space HisSiz

v_H1:
v_H1Nb:		.space 2
v_H1Pos:	.space 2
v_H1Val:	.space HisSiz

v_H2:
v_H2Nb:		.space 2
v_H2Pos:	.space 2
v_H2Val:	.space HisSiz

			.set	IdxNb,		v_H1Nb - v_H1
			.set	IdxPos,		v_H1Pos - v_H1
			.set	IdxVal,		v_H1Val - v_H1

v_RefMON:
			.space 2
v_RefxHM:
			.space 2
v_V1Ref:
			.space 2
v_V2Ref:
			.space 2

			.ifdef	DEBUG
v_SP:		.space 2
v_SR:		.space 2
v_R4:		.space 2
v_R5:		.space 2
v_R6:		.space 2
v_R7:		.space 2
v_R8:		.space 2
v_R9:		.space 2
v_R10:		.space 2
v_R11:		.space 2
v_R12:		.space 2
v_R13:		.space 2
v_R14:		.space 2
v_R15:		.space 2
			.endif
			.ifdef	DSIM
v_SimEnt:
			.space 2
			.endif
;}
;/ Information segment
;{
			.section ".infomem"
			.org 0x0010

CST_beg:
;/	Saved values
c_Status:	.space 2
c_xHSP:		.space 2						;/ xH set point
c_CalV1:	.space 2						;/ V1 calibration
c_CalV2:	.space 2						;/ V2 calibration
c_CalA:		.space 2						;/ A
c_DosCnt:	.space 2						;/ Number of cycles for +/- 010 * 32
c_Spare:	.space 2						;/ 

			.ifdef	DSIM
			.org 0x0080
Simu_beg:
			.endif
			.ifdef	FARC
			.org 0x0090
ARC_beg:
			.endif
;}
;/ Memory dump segment
;{
			.text
			.org 0x0000
			.ifdef	DEBUG
DMP_beg:
			.set	DmpSiz,		0x0100
			.endif
;}
;/ Code constants
;{
			.ifdef	DEBUG
			.org 0x0200						;/ Next NVRAM segment
			.endif

;/	Strings
;{
s_SW:		.word 0xF3FC					;/ 3.0
s_Unk:		.word 0x0202					;/ -- Unknown
s_Rec:		.word 0x9CF0					;/ [] Save
s_SP:		.word 0xD63E					;/ SP Set Point
s_CA:		.word 0x9C7E					;/ CA Calibration
s_CS:		.word 0x9CD6					;/ CS Manual calibration
s_NL:		.word 0x7C8C					;/ NL No Liquid
s_Er:		.word 0x9E0A					;/ Er Error

			.ifdef	FDPAR
s_St:		.word 0xD68E					;/ St Status
s_V1:		.word 0x6082					;/ 1=
s_V2:		.word 0xBA82					;/ 2=
s_A:		.word 0x7E82					;/ A=
s_Dos:		.word 0xEA82					;/ d=
			.endif

s_BegFeat:
s_LC:		.word 0x8C9C					;/ LC Liquid Change
s_Cd:		.word 0x9CEA					;/ Cd Clear dose calibration
s_CC:		.word 0x9C9C					;/ CC Clear calibration
			.ifdef	FLIQO
s_LO:		.word 0x8CFC					;/ LO Liquid On
			.endif
			.ifdef	FARC
s_AS:		.word 0x7ED6					;/ AS Archive Save
s_AL:		.word 0x7E8C					;/ AL Archive Load
			.endif
			.ifdef	FDHIS
s_dH:		.word 0xEA6E					;/ dH Display history
s_h0:		.word 0x4EFC					;/ h0
s_h1:		.word 0x4E60					;/ h1
s_h2:		.word 0x4EBA					;/ h2
			.endif
			.ifdef	FDPAR
s_dP:		.word 0xEA3E					;/ dP Display parameters
			.endif
s_EndFeat:

s_Mode:
s_Pp:		.word 0x3E3E					;/ PP
s_Pm:		.word 0x3E02					;/ P-
s_rH:		.word 0x0A6E					;/ rH
;}
;/	Digits
;{
b_Num:		.byte 0xFC						;/ 0
			.byte 0x60						;/ 1
			.byte 0xBA						;/ 2
			.byte 0xF2						;/ 3
			.byte 0x66						;/ 4
			.byte 0xD6						;/ 5
			.byte 0xDE						;/ 6
			.byte 0x70						;/ 7
			.byte 0xFE						;/ 8
			.byte 0xF6						;/ 9
			.byte 0x7E						;/ A
			.byte 0xCE						;/ B
			.byte 0x9C						;/ C
			.byte 0xEA						;/ D
			.byte 0x9E						;/ E
			.byte 0x1E						;/ F
;}
;/	Snake animation
;{
a_Snk:		.word 0x1000
			.word 0x0010
			.word 0x0020
			.word 0x0040
			.word 0x0080
			.word 0x8000
			.word 0x0800
			.word 0x0400
;}
;/	Empty animation
;{
a_NL0:		.word 0x02FC
a_NL1:		.word 0x02CA
a_NL2:		.word 0x0280
;}
;/	Tests & simulation
;{
			.ifdef	DIBIT
;{
Tests_beg:
			.word	32760
			.word	181
			.word	Modulo
			.word	180
Tests_end:
			.endif
;}
;}
;}
;/ Functions
;{
;/ Wait
;/ 	R8: wait value
;/	no effect
;{
Wait:
			push.w	R8
			push.w	R4
wait_loop1:
			mov.w	#LPWait, R4
wait_loop2:
			dec.w	R4
			jnz		wait_loop2
			dec.w	R8
			jnz		wait_loop1
			pop.w	R4
			pop.w	R8
			ret
;}
;/ WaitKey
;/	No effect
;{
WaitKey:
			bit.w	#SET|CAL, R15			;/ Test SET and CAL keys
			jnz		WaitKey
			ret
;}
;/ WaitFL
;/	No effect
;{
WaitFL:
			bit.w	#1, &FCTL3				;/ Wait till flash not buzzy
			jnz		WaitFL
			ret
;}
;/ WaitLED
;/	No effect
;{
WaitLED:
			push.w	R8
			mov.w	#LDWait, R8
			xor.b	#LED, &P2OUT
			call	#Wait
			xor.b	#LED, &P2OUT
			call	#Wait
			pop.w	R8
			ret
;}
;/ XOR Sign
;/	S(R4) xor S(R5) -> S(R15)
;/	Effect: SGN in R15, R4, R5 sign bit is cleared
;{
XORSign:
			push.w	R5
			bis.w	#SGN, R15
			xor.w	R4, R5
			bis.w	#0x7FFF, R5
			and.w	R5, R15
			pop.w	R5
			tst.w	R4
			jge		sgn_pos4
			inv.w	R4
			inc.w	R4
sgn_pos4:
			tst.w	R5
			jge		sgn_pos5
			inv.w	R5
			inc.w	R5
sgn_pos5:
			ret
;}
;/ Multiply
;/	R4 * R5 => R6
;/	Effect: R6
;{
Multiply:
			clr.w	R6
			tst.w	R4
			jz		mul_ret
			push.w	R4
			push.w	R5
			call	#XORSign
mul_loop:
			bit.w	#1, R4
			jz		mul_even
			add.w	R5, R6					;/ Odd case
			jc		mul_ovf
			dec.w	R4
mul_even:
			rla.w	R5						;/ R5 = R5 * 2
			rra.w	R4						;/ R4 = R4 / 2
			jnz		mul_loop
mul_sgn:
			bit.w	#SGN, R15
			jz		mul_end
			inv.w	R6
			inc.w	R6
mul_end:
			pop.w	R5
			pop.w	R4
mul_ret:
			ret
mul_ovf:
			.ifdef	DEBUG
			bis.w	#MOV, R15
			.endif
			mov.w	#MAX, R6
			jmp		mul_sgn
;}
;/ Egyptian division
;/	a = R4 / b = R5 => q = R6, r = R4
;/	R5 should not be null
;/	Effect: R4, R5, R6
;{
;/	long[] euclide(long a, long b) {
;/		long r = a;/
;/		long q = 0;/
;/		long n = 0;/ // R7
;/
;/		while (r >= b) {
;/			b <<= 1;/
;/			n++;
;/		}
;/
;/		while (n != 0) {
;/			b >>= 1;/
;/			n--;
;/			q <<= 1;/
;/			if (r >= b) {
;/				r -= b;/
;/				q++;
;/			}
;/		}
;/		return {q, r};
;/	}
;/
Euclide:
			clr.w	R6
			tst.w	R5
			jz		euc_ovf
			tst.w	R4
			jz		euc_ret
			call	#XORSign
			push.w	R7
			clr.w	R7
euc_loop1:
			tst.w	R5
			jl		euc_loop2
			cmp.w	R5, R4
			jl		euc_loop2		;/ R4 < R5
			rla.w	R5
			inc.w	R7
			jmp		euc_loop1
euc_loop2:
			tst.w	R7
			jz		euc_sign
			clrc
			rrc.w	R5
			dec.w	R7
			rla.w	R6
			cmp.w	R5, R4
			jl		euc_loop2		;/ R4 < R5
			sub.w	R5, R4
			inc.w	R6
			jmp		euc_loop2
euc_sign:
			bit.w	#SGN, R15
			jz		euc_end
			inv.w	R6
			inc.w	R6
euc_end:
			pop.w	R7
euc_ret:
			ret
euc_ovf:
			bis.w	#DO, &v_Status
			.ifdef	DEBUG
			call	#RecordERR
			.endif
			ret
;}
;/ Divide
;/	R4 / R5 => R6
;/	R5 should not be null
;/	Effect: R4, R5, R6
;{
Divide:
			push.w	R4
			push.w	R5
			call	#Euclide
			pop.w	R5
			pop.w	R4
			ret
;}
;/ Modulo
;/	R4 % R5 => R6
;/	Effect: R6
;{
Modulo:
			push.w	R4
			push.w	R5
			call	#Euclide
			mov.w	R4, R6
			pop.w	R5
			pop.w	R4
			ret

;}
;/ HisSave
;/	R4: value to save
;/	R5: history address
;/	No effect
;{
HisSave:
			push.w	R4
			push.w	R6
			mov.w	IdxPos(R5), R6
			mov.w	R4, @R6
			incd.w	IdxPos(R5)
			mov.w	R5, R6
			add.w	#IdxVal + HisSiz, R6
			cmp.w	R6, IdxPos(R5)
			jnz		his_noinit				;/ No need to rotate buffer
			sub.w	#HisSiz, R6
			mov.w	R6, IdxPos(R5)			;/ Reset to first position
his_noinit:
			cmp.w	#HisNb, IdxNb(R5)
			jz		his_send				;/ Buffer already filled
			inc.w	IdxNb(R5)
his_send:
			pop.w	R6
			pop.w	R4
			ret
;}
;/ HisRead
;/	R4: age
;/	R5: history address
;/	Effect: R6 value
;{
HisRead:
			push.w	R4
			push.w	R7
			rla.w	R4
			mov.w	IdxPos(R5), R6
			sub.w	R4, R6
			mov.w	R5, R7
			add.w	#IdxVal, R7
			cmp.w	R7, R6
			jge		his_rnorot				;/ R6 >= R7
			add.w	#HisSiz, R6
his_rnorot:
			mov.w	@R6, R6
his_rend:
			pop.w	R7
			pop.w	R4
			ret
;}
;/ HisMean
;/	R4: age
;/	R5: history address
;/	Effect: R6 mean
;{
HisMean:
			tst.w	R4
			jz		his_nmax
			cmp.w	R4, IdxNb(R5)
			jl		his_nmax				;/ age > history
			push.w	R4
			push.w	R5
			push.w	R7
			push.w	R4
			clr.w	R7
his_mloop:
			call	#HisRead
			add.w	R6, R7
			dec.w	R4
			jnz		his_mloop
			mov.w	R7, R4
			pop.w	R5
			call	#Divide
			pop.w	R7
			pop.w	R5
			pop.w	R4
			ret
his_nmax:
			clr.w	R6
			ret
;}
;/ HisVar
;/	R4: age
;/	R5: history address
;/	Effect: R6 maximum variation
;{
HisVar:
			tst.w	R4
			jz		his_vmax
			cmp.w	R4, IdxNb(R5)
			jl		his_vmax				;/ age > history
			push.w	R4
			push.w	R7
			push.w	R8
			mov.w	#xHMax, R7
			mov.w	#xHMin, R8
his_vloop:
			call	#HisRead
			cmp.w	R7, R6
			jge		his_vnomin				;/ value >= R7 (minimum)
			mov.w	R6, R7
his_vnomin:
			cmp.w	R6, R8
			jge		his_vnomax				;/ value <= R8 (maximum)
			mov.w	R6, R8
his_vnomax:
			dec.w	R4
			jnz		his_vloop
			sub.w	R7, R8
			mov.w	R8, R6
			pop.w	R8
			pop.w	R7
			pop.w	R4
			ret
his_vmax:
			mov.w	#MAX, R6
			ret
;}
;/ PrintSnk
;/	R4: counter
;/	Effect: R14
;{
PrintSnk:
			push.w	R4
			and.w	#0x0007, R4
			rla.w	R4
			mov.w	a_Snk(R4), R14			;/ Move snake string to display
			pop.w	R4
			ret
;}
;/ PrintByte
;/	R4: LSB to display
;/	Effect: R14
;{
PrintByte:
			push.w	R4
			push.w	R5
			clr.w	R5
			push.w	R4
			rra.w	R4
			rra.w	R4
			rra.w	R4
			rra.w	R4						;/ Get left quartet
			and.w	#0x000F, R4
			mov.b	b_Num(R4), R5
			swpb	R5
			pop.w	R4
			and.w	#0x000F, R4
			mov.b	b_Num(R4), R4
			add.w	R4, R5
			mov.w	R5, R14
			pop.w	R5
			pop.w	R4
			ret
;}
;/ PrintWord
;/	R4: value to display
;/	Effect: R14
;{
PrintWord:
			swpb	R4
			call	#PrintByte
			call	#Wait
			swpb	R4
			call	#PrintByte
			call	#Wait
			ret
;}
;/ PrintNum, PrintPar
;/	R4: value / 10
;/	Effect: R14
;{
PrintNum:
			cmp.w	#xHMax+1, R4
			jge		unknown					;/ value > xHMax
			cmp.w	#xHMin, R4
			jl		unknown					;/ value < xHMin
PrintPar:
			push.w	R4						;/ R4, R5, R6 used for operators
			push.w	R5
			push.w	R6
			push.w	R7
			clr.w	R7
			tst.w	R4
			jge		positive
			bis.w	#0x0100, R7
			inv.w	R4
			inc.w	R4						;/ R4 = -R4
positive:
			mov.w	#10, R5
			call	#Modulo					;/ Get xH cent
			cmp.w	#5, R6					;/ Round to ten
			jl		round_less				;/ R6 < 5
			sub.w	R6, R5
			add.w	R5, R4
			jmp		rounded
round_less:
			sub.w	R6, R4
rounded:
			push.w	R4						;/ Store value rounded
			mov.w	#100, R5				;/ Get unit
			call	#Divide
			and.w	#0x000F, R6
			mov.b	b_Num(R6), R6
			bis.w	R6, R7					;/ Put it in R7
			swpb	R7
			pop.w	R4
			call	#Modulo					;/ Get remainder
			mov.w	R6, R4
			mov.w	#10, R5
			call	#Divide					;/ Get ten
			and.w	#0x000F, R6
			mov.b	b_Num(R6), R6
			bis.w	R6, R7					;/ Combine left and right digit
adddot:
			bit.w	#LQ, &v_Status
			jnz		nodot
			bis.w	#0x0100, R7				;/ Add dot
nodot:
			mov.w	R7, R14
			pop.w	R7
			pop.w	R6
			pop.w	R5
			pop.w	R4
			ret
unknown:
			push.w	R4
			push.w	R5
			push.w	R6
			push.w	R7
			mov.w	&s_Unk, R7
			jmp		adddot
;}
;/ PrintMode
;/	No effect
;{
PrintMode:
			push.w	R4
			mov.w	&v_Status, R4
			and.w	#DI|LQ, R4
			mov.w	s_Mode(R4), R14
			pop.w	R4
			ret
;}
;/ GetState
;/	6(R1): adress of display function
;/	4(R1): adress of SET function
;/	2(R1): adress of CAL function
;/	No effect
;{
GetState:
			push.w	R4
			push.w	R7
			push.w	R8
			push.w	R14
			mov.w	#KYWait, R8
			mov.w	#KeyCpt, R7
			call	#Wait
			call	#WaitKey
gs_loop:
			bit.w	#1, R7
			jnz		gs_clear
			tst.w	6+4*2(R1)				;/ 6 + 4 push
			jnz		gs_call
			mov.w	@R1, R14
			jmp		gs_next
gs_call:
			call	6+4*2+2(R1)				;/ 6 + 4 push + 2 CALL
			jmp		gs_next
gs_clear:
			clr.w	R14
gs_next:
			call	#Wait
			mov.w	R15, R4
			and.w	#SET|CAL, R4
			add.w	R4, R0
			jmp		gs_cont
			jmp		gs_SET
			jmp		gs_CAL
			jmp		Restart
gs_SET:
			call	#WaitKey
			tst.w	4+4*2(R1)				;/ 4 + 4 push
			jz		gs_cont
			mov.w	#KeyCpt, R7
			call	4+4*2+2(R1)				;/ 4 + 4 push + 2 CALL
			jmp		gs_cont
gs_CAL:
			call	#WaitKey
			tst.w	2+4*2(R1)				;/ 2 + 4 push
			jz		gs_cont
			mov.w	#KeyCpt, R7
			call	2+4*2+2(R1)				;/ 2 + 4 push + 2 CALL
gs_cont:
			dec.w	R7
			jnz		gs_loop
			pop.w	R8
			pop.w	R8
			pop.w	R7
			pop.w	R4
			add.w	#6+2, R1				;/ 6 + 2 CALL GetState
			mov.w	-6-2(R1), R0
;}
;/ GetVal
;/	R4: minimum value
;/	R5: maximum value
;/	R6: default value
;/	Effect: R6
;{
GetVal:
			push.w	R4
			push.w	R11
			mov.w	R4, R11
			push.w	#gv_dpl
			push.w	#gv_inc
			push.w	#gv_dec
			call	#GetState
			pop.w	R11
			pop.w	R4
			ret

;/ GetVal display
gv_dpl:
			mov.w	R6, R4					;/ Display value
			call	#PrintNum
			ret

;/ GetVal increase
gv_inc:
			cmp.w	R5, R6
			jl		gv_incn					;/ R6(value) < R5 (maximum)
			mov.w	R11, R6
			jmp		gv_incr
gv_incn:
			add.w	#Step, R6
gv_incr:
			ret

;/ GetVal decrease
gv_dec:
			cmp.w	R6, R11
			jl		gv_decn					;/ R6(value) > R11(minimum)
			mov.w	R5, R6
			jmp		gv_decr
gv_decn:
			sub.w	#Step, R6
gv_decr:
			ret
;}
;/ Snapshot
;/	No effect
;{
Snapshot:
			.ifdef	DEBUG
			dint
			mov.w	R1, &v_SP
			mov.w	R2, &v_SR
			mov.w	R4, &v_R4
			mov.w	R5, &v_R5
			mov.w	R6, &v_R6
			mov.w	R7, &v_R7
			mov.w	R8, &v_R8
			mov.w	R9, &v_R9
			mov.w	R10, &v_R10
			mov.w	R11, &v_R11
			mov.w	R12, &v_R12
			mov.w	R13, &v_R13
			mov.w	R14, &v_R14
			mov.w	R15, &v_R15
			eint
			.endif
			ret
;}
;/ RecordERR
;/	Effect: R4, R5, R6, R14, R15
;{
			.ifdef	DEBUG
RecordERR:
			dint
			tst.b	&DMP_beg
			jnz		recorded				;/ Error already recorded
			call	#Snapshot
			mov.w	#VAR_beg, R4
			mov.w	#DMP_beg, R5
			mov.w	#DmpSiz, R6
			call	#WriteFL				;/ Dump RAM
			call	#WritePar				;/ Record status value
recorded:
			eint
			ret
			.endif
;}
;/ WriteFL
;/	R4: source
;/	R5: destination
;/	R6: size
;/	Effect: R4, R5, R6, R14
;{
WriteFL:
			clr.w	R14
			push.w	R8
			mov.w	#FLWait, R8
			call	#Wait
			pop.w	R8
			dint
			call	#WaitFL
			mov.w	#0xA588, &FCTL2			;/ SMCLK + FN4
			mov.w	#0xA500, &FCTL3			;/ Unlock flash
			mov.w	#0xA502, &FCTL1			;/ Erase	segment

			clr.b	@R5
			call	#WaitFL
			mov.w	#0xA540, &FCTL1			;/ Write enable
fl_loop:
			mov.w	@R4+, @R5
			incd.w	R5
			decd.w	R6
			jnz		fl_loop

			call	#WaitFL
			mov.w	#0xA500, &FCTL1			;/ Write disable
			mov.w	#0xA510, &FCTL3			;/ Lock flash
			ret
;}
;/ WritePar
;/	Effect: R4, R5, R6, R14
;{
WritePar:
			mov.w	&s_Rec, R14
			call	#Wait
			mov.w	#VAR_beg, R4
			mov.w	#CST_beg, R5
			mov.w	#VarSiz, R6
			jmp		WriteFL
;}
;/ RestartADC
;/	Effect: none
;{
RestartADC:
			bic.w	#0x0006, &ADC10CTL0		;/ Stop ADC
adc_busy:
			bit.w	#0x0001, &ADC10CTL1
			jnz		adc_busy				;/ Wait finished
			clr.w	&ADC10SA				;/ Stop DTC

			.ifdef	DEBUG
			push.w	R4
			mov.w	#HisSiz - 2, R4
adc_loop:
			clr.w	v_H0Val(R4)				;/ Clear H0 values
			decd.w	R4
			jge		adc_loop
			pop.w	R4
			.endif

			clr.w	R13						;/ Re-init entropy
			mov.w	&v_H0Nb, &v_H0Pos
			cmp.w	#HisNb, &v_H0Pos
			jnz		adc_nmax				;/ H0Nb != HisNb
			clr.w	&v_H0Pos
adc_nmax:
			rla.w	&v_H0Pos
			add.w	#v_H0Val, &v_H0Pos
			clr.w	&v_H1Nb					;/ Clear mean 1
			mov.w	#v_H1Val, &v_H1Pos
			clr.w	&v_H2Nb					;/ Clear mean 2
			mov.w	#v_H2Val, &v_H2Pos			
			mov.b	&v_H0Nb, &ADC10DTC1		;/ Send H0Nb to DTC
			mov.w	#v_H0Val, &ADC10SA		;/ Start DTC
			bis.w	#0x0003, &ADC10CTL0		;/ Start ADC
			ret
;}
;/ CalcxH
;/	R6: xH
;/	Effect: R6
;{
CalcxH:
			push.w	R4
			push.w	R5
			.ifndef	DSIM
;/ Adjust raw values
;/ pH = (ADCMax - Vm) - ADCZero + V1pH
;/ rH = X
			bit.w	#LQ, &v_Status
			jnz		calc_next
			mov.w	R6, R4
			mov.w	#ADCMax - ADCZero + V1pH, R6
			sub.w	R4, R6
calc_next:
			.endif

			bit.w	#RAW, R15
			jnz		xH_limit
;/ Correct value with calibration:
			bit.w	#LQ, &v_Status
			jnz		calc_corrH
;/ CpH = V1r + (RpH - RV1) * ApH / Ar
			sub.w	&v_CalV1, R6
			mov.w	R6, R4
			mov.w	&v_CalA, R5
			call	#Multiply
			mov.w	R6, R4
			mov.w	#Ar, R5
			call	#Divide
			add.w	#V1pH, R6
			jmp		xH_limit

calc_corrH:
;/ CrH = RrH * ArH / Ar
			mov.w	R6, R4
			mov.w	&v_CalA, R5
			call	#Multiply
			mov.w	R6, R4
			mov.w	#Ar, R5
			call	#Divide

;/ Limit xH
xH_limit:
			cmp.w	#xHMax + 1, R6			;/ Maximize xH with 990
			jl		xH_nomax				;/ value <= xHMax
			mov.w	#xHMax, R6
xH_nomax:
			cmp.w	#xHMin, R6				;/ Minimize xH with 010
			jge		calc_end				;/ calue >= xHMin
			mov.w	#xHMin, R6
calc_end:
			pop.w	R5
			pop.w	R4
			ret
;}
;}
;/ Reset entry point
;{
RESET:
			dint
			mov.w	#0x0300, R1				;/ SP at end of RAM
			mov.w	#0x0100, R4
ram_loop:
			decd.w	R4
			clr.w	VAR_beg(R4)				;/ Clear RAM to avoid false info in dumps
			jnz		ram_loop
			mov.w	#0x5A80, &WDTCTL		;/ Stop	watchdog
			mov.w	#0xA510, &FCTL3			;/ Lock flash

			;/ Basic Clock Module
			.ifdef	DSIM
			mov.b	#0x40+BCMDIV2*16, &BCSCTL1
											;/ LFXT1 High frequency
											;/ RSEL= 000
											;/ ACLK = LFXT1 / 1
			.else
			mov.b	#0x70, &BCSCTL1			;/ LFXT1 High frequency
											;/ RSEL= 000
											;/ ACLK = LFXT1 / 8
			.endif
			mov.b	#0xCE, &BCSCTL2			;/ MCLK = LFXT1 / 1
											;/ SMCLK = LFXT1 / 8

			;/ Interrupts
			bis.b	#0x20, &IE1				;/ Enable flash violation interrupt
			bic.b	#0x13, &IE1				;/ Disable other interrupts
			bic.b	#0x13, &IFG1			;/ Clear pending interrupts

			clr.b	&P1IE
			clr.b	&P2IE

			;/ Ports
			mov.b	#MOT|SKY|SLR|LED|REF, &P2DIR
			bic.b	#MOT|SKY|SLR|LED|REF, &P2OUT

			;/ ADC10 Module
			mov.b	#0x04, &ADC10DTC0		;/ one bloc, continuous
			.ifdef	DSIM
			mov.w	#0x2078+SAMDIV2*2048, &ADC10CTL0
											;/ Vr+ = Vref+, Vr− = Vss
											;/ Sample = 4 x ADC10CLK
											;/ No need of reference output
											;/ Vref+ = 2,5V
											;/ Interrupt enabled
			mov.w	#0x2404+ADCDIV3*32, &ADC10CTL1
											;/ Input = A2
											;/ ADC10MEM in binary format
											;/ Sample and hold controlled by TA1
											;/ ADC10CLK = ADC10OSC / 1
											;/ Repeat single channel
			.else
			mov.w	#0x3878, &ADC10CTL0		;/ Vr+ = Vref+, Vr− = Vss
											;/ Sample = 64 x ADC10CLK
											;/ No need of reference output
											;/ Vref+ = 2,5V
											;/ Interrupt enabled
			mov.w	#0x24E4, &ADC10CTL1		;/ Input = A2
											;/ ADC10MEM in binary format
											;/ Sample and hold controlled by TA1
											;/ ADC10CLK = ADC10OSC / 8
											;/ Repeat single channel
			.endif

			;/ Timer A Module
			clr.w	&TAIV
			;/ TA0: display and keys
			mov.w	#0x0010, &TACCTL0		;/ Interrupt enable
			clr.w	&TACCR0
			;/ TA1: ADC DTC finished
			mov.w	#0x0090, &TACCTL1		;/ Output toggle mode
											;/ Interrupt enable
			clr.w	&TACCR1					;/ Timer A1 initiate count
			mov.w	#0x02E2, &TACTL			;/ TA = ACLK / 8
											;/ Continuous up to 0xFFFF
											;/ Interrupt enable

			clr.w	R15
			cmp.w	#0xFFFF, &CST_beg 		;/ Check if parameters are initialized or if code has been reflashed
			jnz		Restart
			bis.b	#LED, &P2OUT
			mov.w	#DPWait, R8
			.ifdef	FARC
			cmp.w	#0xFFFF, &ARC_beg 		;/ Check if archive exists
			jnz		ArcLoad
			.endif
			jmp		ClearCal
;}
;/ Restart entry point
;{
Restart:
			dint
			mov.w	#0x0300, R1				;/ SP at end of RAM
			bic.b	#MOT|SKY|SLR|LED|REF, &P2OUT
			bis.b	#0xFF, &P1DIR
			clr.b	&P1OUT
			.ifdef	DSIM
			mov.w	#Simu_beg, R9
			.endif
			.ifdef	DEBUG
			clr.w	R5
			clr.w	R6
			clr.w	R7
			clr.w	R10
			clr.w	R11
			.endif

			clr.w	R12
			clr.w	&v_RefMON
			clr.w	&v_RefxHM
			clr.w	R15
			bis.w	#SPD, R15				;/ Start suspended
			mov.w	#VarSiz, R4
restart_load:
			decd.w	R4
			mov.w	CST_beg(R4), VAR_beg(R4)
			jnz		restart_load
			bit.w	#LQ, &v_Status
			jnz		restart_rh
			mov.w	#V1pH, &v_V1Ref
			mov.w	#V2pH, &v_V2Ref
			jmp		restart_cont
restart_rh:
			mov.w	#V1rH, &v_V1Ref
			mov.w	#V2rH, &v_V2Ref
			bis.b	#REF, &P2OUT
restart_cont:
			call	#PrintMode
			mov.w	#MOTStr, &v_H0Nb
			call	#RestartADC
			clr.w	&TAR
			eint							;/ Start interrupts
			mov.w	#DPWait, R8
			call	#Wait
			mov.w	R15, R4
			and.w	#SET|CAL, R4
			add.w	R4, R0
			jmp		Start					;/ No key pressed
			jmp		FeatMenu				;/ Features
			jmp		FeatMenu				;/ Features
;/			jmp		FeatMenu				;/ Features
;}
;/ Features
;{
;/ Features menu
;{
FeatMenu:
			clr.w	R6
			push.w	#feat_dpl
			push.w	#feat_set
			push.w	#Restart
			call	#GetState
			add.w	R6, R0
feat_beg:
			jmp		LiqChange
			jmp		ClearDos
			jmp		ClearCal
			.ifdef	FLIQO
			jmp		LiqOn
			.endif
			.ifdef	FARC
			jmp		ArcLoad
			jmp		ArcSave
			.endif
			.ifdef	FDHIS
			jmp		DispHis
			.endif
			.ifdef	FDPAR
			jmp		DispParm
			.endif
feat_end:
feat_dpl:
			mov.w	s_BegFeat(R6), R14
			ret
feat_set:
			incd.w	R6
			cmp.w	#feat_end - feat_beg, R6
			jnz		feat_ret					;/ No need to reset R6
			clr.w	R6
feat_ret:
			ret
;}
;/ Display Parameters
;{
			.ifdef	FDPAR
DispParm:
			call	#WaitKey				;/ Wait for key release
disp_loop:
			mov.w	&s_SW, R14
			call	#Wait
			call	#PrintMode
			call	#Wait
			mov.w	&s_St, R14
			call	#Wait
			mov.b	&v_Status, R4
			call	#PrintByte
			call	#Wait
			mov.w	&s_SP, R14
			call	#Wait
			mov.w	&v_xHSP, R4
			call	#PrintPar
			call	#Wait
			mov.w	&s_V1, R14
			call	#Wait
			mov.w	&v_CalV1, R4
			call	#PrintPar
			call	#Wait
			mov.w	&s_V2, R14
			call	#Wait
			mov.w	&v_CalV2, R4
			call	#PrintPar
			call	#Wait
			mov.w	&s_A, R14
			call	#Wait
			mov.w	&v_CalA, R4
			call	#PrintWord
			mov.w	&s_Dos, R14
			call	#Wait
			mov.w	&v_DosCnt, R4
			call	#PrintWord
			bit.w	#SET|CAL, R15
			jz		disp_loop
			call	#WaitKey
			jmp		MainBeg
			.endif
;}
;/ Display History
;{
			.ifdef	FDHIS
DispHis:
			call	#WaitKey				;/ Wait for key release
			mov.w	#HisNb, &v_H0Nb
			dint
			call	#RestartADC
			eint
dish_loop:
			mov.w	&s_h0, R14
			call	#Wait
			mov.w	&v_H0Nb, R4
			call	#PrintByte
			call	#Wait
			mov.w	#v_H0, R5
			call	#HisMean
			mov.w	R6, R4
			call	#PrintNum
			call	#Wait
			mov.w	&v_H0Nb, R4
			call	#HisVar
			mov.w	R6, R4
			call	#PrintNum
			call	#Wait

			mov.w	&s_h1, R14
			call	#Wait
			mov.w	&v_H1Nb, R4
			call	#PrintByte
			call	#Wait
			mov.w	#v_H1, R5
			call	#HisMean
			mov.w	R6, R4
			call	#PrintNum
			call	#Wait
			mov.w	&v_H1Nb, R4
			call	#HisVar
			mov.w	R6, R4
			call	#PrintNum
			call	#Wait

			mov.w	&s_h2, R14
			call	#Wait
			mov.w	&v_H2Nb, R4
			call	#PrintByte
			call	#Wait
			mov.w	#v_H2, R5
			call	#HisMean
			mov.w	R6, R4
			call	#PrintNum
			call	#Wait
			mov.w	&v_H2Nb, R4
			call	#HisVar
			mov.w	R6, R4
			call	#PrintNum
			call	#Wait

			bit.w	#SET|CAL, R15
			jz		dish_loop
			call	#WaitKey
			jmp		MainBeg
			.endif
;}
;/ Liquid change
;{
LiqChange:
			bic.w	#~(DI|LQ), &v_Status
			push.w	#PrintMode
			push.w	#mode_chg
			push.w	#MainBeg
			call	#GetState
			bit.w	#LQ, &v_Status
			jnz		mode_rh
			mov.w	#SPpH, &v_xHSP
			jmp		ClearCal
mode_rh:
			mov.w	#SPrH, &v_xHSP
			jmp		ClearCal
mode_chg:
			incd.w	&v_Status
			cmp.b	#DI|LQ, &v_Status
			jl		mode_cont					;/ No need to reset liquid
			bic.w	#DI|LQ, &v_Status
mode_cont:
			ret
;}
;/ Clear dose or calibration and dose
;{
ClearDos:
			clr.w	R6
			jmp		crst_beg
ClearCal:
			bis.w	#1, R6
crst_beg:
			clr.w	R15
			tst.w	R6
			jz		crst_dose
			bit.w	#LQ, &v_Status
			jnz		crst_rh
			mov.w	#V1pH, &v_CalV1
			mov.w	#V2pH, &v_CalV2
			mov.w	#ADpH, &v_CalA
			jmp		crst_dose
crst_rh:
			mov.w	#V1rH, &v_CalV1
			mov.w	#V2rH, &v_CalV2
			mov.w	#ADrH, &v_CalA
crst_dose:
			clr.w	&v_DosCnt
crst_write:
			call	#WritePar				;/ Flash parameters
			jmp		Restart
;}
;/ Liquid on
;{
LiqOn:
			.ifdef	FLIQO
			dint
			push.w	R12
			mov.w	#1, &v_H0Nb
			call	#RestartADC
			eint
			bic.w	#SPD, R15
mmot_loop:
			mov.w	#3, R12					;/ Always motor on
			mov.w	R13, R4
			call	#PrintSnk				;/ Display snake animation
			bit.w	#SET|CAL, R15
			jz		mmot_loop
			call	#WaitKey
			dint
			call	#RestartADC
			pop.w	R12
			eint
			jmp		MainBeg
			.endif
;}
;/ Load parameters from archive
;{
ArcLoad:
			.ifdef	FARC
			mov.w	&s_Rec, R14
			call	#Wait
			mov.w	#ARC_beg, R4
			mov.w	#CST_beg, R5
			mov.w	#VarSiz, R6
			call	#WriteFL
			jmp		Restart
			.endif
;}
;/ Save parameters in archive
;{
ArcSave:
			.ifdef	FARC
			mov.w	&s_Rec, R14
			call	#Wait
			mov.w	#CST_beg, R4
			mov.w	#ARC_beg, R5
			mov.w	#VarSiz, R6
			call	#WriteFL
			eint
			jmp		MainBeg
			.endif
;}
;/ Internal tests
;{
			.ifdef	DIBIT
IBIT:
			mov.w	#Tests_beg, R7			;/ Address of tests
test_loop:
			mov.w	@R7+, R4				;/ word 1: R4
			mov.w	@R7+, R5				;/ word 2: R5
			call	@R7+					;/ word 3: address of function
			cmp.w	@R7+, R6				;/ word 4: R6 expected
			jnz		test_fail
			cmp.w	#Tests_end, R7
			jnz		test_loop
			bis.w	#IB, &v_Status
			call	#WritePar
			eint
test_cont:
			mov.w	&v_Status, R4
			call	#PrintByte
in_loop:
			bit.w	#SET|CAL, R15
			jz		in_loop
			call	#WaitKey
			jmp		Restart
test_fail:
			bis.w	#WR, &v_Status			;/ Wrong result
			call	#RecordERR
			jmp		test_cont
			.endif
;}
;/ Save RAM in dump
;{
DumpRAM:
			.ifdef	FDUMP
			.ifdef	DEBUG
			mov.w	&s_Rec, R14
			call	#WaitKey
			call	#Wait
			call	#RecordERR
			jmp		MainBeg
			.endif
			.endif
;}
;}
;/ Main loop
;{
;/ Registers:
;/ R12:	number of cycles with motor ON
Main:
;{
			bis.b	#MOT, &P2OUT
			bis.w	#LGT, R15				;/ Start Motor
			clr.w	R4
			call	#PrintNum				;/ Display --
main_loop:
			tst.w	&v_H1Nb
			jz		main_loop
			mov.w	#HisNb, &v_H0Nb
			dint
			call	#RestartADC
			eint
;}
;/ Route choice
MainBeg:
;{
			bic.w	#SPD, R15				;/ Enable action
			.ifdef	DEBUG
			call	#Snapshot
			.endif
			mov.w	R15, R4
			and.w	#SET|CAL, R4
			add.w	R4, R0
			jmp		Compute					;/ No key pressed
			jmp		SetPoint				;/ Change SP
			jmp		Calibrate				;/ Calibrate
			jmp		Restart					;/ Reset
;}
;/ Compute or monitor
;{
Compute:
			.ifdef	DSIM
			bit.w	#STP, R15
			jz		nostop
			.ifdef	DEBUG
			call	#Snapshot
			.endif
			dint
endless:
			jmp		endless
nostop:
			.endif
			bit.w	#VAL, R15
			jnz		xH_last
;/ Check if probe is stabilized
			mov.w	#ValHis, R4
			mov.w	#v_H1, R5
			call	#HisVar
			cmp.w	#MAX, R6
			jz		MainBeg					;/ Not enough history
			tst.w	R6
			jge		xh_valtst
			inv.w	R6
			inc.w	R6
xh_valtst:
			cmp.w	#ValTol + 1, R6
			jl		xh_valok				;/ value <= ValTol
			cmp.w	#ValHis * 2 + 1, &v_H1Nb
			jl		MainBeg
			jge		BadProbe				;/ H1Nb >= 2 * history
xh_valok:
			bis.w	#VAL, R15
			dint
			call	#RestartADC
			eint
			jmp		MainBeg

;/ Take the last value
xH_last:
			mov.w	#1, R4
			mov.w	#v_H1, R5
			call	#HisMean
			tst.w	R6
			jz		MainBeg					;/ Waiting for 1st mean after stabilization
			mov.w	R6, R4

;/ Check direction
			bit.w	#DI, &v_Status
			jnz		xH_minus
			mov.w	&v_xHSP, R4				;/ xH+ R4=SP, R6=xH
			jmp		xH_calc
xH_minus:
			mov.w	&v_xHSP, R6				;/ xH- R4=xH, R6=SP

;/ Check discrepancy sign
xH_calc:
			sub.w	R6, R4
			cmp.w	#ActTol + 1, R4
			jl		StopAct					;/ R4 <= ActTol stop and monitor
;}
;/ R4 > ActTol:		need action
;{
			bit.w	#ACT, R15
			jz		send_dose
			jmp		Monitor

;/ Send dose
send_dose:
			tst.w	&v_H2Nb
			jz		MainBeg					;/ Not enough history to send liquid
			tst.w	&v_DosCnt
			jnz		calc_dos				;/ Compute dose to send
			cmp.w	#DosTol, R4
			jl		MainBeg					;/ R4 < DosTol, not enough discrepancy to launch dose calibration
			mov.w	#1, R4
			mov.w	#v_H1, R5
			call	#HisRead
			mov.w	R6, &v_RefxHM
			mov.w	#DosIni, R12			;/ No idea, so send DosIni
			add.w	R12, &v_RefMON			;/ Remember number of dose sent
			jmp		dose_end
calc_dos:
			mov.w	&v_DosCnt, R5
			call	#Multiply
			rra.w	R6
			rra.w	R6
			rra.w	R6
			rra.w	R6
			rra.w	R6
			mov.w	R6, R12					;/ R12 = abs(xH - SP) * DosCnt / 32
dose_end:
			dint
			call	#RestartADC
			eint
			bis.w	#ACT, R15
			bic.w	#END|EFF, R15
			jmp		MainBeg
;}
;/ R4 <= ActTol:	normal, stop action
;{
StopAct:
			bit.w	#ACT, R15
			jz		no_act
			tst.w	&v_DosCnt
			jnz		no_refmon
			sub.w	R12, &v_RefMON
no_refmon:
			clr.w	R12						;/ Stop action
			bic.w	#ACT, R15
no_act:
			tst.w	&v_RefxHM
			jz		MainBeg					;/ if dose calibration, go on with monitor
;}
;/ Monitor
;{
Monitor:
			mov.w	R15, R6
			and.w	#END|EFF, R6
			swpb	R6
			add.w	R6, R0
			jmp		EvalEFF					;/ !END !EFF -> Test EFF
			jmp		EvalEND					;/ !END  EFF -> Test END
			jmp		MainBeg					;/  END !EFF -> Impossible case
			jmp		EndEffect				;/  END  EFF -> End of effect

;/ Check if there is an effect
;{
EvalEFF:
			cmp.w	#HisNb, &v_H2Nb
			jz		LQEmpty					;/ No effect since too long
			cmp.w	#EffHis, &v_H2Nb
			jl		MainBeg					;/ Not enough history
			mov.w	#EffHis, R4
			mov.w	#v_H2, R5
			call	#HisRead
			mov.w	R6, R7
			mov.w	#1, R4
			call	#HisRead
			sub.w	R6, R7					;/ xH(x) - xH(1)
			jl		xH_inc
;/ xH decrease
			bit.w	#DI, &v_Status
			jnz		check_cvg
eval_save:
			tst.w	&v_DosCnt				;/ xH decrease with xH+, no effect
			jnz		MainBeg
			bit.w	#DI, &v_Status
			jz		above_ref
			cmp.w	&v_RefxHM, R6
			jl		MainBeg					;/ value under reference
			jmp		change_ref
above_ref:
			cmp.w	R6, &v_RefxHM
			jl		MainBeg					;/ value above reference
change_ref:
			mov.w	R6, &v_RefxHM
			jmp		MainBeg
;/ xH increase
xH_inc:
			bit.w	#DI, &v_Status
			jnz		eval_save				;/ xH increase with xH-, no effect
			inv.w	R7
			inc.w	R7
check_cvg:
			cmp.w	#EffTol, R7
			jl		MainBeg					;/ R7 < EffTol
			bis.w	#EFF, R15				;/ Set effect if variance is enough
			jmp		MainBeg
;}
;/ Check if effect is finished
;{
EvalEND:
			tst.w	R12
			jnz		MainBeg					;/ Still liquid to send
			mov.w	#EndHis, R4
			mov.w	#v_H2, R5
			call	#HisVar
			cmp.w	#EndTol + 1, R6
			jge		MainBeg					;/ value > EndTol
			bis.w	#END, R15
			jmp		MainBeg
;}
;/ End of effect
;{
EndEffect:
			tst.w	&v_DosCnt
			jnz		restart_act
			mov.w	#1, R4
			mov.w	#v_H2, R5
			call	#HisRead
			sub.w	&v_RefxHM, R6
			jge		comp_pos
			inv.w	R6
			inc.w	R6
comp_pos:
			mov.w	&v_RefMON, R4
			rla.w	R4
			rla.w	R4
			rla.w	R4
			rla.w	R4
			rla.w	R4
			mov.w	R6, R5
			call	#Divide
			mov.w	R6, &v_DosCnt			;/ DosCnt = total cycles * 32 / xH variance
			.ifdef	DEBUG
			clr.w	&v_RefxHM
			clr.w	&v_RefMON
			.endif
			tst.w	&v_DosCnt
			jz		restart_act				;/ Protection to avoid useless flash damage
			call	#WritePar
			eint

;/ End of effect
restart_act:
			bic.w	#ACT|END|EFF, R15
			jmp		MainBeg
;}
;}
;}
;/ SetPoint
;{
SetPoint:
			bis.w	#SPD, R15
			mov.w	&s_SP, R14
			call	#WaitKey
			call	#Wait
			mov.w	R15, R4
			and.w	#SET|CAL, R4
			add.w	R4, R0
			jmp		sp_start
			jmp		MainBeg
			.ifdef	DEBUG
			.ifdef	FDUMP
			jmp		DumpRAM
			.else
			jmp		MainBeg			
			.endif
			.else
			jmp		MainBeg
			.endif
			jmp		MainBeg

sp_start:			
			bit.w	#LQ, &v_Status
			jnz		sp_rH
			mov.w	#SPpHMin, R4
			mov.w	#SPpHMax, R5
			jmp		sp_cont
sp_rH:
			mov.w	#SPrHMin, R4
			mov.w	#SPrHMax, R5
sp_cont:
			mov.w	&v_xHSP, R6
			call	#GetVal
			mov.w	R6, &v_xHSP
			call	#WritePar				;/ Write set-point
			eint
			bic.w	#SPD, R15
			jmp		restart_act				;/ Exit
;}
;/ Calibrate
;{
;/ Registers:
;/ R11:	target xH
;/ R12:	number of cycles with motor ON
;/ R13:	entropy counter
Calibrate:
			bis.w	#SPD, R15
			mov.w	&s_CA, R14
			call	#WaitKey
			call	#Wait
			bic.w	#MAN, R15
			mov.w	R15, R4
			and.w	#SET|CAL, R4
			add.w	R4, R0
			jmp		AutCal
			jmp		ManCal
			jmp		MainBeg
			jmp		MainBeg

ManCal:
			mov.w	&s_CS, R14
			call	#WaitKey
			call	#Wait
			bis.w	#MAN, R15
AutCal:
			mov.w	&v_V1Ref, R11			;/ Choose V1 calibration
			push.w	#cal_dpl
			push.w	#cal_chg
			push.w	#MainBeg
			call	#GetState

;/ Begin calibration
CalIni:
			bit.w	#MAN, R15
			jz		cal_aut

;/ Manual calibration
			clr.w	R4
			call	#PrintNum
			call	#Wait
			mov.w	#xHMin, R4
			mov.w	#xHMax, R5
			mov.w	R11, R6
			call	#GetVal
			jmp		cal_comp				;/ End of manual calibration

;/ Automatic calibration
cal_aut:
			dint
			clr.w	R12						;/ Stop actions
			mov.w	#1, &v_H0Nb
			call	#RestartADC
			bis.w	#RAW, R15
			eint
CalBeg:
			cmp.w	#CalCpt, R13
			jge		BadProbe				;/ Number of tries exceeded
			mov.w	R13, R4
			call	#PrintSnk				;/ Display snake animation
			cmp.w	#CalNb, &v_H1Nb
			jl		CalBeg
			mov.w	#CalNb, R4
			mov.w	#v_H1, R5
			call	#HisVar
			cmp.w	#CalTol, R6				;/ Convergence ?
			jge		CalBeg					;/ Continue

;/ Good calibration
			call	#HisMean
			.ifdef	DEBUG
			mov.w	R6, R4
			call	#PrintNum
			call	#Wait
			.endif
			cmp.w	&v_V1Ref, R11
			jnz		cal_cmp2
			mov.w	R6, &v_CalV1			;/ Save new value
			sub.w	&v_V1Ref, R6
			jmp		cal_tst
cal_cmp2:
			mov.w	R6, &v_CalV2			;/ Save new value
			sub.w	&v_V2Ref, R6
cal_tst:
			tst.w	R6
			jge		cal_comp
			inv.w	R6
			inc.w	R6
cal_comp:
			cmp.w	&v_V1Ref, R11
			jnz		cal_V2

;/ First calibration
			bit.w	#LQ, &v_Status
			jnz		cal_1rH
;/ ApH = Ar with only V1 calibration
			mov.w	#ADpH, &v_CalA
			jmp		cal_write
;/ ArH = V1r * Ar / RV1
cal_1rH:
			mov.w	#V1rH * Ar, R4
			mov.w	&v_CalV1, R5
cal_rH:
			call	#Divide
			mov.w	R6, &v_CalA
			jmp		cal_check

;/ Second calibration
cal_V2:
			bit.w	#LQ, &v_Status
			jnz		cal_2rH
;/ ApH = (V1r - V2r) * Ar / (RV1 - RV2) with V2 calibration
			mov.w	#(V1pH - V2pH) * Ar, R4
			mov.w	&v_CalV1, R5
			sub.w	&v_CalV2, R5
			call	#Divide
			mov.w	R6, &v_CalA
cal_check:
			cmp.w	#AMax + 1, &v_CalA
			jge		BadProbe
			jmp		cal_write
cal_2rH:
;/ ArH = V2r * Ar / RV2
			mov.w	#V2rH * Ar, R4
			mov.w	&v_CalV2, R5
			jmp		cal_rH

;/ Check and save calibration
cal_write:
			call	#WritePar
			bic.w	#RAW, R15
			call	#RestartADC
			eint
			clr.w	R4
			call	#PrintNum				;/ Display -- until enough history
			clr.w	&v_RefxHM
			clr.w	&v_RefMON
			br		main_loop

;/ Reference calibration display
cal_dpl:
			mov.w	R11, R4
			call	#PrintNum
			ret

;/ Reference calibration change
cal_chg:
			cmp.w	&v_V1Ref, R11
			jnz		cal_chg_V1
			mov.w	&v_V2Ref, R11			;/ Calibration V2
			ret
cal_chg_V1:
			mov.w	&v_V1Ref, R11			;/ Calibration V1
			ret

;}
;/ Errors
;{
;/ Liquid empty
;{
LQEmpty:
			bis.w	#SPD, R15
			.ifdef	DEBUG
			bis.w	#NLE, R15
			call	#Snapshot
			.endif
empty_loop:
			mov.w	&s_NL, R14				;/ Display NL
			call	#Wait
			mov.w	&a_NL0, R14				;/ Display animation
			call	#Wait
			mov.w	&a_NL1, R14
			call	#Wait
			mov.w	&a_NL2, R14
			call	#Wait
			bit.w	#SET|CAL, R15
			jz		empty_loop
empty_cont:
			call	#WaitKey
			mov.w	&a_NL2, R14				;/ Display reverse animation
			call	#Wait
			mov.w	&a_NL1, R14
			call	#Wait
			mov.w	&a_NL0, R14
			call	#Wait
			jmp		Restart2
;}
;/ Bad probe
;{
BadProbe:
			bis.w	#SPD, R15
			mov.w	&s_Er, R14
			.ifdef	DEBUG
			bis.w	#PRE, R15
			.endif
cal_errlp:
			call	#WaitLED
			bit.w	#SET|CAL, R15
			jz		cal_errlp				;/ Wait for a key
			call	#WaitKey
Restart2:
			br		Restart
;}
;/ Flash violation interrupt: Generate an error
;{
FLASH:
			bis.w	#FV, &v_Status
			.ifdef	DEBUG
			call	#RecordERR
			.endif
			reti
;}
;}
;/ Interrupts
;{
;/ ADC10 interrupt: Read xH & manage motor
;/
;/ Registers:
;/ R12:	number of cycles with motor ON
;/ R13:	entropy counter
;{
ADC10:
			bit.w	#SPD, R15
			jnz		adc_stop

;/ Normal processing
			tst.w	R12						;/ Check cycle status
			jz		adc_stop
			dec.w	R12
			bis.b	#MOT, &P2OUT			;/ Start Motor
			tst.w	&v_DosCnt
			jnz		adc_dose				;/ Computed dose case
			bis.w	#LGT, R15				;/ Fixed LED when dose is not computed
			jmp		xHMean
adc_dose:
			xor.w	#LGT, R15				;/ Blink LED when dose is computed
			jmp		xHMean
adc_stop:
			bic.b	#MOT, &P2OUT			;/ Stop motor
			bic.w	#LGT, R15				;/ and LED

;/ Compute xH mean
xHMean:
			push.w	R4
			push.w	R5
			push.w	R6
			push.w	R15

;/ ReadxH
			.ifdef	DSIM
			bit.w	#STP, R15
			jnz		ADCEND
			cmp.w	0 * 2(R9), &v_SimEnt
			jl		sim_norm				;/ still in current sim bloc
			clr.w	&v_SimEnt
			add.w	#3 * 2, R9
			tst.w	0 * 2(R9)
			jz		sim_stop				;/ length null => sim end

;/ xH = v_SimEnt * (stop(R9) - start(R9)) / lenght(R9) + start(R9)
sim_norm:
			mov.w	&v_SimEnt, R4
			mov.w	2 * 2(R9), R5
			sub.w	1 * 2(R9), R5
			call	#Multiply
			mov.w	R6, R4
			mov.w	0 * 2(R9), R5
			call	#Divide
			add.w	1 * 2(R9), R6
			inc.w	&v_SimEnt
			.else
;/ Normal xH read
			mov.w	&v_H0Nb, R4
			mov.w	#v_H0, R5
			call	#HisMean
			.ifdef	DEBUG
			mov.w	#HisSiz - 2, R4
real_loop:
			clr.w	v_H0Val(R4)				;/ Clear H0 values
			decd.w	R4
			jge		real_loop
			.endif
			call	#CalcxH
			.endif

			inc.w	R13						;/ Augment entropy

;/ Mean 1 calculation
			mov.w	R6, R4
			mov.w	#v_H1, R5
			call	#HisSave
			mov.w	R13, R4
			and.w	#0x000F, R4
			jnz		ADCEND					;/ Stop here

;/ Mean 2 calculation
			mov.w	#HisNb, R4
			call	#HisMean
			mov.w	R6, R4
			mov.w	#v_H2, R5
			call	#HisSave
ADCEND:
			pop.w	R15
ADCSIMEND:
			pop.w	R6
			pop.w	R5
			pop.w	R4
			reti
			
			.ifdef	DSIM
;/ Stop simulation
sim_stop:
			pop.w	R15
			bis.w	#STP, R15
			.ifdef	DEBUG
			pop.w	R6
			pop.w	R5
			pop.w	R4
			call	#Snapshot
			reti
			.else
			jmp		ADCSIMEND
			.endif
			.endif
;}
;/ Timer Ax interrupt: Routing Ax interrupts
;{
TIMERAx:
			add.w	&TAIV, R0
			reti							;/ TACCR0
			jmp		TIMERA1					;/ TACCR1
			reti							;/ TACCR2
			reti
			reti
			reti							;/ TAIV
;}
;/ Timer A0 interrupt: Display and test keys
;/
;/ Registers:
;/ R14:	segments (MSB left, LSB right)
;/ R15:	status
;{
TIMERA0:
			add.w	#APer, &TACCR0			;/ Next stop
			push.w	R4
			push.w	R5
			bit.w	#LGT, R15
			jnz		light
			tst.w	&v_DosCnt
			jnz		nolight
			mov.w	&TAR, R4
			and.w	#0xFF00, R4
			jz		light
nolight:
			bic.b	#LED, &P2OUT
			jmp		a0next
light:
			bis.b	#LED, &P2OUT
a0next:
			mov.w	R14, R5
			.ifdef	DEBUG
;/ Light point if error dumped
			bit.w	#DO|FV, &v_Status
			jz		noerr
			bis.w	#0x0001, R5				;/ an error has been recorded
noerr:
			.endif
			bic.b	#0xFF, &P1DIR			;/ Read P1
			bis.b	#SKY, &P2OUT			;/ Enable key input
			mov.b	&P1IN, R4				;/ Get keys status
			bic.b	#SKY, &P2OUT			;/ Disable key input
			bis.b	#0xFF, &P1DIR			;/ Write P1
			xor.b	#SLR, &P2OUT
			bit.b	#SLR, &P2OUT
			jz		right
			swpb	R5
right:
			mov.b	R5, &P1OUT				;/ Print digit
			and.w	#SET|CAL, R4			;/ Filter information
			bis.w	#SET|CAL, R15			;/ Set keys in status register
			xor.w	R4, R15					;/ Change R15 status
A0END:
			pop.w	R5
			pop.w	R4
			reti
;}
;/ Timer A1 interrupt: Trigger ADC10 SHS
;{
TIMERA1:
			.ifdef	DSIM
			add.w	#SPer, &TACCR1			;/ Next stop
			.endif
			push.w	R4
			push.w	R5
			push.w	R6
			bit.w   #VAL, R15
			jnz		A1_displ
			bit.w	#2, R10
			jz		A1_null
A1_displ:
			tst.w	&v_H1Nb
			jz		h0_read
			mov.w	#1, R4
			mov.w	#v_H1, R5
			call	#HisMean				;/ Take the last value
			jmp		A1_save
h0_read:
			mov.w	&v_H0Nb, R4
			rla.w	R4
h0_loop:
			tst.w	v_H0Val - 2(R4)			;/ Get first H0 value not null
			jnz		h0_good
			decd.w	R4
			jnz		h0_loop
A1_null:
			clr.w	R6
			jmp		A1_save
h0_good:
			mov.w	v_H0Val - 2(R4), R6
			call	#CalcxH
A1_save:
			bit.w	#SPD, R15
			jnz		A1_exit
			mov.w	R6, R4
			call	#PrintNum
A1_exit:
			pop.w	R6
			pop.w	R5
			pop.w	R4
			inc.w	R10
			reti
;}
;/ Interrupt vectors
;{
			.org 0x0FE0
VECTORS:
			.word 0xFFFF
			.word 0xFFFF
			.word 0xFFFF	;/ P1IFG
			.word 0xFFFF	;/ P2IFG
			.word 0xFFFF
			.word ADC10		;/ ADC10
			.word 0xFFFF
			.word 0xFFFF
			.word TIMERAx	;/ Timer Ax
			.word TIMERA0	;/ Timer A0
			.word 0xFFFF	;/ Watchdog
			.word 0xFFFF
			.word 0xFFFF
			.word 0xFFFF
			.word FLASH		;/ Non maskable interrupt, oscillator fault, flash violation
			.word RESET		;/ Power on
;}
