#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <avr/io.h>
#include "SynthCore.h"
#include "Player.h"

extern unsigned char Score[];
Player mainPlayer;

void PlayerProcess(Player *player)
{

    uint8_t temp;
    
    if (player->synthesizerPointer->decayGenTick >= 150)
    {
        GenDecayEnvlopeAsm();
        player->synthesizerPointer->decayGenTick = 0;
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
    player->currentTick = 0;
    player->lastScoreTick = 0;
    player->scorePointer = Score;
    PlayUpdateNextScoreTick(player);
    player->status = STATUS_PLAYING;

}

void PlayerInit(Player *player,Synthesizer *synthesizer)
{
    player->status = STATUS_STOP;
    player->currentTick = 0;
    player->lastScoreTick = 0;
    player->scorePointer = Score;
    player->synthesizerPointer = synthesizer;
    SynthInit(synthesizer);
}