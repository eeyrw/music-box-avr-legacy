#include <avr/io.h>
#include <stdio.h>
#include <avr/interrupt.h>

extern void TestProcess(void);



static int uart0_putchar(char c, FILE *stream);

static FILE mystdout = FDEV_SETUP_STREAM(uart0_putchar, NULL,
                                         _FDEV_SETUP_WRITE);

static int
uart0_putchar(char c, FILE *stream)
{
 	/* Wait for empty transmit buffer */
	while (!(UCSR0A & (1<<UDRE0)));
	UDR0 = c;
  return 0;
}

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

ISR(USART_RX_vect)
{
	unsigned char data;
	data = UDR0;                 
	/* Calculate buffer index */

}
int main(void)
{
	CLKPR=0b10000000;
	USART0_Init(115200);
	printf("UART works!\n");
	sei();
	TestProcess();
	return 0;
}