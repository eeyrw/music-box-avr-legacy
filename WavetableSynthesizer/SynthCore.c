#include "SynthCore.h"
#include <stdint.h>
#include <stdio.h>
#include "WaveTable_Celesta_C5.h"
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>

#ifdef RUN_TEST
Synthesizer synthForC;
#endif

Synthesizer synthForAsm;


void SynthInit(Synthesizer* synth)
{
    SoundUnitUnion* soundUnionList=&(synth->SoundUnitUnionList[0]);
	for (uint8_t i = 0; i < POLY_NUM; i++)
	{
		soundUnionList[i].combine.increment = 0;
		soundUnionList[i].combine.wavetablePos_frac = 0;
		soundUnionList[i].combine.wavetablePos_int = 0;
		soundUnionList[i].combine.envelopeLevel = 255;
		soundUnionList[i].combine.envelopePos = 0;
        soundUnionList[i].combine.val = 0;
	}
    synth->lastSoundUnit=0;
}
#ifdef RUN_TEST
void NoteOnC(uint8_t note)
{
	uint8_t lastSoundUnit = synthForC.lastSoundUnit;

	cli();
	synthForC.SoundUnitUnionList[lastSoundUnit].combine.increment = pgm_read_word(&WaveTable_Celesta_C5_Increment[note&0x7F]);
	synthForC.SoundUnitUnionList[lastSoundUnit].combine.wavetablePos_frac = 0;
	synthForC.SoundUnitUnionList[lastSoundUnit].combine.wavetablePos_int = 0;
	synthForC.SoundUnitUnionList[lastSoundUnit].combine.envelopePos = 0;
	synthForC.SoundUnitUnionList[lastSoundUnit].combine.envelopeLevel = 255;
	sei();

	lastSoundUnit++;

	if (lastSoundUnit== POLY_NUM)
		lastSoundUnit = 0;

    synthForC.lastSoundUnit=lastSoundUnit;
}

void SynthC(void)
{
    synthForC.mixOut=0;
    SoundUnitUnion* soundUnionList=&(synthForC.SoundUnitUnionList[0]);
    for(uint8_t i=0;i<POLY_NUM;i++)
    {
		if(soundUnionList[i].combine.envelopeLevel==0)
			continue;
        soundUnionList[i].combine.val=soundUnionList[i].combine.envelopeLevel*(int8_t)pgm_read_byte(&WaveTable_Celesta_C5[soundUnionList[i].combine.wavetablePos_int])>>8;
        soundUnionList[i].combine.sampleVal=(int8_t)pgm_read_byte(&WaveTable_Celesta_C5[soundUnionList[i].combine.wavetablePos_int]);
		uint32_t waveTablePos=soundUnionList[i].combine.increment+
                             soundUnionList[i].combine.wavetablePos_frac+
                             ((uint32_t)soundUnionList[i].combine.wavetablePos_int<<8); 

        uint16_t waveTablePosInt= waveTablePos>>8;
        if(waveTablePosInt>WAVETABLE_CELESTA_C5_LEN)
           waveTablePosInt-=WAVETABLE_CELESTA_C5_LOOP_LEN;
        soundUnionList[i].combine.wavetablePos_int= waveTablePosInt;
        soundUnionList[i].combine.wavetablePos_frac=0xFF&waveTablePos;
        synthForC.mixOut+=soundUnionList[i].combine.val;
    }
}

void GenDecayEnvlopeC(void)
{
    SoundUnitUnion* soundUnionList=&(synthForC.SoundUnitUnionList[0]);
	for (uint8_t i = 0; i < POLY_NUM; i++)
	{
		if(soundUnionList[i].combine.wavetablePos_int >= WAVETABLE_CELESTA_C5_ATTACK_LEN &&
				soundUnionList[i].combine.envelopePos <sizeof(EnvelopeTable)-1)
		{
			soundUnionList[i].combine.envelopeLevel = pgm_read_byte(&EnvelopeTable[soundUnionList[i].combine.envelopePos]);
			soundUnionList[i].combine.envelopePos += 1;
		}
	}
}
#endif