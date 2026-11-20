// Driver minimo do gpio_periph. Ajuste GPIO_BASE ao seu mapa de enderecos.
#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

#define GPIO_BASE  0xFF002000u
#define GPIO_DIR   (*(volatile uint32_t *)(GPIO_BASE + 0x00))  // 1 = saida
#define GPIO_OUT   (*(volatile uint32_t *)(GPIO_BASE + 0x04))  // valor de saida
#define GPIO_IN    (*(volatile uint32_t *)(GPIO_BASE + 0x08))  // leitura dos pinos
#define GPIO_SET   (*(volatile uint32_t *)(GPIO_BASE + 0x0C))  // OUT |=  valor
#define GPIO_CLR   (*(volatile uint32_t *)(GPIO_BASE + 0x10))  // OUT &= ~valor

#endif
