#include <avr/io.h>

.extern	UpdateTick
.extern GenDecayEnvlopeAsm
.extern SynthAsm


#define PeriodTimerHandler TIMER0_COMPA_vect
;typedef struct _SoundUnit
;{
;	uint8_t increment_frac;
;	uint8_t increment_int;
;	uint8_t  wavetablePos_frac;
;	uint16_t  wavetablePos_int;
;	uint8_t envelopeLevel;
;	uint8_t envelopePos;
;	int16_t val;
;	int8_t sampleVal;
;} SoundUnit;


;typedef struct _Synthesizer
;{
;    SoundUnitUnion SoundUnitUnionList[POLY_NUM];
;	int16_t mixOut;
;    uint8_t lastSoundUnit;
;}Synthesizer;

SoundUnitSize=10

pIncrement_int=1
pIncrement_frac=0
pWavetablePos_frac=2
pWavetablePos_int_h=4
pWavetablePos_int_l=3
pEnvelopeLevel=5
pEnvelopePos=6
pVal=7
pSampleVal=9

pMixOut=SoundUnitSize*POLY_NUM
pLastSoundUnit=SoundUnitSize*POLY_NUM+2


ENVELOP_LEN=256
POLY_NUM=6
WAVETABLE_CELESTA_C5_ATTACK_LEN=1998
WAVETABLE_CELESTA_C5_LEN=2608
WAVETABLE_CELESTA_C5_LOOP_LEN=(WAVETABLE_CELESTA_C5_LEN - WAVETABLE_CELESTA_C5_ATTACK_LEN)




#define xl r26
#define xh r27
#define yl r28
#define yh r29
#define zl r30
#define zh r31
#define zero r1
#define t0l r18
#define t0h r19
#define t1l r20
#define t1h r21
#define t2l r22
#define t2h r23
#define mixOutl r14
#define mixOuth r15
#define loopIndex r16

#define arg0l r24
#define arg0h r25
#define arg1l r22
#define arg1h r23

.extern	WaveTable_Celesta_C5
.extern	EnvelopeTable
.extern WaveTable_Celesta_C5_Increment
.extern synthForAsm

.section .bss
.global currentTick
currentTick:
.skip 4
.global decayGenTick
decayGenTick:
.skip 1

