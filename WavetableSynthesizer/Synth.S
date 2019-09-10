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

.extern	WaveTable_Celesta_C5

SynthAsm:

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
	movw t1l,zl
	ldd zl,Z+pWavetablePos_int_l ; Get a sample by pWavetablePos_int and save to t0l
	ldd zh,Z+pWavetablePos_int_h
	ldi t0l,lo8(WaveTable_Celesta_C5)
	ldi t0h,hi8(WaveTable_Celesta_C5)
	add zl,t0l
	adc zh,t0h
	lpm t0l,Z
	movw zl,t1l
	std Z+pSampleVal,t0l


	mulsu t0l,t2l ;r1:r0=sample*evnvlopelevel
	std Z+pVal,r0
	std Z+(pVal+1),r1
	add mixOutl,r1
	adc mixOuth,zero
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

	cpi t0l,lo8(WAVETABLE_CELESTA_C5_LEN)
	ldi t1l,hi8(WAVETABLE_CELESTA_C5_LEN)
	cpc t0h,t1l
	brlo branch0_end
	subi t0l,lo8(WAVETABLE_CELESTA_C5_LOOP_LEN)
	ldi t1l,hi8(WAVETABLE_CELESTA_C5_LOOP_LEN)
	sbc t0h,t1l
	branch0_end:
	std Z+pWavetablePos_int_l,t0l
	std Z+pWavetablePos_int_h,t0h
loopSynthContinue:						
inc loopIndex
ldi t0l,SoundUnitSize
add zl,t0l
adc zh,zero
rjmp loopSynth

loopSynth_end:
; 	ldw y,(0x06, sp) 
; 	ldw x,(0x01,sp)
; 	ldw (pMixOut,y),x
movw xl,arg0l
std Z+pMixOut,mixOutl
std Z+pMixOut+1,mixOuth

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
subi	t0l, 0x80	; EL=EL-0x80
mov	t0h, t0l			; 
com	t0h				; EH取反
sbrc	mixOuth, 7		; 如果T2H的第七位是0就跳过下面一行
inc	t0l				; EL++
sts OCR1AL,t0l
sts OCR1BL,t0h

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

