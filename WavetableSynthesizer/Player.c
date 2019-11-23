#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <avr/io.h>
#include "SynthCore.h"
#include "Player.h"
#include "PeriodTimer.h"

extern unsigned char Score[];

void PlayerProcess(Player *player)
{

    uint8_t temp;
    
    if (decayGenTick >= 150)
    {
        GenDecayEnvlopeAsm();
        decayGenTick = 0;
    }
    if (player->status == STATUS_PLAYING)
    {
        if(PlayNoteTimingCheck(player))
        {
            do
            {
                temp = pgm_read_byte(player->scorePointer);
                player->scorePointer++;
                if (temp == 0xFF)
                {
                    player->status = STATUS_STOP;
                }
                else
                {
                    NoteOnAsm(temp);
                    //printf("Note On:%02x\n",temp);
                }
            } while ((temp & 0x80) == 0);
            PlayUpdateNextScoreTick(player);
        }
    }
}

void PlayerPlay(Player *player)
{
    player->lastScoreTick = 0;
    player->scorePointer = Score;
    currentTick=0;
    PlayUpdateNextScoreTick(player);
    player->status = STATUS_PLAYING;

}

void PlayerInit(Player *player,Synthesizer *synthesizer)
{
    player->status = STATUS_STOP;
    player->lastScoreTick = 0;
    currentTick=0;
    player->scorePointer = Score;
    player->synthesizerPointer = synthesizer;
    SynthInit(synthesizer);
}