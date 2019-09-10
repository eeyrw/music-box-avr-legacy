#include <avr/io.h>
.text
.global SynthAsm
.global NoteOnAsm
.global GenDecayEnvlopeAsm

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

pIncrement_int=0
pIncrement_frac=1
pWavetablePos_frac=2
pWavetablePos_int_h=3
pWavetablePos_int_l=4
pEnvelopeLevel=5
pEnvelopePos=6
pVal=7
pSampleVal=9

pMixOut=SoundUnitSize*POLY_NUM
pLastSoundUnit=SoundUnitSize*POLY_NUM+2


ENVELOP_LEN=256
POLY_NUM=5
WAVETABLE_CELESTA_C5_ATTACK_LEN=1998
WAVETABLE_CELESTA_C5_LEN=2608
WAVETABLE_CELESTA_C5_LOOP_LEN=(WAVETABLE_CELESTA_C5_LEN - WAVETABLE_CELESTA_C5_ATTACK_LEN)


REG_TIM2_CCR2L=0x314+0x5000;
REG_TIM2_CCR3L=0x316+0x5000;




#define zl r30
#define zh r31
#define xl r26
#define xh r27
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

.extern	WaveTable_Celesta_C5

SynthAsm:

; 	clr a				
; 	push a			; Keep a loop index in stack
; 	clrw x
; 	pushw x				; Keep mixOut result in stack
; 	; The stack layout is:
; 	; (0x01,sp)=mixOut
; 	; (0x03,sp)=loop index
; 	; (0x04,sp)=PCH
; 	; (0x05,sp)=PCL
; 	; (0x06,sp)=synthesizer object's address.
	
; 	ldw y,(0x06, sp) 	; Load sound unit pointer to register Y.
push loopIndex
push mixOutl
push mixOuth
clr loopIndex
clr mixOutl
clr mixOuth
movw xl,arg0l
loopSynth:
	cpi loopIndex,POLY_NUM
	breq loopSynth_end
	ldd t2l,Z+pEnvelopeLevel ; Load evnvlopelevel to t2l
	cp t2l,zero
	breq loopSynthContinue
	ldd zl,Z+pWavetablePos_int_l ; Get a sample by pWavetablePos_int and save to t0l
	ldd zh,Z+pWavetablePos_int_h
	ldi t0l,WaveTable_Celesta_C5&0xFF
	ldi t0h,WaveTable_Celesta_C5>>8
	add xl,t0l
	adc xh,t0h
	lpm t0l,Z

	mulsu t0l,t2l ;r1:r0=sample*evnvlopelevel
	add mixOutl,r1
	adc mixOuth,r1
	clr r1 

	ldd t0l,Z+pIncrement_frac
	ldd t0h,Z+pWavetablePos_frac 
	add t0l,t0h
	std Z+pWavetablePos_frac,t0l

	ldd t0l,Z+pIncrement_int
	ldd t0h,Z+pWavetablePos_int_l
	adc t0l,t0h

	ldd t0h,Z+pWavetablePos_int_h
	adc t0h,zero

	cpi t0l,(WAVETABLE_CELESTA_C5_LEN&0xFF)
	ldi t1l,(WAVETABLE_CELESTA_C5_LEN>>8)
	cpc t0h,t1l
	brlo branch0_end
	subi t0l,(WAVETABLE_CELESTA_C5_LOOP_LEN&0xFF)
	ldi t1l,(WAVETABLE_CELESTA_C5_LOOP_LEN>>8)
	sbc t0h,t1l
	branch0_end:
	std Z+pWavetablePos_int_l,t0l
	std Z+pWavetablePos_int_h,t0h



; loopSynth$:
; 	ld a,(0x03,sp)
;     cp a,#POLY_NUM
;     jreq loopSynth_end$
; ; loop body
; 		ldw x,y
; 		ldw x,(pWavetablePos_int_h,x)	; Get a sample by pWavetablePos_int and save to a
; 		ld a,(_WaveTable_Celesta_C5,x)
; 		ld (pSampleVal,y),a

