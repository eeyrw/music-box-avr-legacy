#ifdef RUN_TEST
#include "SynthCore.h"
#include "Player.h"
#include <stdint.h>
#include <stdio.h>

#define TEST_LOOP_NUN 10000

void TestInit(void)
{ 
    SynthInit(&synthForC);
    SynthInit(&synthForAsm);
}

int16_t abs_u16(int16_t num)
{
    return num > 0 ? num : -num;
}

void PrintParameters(Synthesizer *synth)
{
    SoundUnitUnion *soundUnionList;
    printf("MixOut:%d\n", synth->mixOut);
    soundUnionList = &(synth->SoundUnitUnionList[0]);

    printf("%12s", "Chn Val");
    for (uint8_t k = 0; k < POLY_NUM; k++)
    {
        printf("%6d ", soundUnionList[k].combine.val);
    }
    printf("\n");

    printf("%12s", "Chn Sample");
    for (uint8_t k = 0; k < POLY_NUM; k++)
    {
        printf("%6d ", soundUnionList[k].combine.sampleVal);
    }
    printf("\n");

    printf("%12s", "Chn EnvLevel");
    for (uint8_t k = 0; k < POLY_NUM; k++)
    {
        printf("%6d ", soundUnionList[k].combine.envelopeLevel);
    }
    printf("\n");

    printf("%12s", "Chn WavePos");
    for (uint8_t k = 0; k < POLY_NUM; k++)
    {
        printf("%6d ", soundUnionList[k].combine.wavetablePos_int);
    }
    printf("\n");

    printf("%12s", "Chn EnvlPos");
    for (uint8_t k = 0; k < POLY_NUM; k++)
    {
        printf("%6d ", soundUnionList[k].combine.envelopePos);
    }
    printf("\n");

    printf("%12s", "Chn NoteIncr");
    for (uint8_t k = 0; k < POLY_NUM; k++)
    {
        printf("%6d ", soundUnionList[k].combine.increment);
    }
    printf("\n");
}

void TestUpdateTickFunc(void)
{
    uint32_t i;
    Player player;
    PlayerInit(&player,&synthForC);
    printf("~~~~~~~Start testing updateTickFunc.~~~~~~~\n");
    for (i = 0; i < 0xffff; i++)
    {
        if (i != player.currentTick)
        {
            printf("UpdateTickFunc get wrong in %ld loop.\n", i);
            break;
        }
        UpdateTick(&player);
    }
    if (i == player.currentTick)
        printf("UpdateTickFunc passed the test.\n");
}

uint8_t SynthParamterCompare(Synthesizer *synthA, Synthesizer *synthB)
{
    uint8_t error = 0;
    SoundUnitUnion *sa = &(synthA->SoundUnitUnionList[0]);
    SoundUnitUnion *sb = &(synthB->SoundUnitUnionList[0]);

    if (abs_u16(synthA->mixOut - synthB->mixOut) > POLY_NUM)
        error++;
    for (uint8_t k = 0; k < POLY_NUM; k++)
    {
        if (abs_u16(sa[k].combine.val - sb[k].combine.val) > 2)
            error++;
        if (sa[k].combine.sampleVal != sb[k].combine.sampleVal)
            error++;
        if (sa[k].combine.envelopeLevel != sb[k].combine.envelopeLevel)
            error++;
        if (sa[k].combine.envelopePos != sb[k].combine.envelopePos)
            error++;
        if (sa[k].combine.wavetablePos_frac != sb[k].combine.wavetablePos_frac)
            error++;
        if (sa[k].combine.wavetablePos_int != sb[k].combine.wavetablePos_int)
            error++;
        if (sa[k].combine.increment != sb[k].combine.increment)
            error++;
    }
    if (error > 0)
    {
        printf("%d error(s) found:\n", error);
        printf("Synth C:\n");
        PrintParameters(&synthForC);
        printf("Synth ASM:\n");
        PrintParameters(&synthForAsm);
    }
    else
    {
        printf("Passed.\n");
    }
    return error;
}

void TestSynth(void)
{
    printf("~~~~~~~Start testing synthesizer.~~~~~~~\n");
    for (uint8_t i = 0; i < POLY_NUM; i++)
    {
        NoteOnC(i % 56);
        NoteOnAsm(i % 56);
    }
    for (uint16_t i = 0; i < TEST_LOOP_NUN; i++)
    {
        //PlayerProcess(&mainPlayer);
        NoteOnC(i % 56);
        NoteOnAsm(i % 56);

        SynthAsm();
        SynthC();
        GenDecayEnvlopeAsm();
        GenDecayEnvlopeC();
        GenDecayEnvlopeAsm();
        GenDecayEnvlopeC();
        GenDecayEnvlopeAsm();
        GenDecayEnvlopeC();
        NoteOnC(i % 56);
        NoteOnAsm(i % 56);
        GenDecayEnvlopeAsm();
        GenDecayEnvlopeC();
        GenDecayEnvlopeAsm();
        GenDecayEnvlopeC();
        GenDecayEnvlopeAsm();
        GenDecayEnvlopeC();

        printf("=============%d==============\n", i);
        if (SynthParamterCompare(&synthForC, &synthForAsm) > 0)
            break;
    }
}

void TestProcess(void)
{
    TestInit();
    TestUpdateTickFunc();
    TestSynth();
}
#endif