.section .text
.global PeriodTimerHandler
PeriodTimerHandler:
	sbi _SFR_IO_ADDR(PORTB),0
	in	r0, _SFR_IO_ADDR(SREG)
	push r0
	push r18
	push r19
	push r20
	push r21	
	push r30
	push r31
    ;call SynthAsm

	SynthAsm: ; Register usage: t0l,t0h:r18,r19 t1l,t1h:r20,r21 zl,zh:r30,r31
	push yl
	push yh
	push loopIndex
	push mixOutl
	push mixOuth
	clr loopIndex
	clr mixOutl
	clr mixOuth
	ldi yl,lo8(synthForAsm)
	ldi yh,hi8(synthForAsm)
	loopSynth:
		cpi loopIndex,POLY_NUM
		breq loopSynth_end
		ldd t1h,Y+pEnvelopeLevel ; Load evnvlopelevel to t1h	
		cp t1h,zero
		breq loopSynthContinue	
		ldd zl,Y+pWavetablePos_int_l ; Get a sample by pWavetablePos_int and save to t0l
		ldd zh,Y+pWavetablePos_int_h


		ldd t0l,Y+pIncrement_frac
		ldd t0h,Y+pWavetablePos_frac 
		add t0l,t0h
		std Y+pWavetablePos_frac,t0l

		ldd t0l,Y+pIncrement_int
		adc t0l,zl

		mov t0h,zh
		adc t0h,zero

		cpi t0l,lo8(WAVETABLE_CELESTA_C5_LEN+1) ; "+1" is to realize "<="
		ldi t1l,hi8(WAVETABLE_CELESTA_C5_LEN+1)
		cpc t0h,t1l
		brlo branch0_end
		subi t0l,lo8(WAVETABLE_CELESTA_C5_LOOP_LEN)
		ldi t1l,hi8(WAVETABLE_CELESTA_C5_LOOP_LEN)
		sbc t0h,t1l
		branch0_end:
		std Y+pWavetablePos_int_l,t0l
		std Y+pWavetablePos_int_h,t0h



		ldi t0l,lo8(WaveTable_Celesta_C5)
		ldi t0h,hi8(WaveTable_Celesta_C5)
		add zl,t0l
		adc zh,t0h
		lpm t0l,Z
	#ifdef RUN_TEST
		std Y+pSampleVal,t0l
	#endif
		mulsu t0l,t1h ;r1:r0=sample*evnvlopelevel
		clr r0 ;(r1:r0)/255
		sbrc r1,7 ;skip if bit 7(sign bit of signed 16) of r1 is 0
		com r0 ;~r0=0xFF
	#ifdef RUN_TEST	
		std Y+pVal,r1
		std Y+(pVal+1),r0
	#endif	
		add mixOutl,r1 ; mixOut+=(r1:r0)>>8
		clr r1 ; Always keep r1(zero)=0
		adc mixOuth,r0

	loopSynthContinue:						
	inc loopIndex
	ldi t0l,SoundUnitSize
	add yl,t0l
	adc yh,zero
	rjmp loopSynth

	loopSynth_end:
	#ifdef RUN_TEST
	sts synthForAsm+pMixOut,mixOutl
	sts synthForAsm+pMixOut+1,mixOuth
	#endif

	asr mixOuth
	ror mixOutl

	ldi	t0l, lo8(253)			;Clip it between -255 to 253
	ldi t0h, hi8(253)
	cp mixOutl,t0l
	cpc mixOuth,t0h
	brlt	higherBoundSatisfied			;
	movw	mixOutl, t0l			;
	higherBoundSatisfied:
	ldi	t0l, lo8(-255)			;
	ldi t0h, hi8(-255)
	cp mixOutl,t0l
	cpc mixOuth,t0h	;
	brge	lowerBoundSatisfied			;
	movw	mixOutl, t0l			;/
	lowerBoundSatisfied:
	asr mixOuth ; Set it to PWM modulator ： 把16位的T2带符号位右移一位，除以2，最低位移到Carrier 
	ror mixOutl			
	ror	mixOuth				; 把T2H的高位右移，Carrier进到T2H的第七位
	mov	t0l, mixOutl			; 复制T2L到EL
	subi t0l, 0x80	; EL=EL-0x80
	mov	t0h, t0l			; 
	com	t0h				; EH取反
	sbrc mixOuth, 7		; 如果T2H的第七位是0就跳过下面一行
	inc	t0l				; EL++
	sts OCR1AL,t0l
	sts OCR1BL,t0h

	pop mixOuth
	pop mixOutl
	pop loopIndex
	pop yh
	pop yl


    ;call UpdateTick
 
	sec
	lds t0l,currentTick
	adc t0l,zero
	sts currentTick,t0l
	lds t0l,currentTick+1
	adc t0l,zero
	sts currentTick+1,t0l
	lds t0l,currentTick+2
	adc t0l,zero
	sts currentTick+2,t0l
	lds t0l,currentTick+3
	adc t0l,zero
	sts currentTick+3,t0l

	lds t0l,decayGenTick
	cpi t0l,80
	brsh updateDecayGenTickEnd ; BRSH – Branch if Same or Higher (Unsigned)
	inc t0l
	sts decayGenTick,t0l
	updateDecayGenTickEnd:

	pop r31
	pop r30
	pop r21	
	pop r20
	pop r19
	pop r18
	pop r0
	out	_SFR_IO_ADDR(SREG), r0
	cbi _SFR_IO_ADDR(PORTB),0
	reti