; 		ld a,(pEnvelopeLevel,y); Load evnvlopelevel to xl
; 		ld xl,a
; 		ld a,(pSampleVal,y)

; 		tnz a				; Test if a<0
; 		jrmi branch1_end$	; Do signed mutiple with unsigned MUL
; 		mul x,a
; 		swapw x				; Div with 0xFF
; 		ld a,#0
; 		ld xh,a
; 		jra branch2_end$	
; 	branch1_end$:
; 		neg a				;Do signed mutiple with unsigned MUL
; 		mul x,a				; Mutiple envelopeLevel with sample
; 		swapw x				; Div with 0xFF
; 		ld a,#0
; 		ld xh,a
; 		negw x
; 	branch2_end$:

; 		ldw (pVal,y),x

; 		addw x,(0x01,sp)
; 		ldw (0x01,sp),x

; 		; Do calculation :[pWavetablePos]+=[pIncrement]
; 		ld a,(pIncrement_frac,y) ; Get frac part of increment.
; 		add a,(pWavetablePos_frac,y) ; Add frac part of increment with frac part of wavetablePos.
; 		ld (pWavetablePos_frac,y),a ; Save frac result to frac part of wavetablePos.

; 		ld a,(pIncrement_int,y) ; Get integer part of increment.
; 		adc a,(pWavetablePos_int_l,y) ; Add integer part of increment with integer part L of wavetablePos and carrier from frac.
; 		ld (pWavetablePos_int_l,y),a ; Save integer result to integer part L of wavetablePos.
; 		ld xl,a		; Let X hold value of integer part of wavetablePos

; 		ld a,(pWavetablePos_int_h,y) ; integer part H of wavetablePos
; 		adc a,#0 ; integer part H of wavetablePos with carrier from integer part L.
; 		ld (pWavetablePos_int_h,y),a ; Save integer result  to integer part H of wavetablePos.
; 		ld xh,a   ; Let X hold value of integer part of wavetablePos

; 	branch0_start$:
; 		cpw x,#WAVETABLE_CELESTA_C5_LEN 	; Compare x (wavetablePos) with WAVETABLE_CELESTA_C5_LEN C=1 when WAVETABLE_CELESTA_C5_LEN>x
; 		jrc branch0_end$			; Jump if WAVETABLE_CELESTA_C5_LEN is great than x
; 		subw x,#WAVETABLE_CELESTA_C5_LOOP_LEN ; Subtract x with WAVETABLE_CELESTA_C5_LOOP_LEN
; 	branch0_end$:
; 		ldw (pWavetablePos_int_h,y),x ;
loopSynthContinue:						
;     inc (0x03,sp)
; 	addw y,#SoundUnitSize
;     jra loopSynth$

inc loopIndex
ldi t0l,SoundUnitSize
add zl,t0l
adc zh,zero

loopSynth_end:
; 	ldw y,(0x06, sp) 
; 	ldw x,(0x01,sp)
; 	ldw (pMixOut,y),x
; 	;sraw x
; 	cpw x,#253
; 	jrslt branch_lt_253$
; 	ldw x,#253
; branch_lt_253$:
; 	cpw x,#-255
; 	jrsgt branch_lt_gt_end$
; 	ldw x,#-255
; branch_lt_gt_end$:	

; 	sraw x
; 	ld a,xl
; 	sub a,#0x80
; 	ld REG_TIM2_CCR2L,a
; 	cpl a
; 	ld REG_TIM2_CCR3L,a	

; 	addw sp,#3
pop mixOuth
pop mixOutl
pop loopIndex
 	ret

GenDecayEnvlopeAsm:
; 	clr a				; Register A as loop index.
; 	ldw y,(0x03, sp) 		; Load sound unit pointer to register Y. (0x03, sp) is synthesizer object's address.
; loopGenDecayEnvlope$:
;     cp a,#POLY_NUM
;     jreq loopGenDecayEnvlope_end$
; 	push a				; Keep a as temporary variable
; 	; loop body

