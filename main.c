#include <avr/io.h>
#include <stdio.h>
#include <avr/interrupt.h>
#include "Player.h"
#include "lgt8fx.h"

extern void TestProcess(void);
Player mainPlayer;


static int uart0_putchar(char c, FILE *stream);

static FILE uart0Stdout = FDEV_SETUP_STREAM(uart0_putchar, NULL,
                                         _FDEV_SETUP_WRITE);

static int
uart0_putchar(char c, FILE *stream)
{
 	/* Wait for empty transmit buffer */
	while (!(UCSR0A & (1<<UDRE0)));
	UDR0 = c;
  return 0;
}

#ifdef F_CPU
#undef F_CPU
#endif
#define F_CPU 32000000
/* Initialize UART */
void USART0_Init(uint32_t baud)
{
	/* Set the baud rate */
	uint16_t baudRegVal = (uint32_t)F_CPU/8/baud-1;
	UBRR0H = (unsigned char) (baudRegVal>>8);
	UBRR0L = (unsigned char) baudRegVal;
	
	/* Enable UART receiver and transmitter */
	UCSR0B = ((1<<RXEN0)|(1<<TXEN0)|(1 << RXCIE0));
	UCSR0A |=1<<U2X0;

	/* Set frame format: 8 data 2stop */
	UCSR0C = (1<<USBS0)|(1<<UCSZ01)|(1<<UCSZ00);
}

void TIMER_Init()
{
	PORTB=0b001101;		//Initalize Port B
	DDRB=0b000111;		

	TCCR1A=0b10100001;
	//ICNC1 ICES1 – WGM13 WGM12 CS12 CS11 CS10 ; Fast PWM pclk/1
	TCCR1B=0b00001001;

	OCR0A=124;		//Initalize TC0 in 32 kHz interval timer ( pclk=32M )
	TCCR0A=0b00000010;
	TCCR0B=0b00000010; //pclk/8
	TIMSK0=1<<OCIE0A; //Enable timer interrupt
}

void DAC_Init(void)
{
	DACON=((1<<DACEN)|(1<<DAOE));
	DALR=0;
	MCUCR|=1<<PUD;
	DDRD&=~(1<<4);
}

ISR(USART_RX_vect)
{
	unsigned char data;
	data = UDR0;                 
	/* Calculate buffer index */

}

int main(void)
{
	CLKPR=0b10000000;
	CLKPR=0b00000000;
	USART0_Init(115200);
	stdout = &uart0Stdout;
	printf("UART works!\n");
#ifndef RUN_TEST	
	PlayerInit(&mainPlayer,&synthForAsm);
	TIMER_Init();
	DAC_Init();

	sei();

	PlayerPlay(&mainPlayer);
	while (1)
	{
		PlayerProcess(&mainPlayer);
	}
#else
	TestProcess();
#endif
	return 0;
}