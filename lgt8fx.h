#ifndef __LGT8FX_H__
#define __LGT8FX_H__

#ifdef __ASSEMBLER__
#define DACON 0xA0
#else
#define DACON (*(volatile uint8_t *)(0xA0))
#endif
#define DACEN 3
#define DAOE 2
#define DAVS1 1
#define DAVS0 0

#ifdef __ASSEMBLER__
#define DALR 0xA1
#else
#define DALR (*(volatile uint8_t *)(0xA1))
#endif

#ifdef __ASSEMBLER__
#define DIDR2 0xA1
#else
#define DIDR2 (*(volatile uint8_t *)(0x76))
#endif

#endif