; 	;    SoundUnitUnion* soundUnionList=&(synth->SoundUnitUnionList[0]);
; 	;	for (uint8_t i = 0; i < POLY_NUM; i++)
; 	;	{
; 	;		if(soundUnionList[i].combine.wavetablePos_int >= WAVETABLE_CELESTA_C5_ATTACK_LEN &&
; 	;				soundUnionList[i].combine.envelopePos < sizeof(EnvelopeTable)-1)
; 	;		{
; 	;			soundUnionList[i].combine.envelopeLevel = EnvelopeTable[soundUnionList[i].combine.envelopePos];
; 	;			soundUnionList[i].combine.envelopePos += 1;
; 	;		}
; 	;	}

; 	ldw x,y
; 	ldw x,(pWavetablePos_int_h,x)
; 	cpw x,#WAVETABLE_CELESTA_C5_ATTACK_LEN
; 	jrc envelopUpdateEnd$
; 	ld a,(pEnvelopePos,y)
; 	cp a,#(ENVELOP_LEN-1)
; 	jrnc envelopUpdateEnd$
; 	ld a,(pEnvelopePos,y)
; 	clrw x
; 	ld xl,a
; 	ld a,(_EnvelopeTable,x)
; 	ld (pEnvelopeLevel,y),a
; 	inc (pEnvelopePos,y)

; envelopUpdateEnd$:	
						
; 	pop a
;     inc a
; 	addw y,#SoundUnitSize
;     jra loopGenDecayEnvlope$
; loopGenDecayEnvlope_end$:

ret

NoteOnAsm:
; 	ldw y,(0x03, sp) 		; Load sound unit pointer to register Y. (0x03, sp) is synthesizer object's address.
; 	;void NoteOn(Synthesizer* synth,uint8_t note)
; 	;{
; 	;	uint8_t lastSoundUnit = synth->lastSoundUnit;

; 	;	disable_interrupts();
; 	;	synth->SoundUnitUnionList[lastSoundUnit].combine.increment = PitchIncrementTable[note&0x7F];
; 	;	synth->SoundUnitUnionList[lastSoundUnit].combine.wavetablePos_frac = 0;
; 	;	synth->SoundUnitUnionList[lastSoundUnit].combine.wavetablePos_int = 0;
; 	;	synth->SoundUnitUnionList[lastSoundUnit].combine.envelopePos = 0;
; 	;	synth->SoundUnitUnionList[lastSoundUnit].combine.envelopeLevel = 255;
; 	;	enable_interrupts();

; 	;	lastSoundUnit++;

; 	;	if (lastSoundUnit== POLY_NUM)
; 	;		lastSoundUnit = 0;

; 	;	synth->lastSoundUnit=lastSoundUnit;
; 	;}
; 	ldw x,#SoundUnitSize
; 	ld a,(pLastSoundUnit,y)
; 	mul x,a
; 	addw x,(0x03, sp)
; 	ldw y,x
; 	ld a,(0x05, sp) ;uint8_t note
; 	sla a ;note*=2 and drop bit7
; 	clrw x
; 	ld xl,a
; 	sim ;disable interrupt
; 	ldw x,(_WaveTable_Celesta_C5_Increment,x)
; 	ldw (pIncrement_int,y),x
; 	clr (pWavetablePos_frac,y)
; 	clr (pWavetablePos_int_h,y)
; 	clr (pWavetablePos_int_l,y)
; 	clr (pEnvelopePos,y)
; 	ld a,#255
; 	ld (pEnvelopeLevel,y),a
; 	rim ;enable interrput

; 	ldw y,(0x03, sp)
; 	ld a,(pLastSoundUnit,y)
; 	inc a
; 	cp a,#POLY_NUM
; 	jrne lastSoundUnitUpdateEndNotEq$
; 	clr a
; lastSoundUnitUpdateEndNotEq$:
; 	ld (pLastSoundUnit,y),a


ret
.end

