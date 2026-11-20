// Teste do gpio_periph na PYNQ-Z2:
//   GPIO[3:0] = LD0..LD3 (saida), GPIO[7:4] = BTN0..BTN3 (entrada)
// Le os 4 botoes periodicamente e copia o estado para os 4 LEDs
// (BTN0 -> LD0, ..., BTN3 -> LD3). Mudancas tambem saem pela UART.
#include <stdint.h>
#include <stdio.h>
#include "uart.h"
#include "gpio.h"

#define LED_MASK  0x0Fu   // bits 3:0
#define BTN_SHIFT 4       // botoes em 7:4

// Pausa entre leituras (~100 ms com o clock de 25 MHz; ajuste a contagem)
static void pausa(void) { for (volatile uint32_t i = 0; i < 250000; i++) ; }

int main(void)
{
    GPIO_OUT = 0;
    GPIO_DIR = LED_MASK;            // so os LEDs viram saida; botoes ficam entrada

    printf("\n=== Teste GPIO: botoes -> LEDs ===\n");
    printf("DIR=0x%02X IN=0x%02X\n", (unsigned)GPIO_DIR, (unsigned)GPIO_IN);

    uint32_t anterior = 0xFFFFFFFFu;
    while (1) {
        uint32_t btn = (GPIO_IN >> BTN_SHIFT) & 0xFu;
        GPIO_OUT = btn;             // escreve os 4 LEDs de uma vez

        if (btn != anterior) {
            printf("botoes = %u%u%u%u (BTN3..BTN0)\n",
                   (unsigned)(btn >> 3) & 1u, (unsigned)(btn >> 2) & 1u,
                   (unsigned)(btn >> 1) & 1u, (unsigned)btn & 1u);
            anterior = btn;
        }
        pausa();
    }
}
