// Teste do spi_periph contra um ESP32-C3 escravo (ligado no CS0).
// Os logs saem pela UART; o que o ESP recebeu aparece no monitor serial dele.
// No fim: GPIO0 = 1 se tudo passou, GPIO1 = 1 se algo falhou.
#include <stdint.h>
#include <stdio.h>
#include "uart.h"
#include "spi.h"

// #define GPIO_BASE 0xFF002000u
// #define GPIO_DIR  (*(volatile uint32_t *)(GPIO_BASE + 0x00))
// #define GPIO_SET  (*(volatile uint32_t *)(GPIO_BASE + 0x0C))

#define CLK_FREQ  100000000u // clock do SoC (ajuste ao da FPGA)
#define SPI_MODE  0          // igual ao SPI_MODE do ESP

// Espera o ESP imprimir e preparar a proxima transacao (~10-50 ms).
// Ajuste a contagem ao seu clock.
static void pausa(void) { for (volatile uint32_t i = 0; i < 1000000; i++) ; }

static void configura(uint32_t clkdiv)
{
    spi_init(SPI_MODE, clkdiv);
    printf("[cfg] modo %u, CLKDIV %u -> SCLK = %u kHz | CTRL=0x%X CS=0x%X\n",
           SPI_MODE, clkdiv, CLK_FREQ / (2 * (clkdiv + 1)) / 1000,
           SPI_CTRL, SPI_CS);
}

// Envia 4 bytes com o CS escolhido ativo o tempo todo.
// Retorna 1 se o mestre recebeu A0 A1 A2 A3 de volta.
static int rajada(uint32_t cs)
{
    uint8_t rx[4];
    int ok = 1;

    spi_select(cs);
    for (uint32_t i = 0; i < 4; i++) {
        rx[i] = spi_transfer(0x11 * (i + 1));
        if (rx[i] != 0xA0 + i) ok = 0;
    }
    spi_deselect();

    // Imprime so depois de soltar o CS, para nao atrasar a transferencia
    printf("  CS%u: enviou 11 22 33 44 | recebeu %02X %02X %02X %02X | %s\n",
           cs, rx[0], rx[1], rx[2], rx[3], ok ? "ok" : "ERRO");
    pausa();
    return ok;
}

int main(void)
{
    int ok = 1;
    //GPIO_DIR = 0x3;

    printf("\n=== Teste SPI com ESP32-C3 ===\n");
    configura(49);                           // 1 MHz com clock de 100 MHz
    pausa();

    // 1) Um byte so: ESP deve mostrar "8 bits: 55"
    printf("[1] um byte (ESP esperado: 8 bits: 55)\n");
    spi_select(0);
    uint8_t r = spi_transfer(0x55);
    spi_deselect();
    printf("  enviou 55 | recebeu %02X | %s\n", r, r == 0xA0 ? "ok" : "ERRO");
    if (r != 0xA0) ok = 0;
    pausa();

    // 2) Quatro bytes no mesmo CS: "32 bits: 11 22 33 44"
    printf("[2] 4 bytes no CS0 (ESP esperado: 32 bits: 11 22 33 44)\n");
    if (!rajada(0)) ok = 0;

    // 3) Mesmo teste no CS1: o ESP NAO deve imprimir nada.
    //    Aqui o mestre recebe lixo (ninguem dirige o MISO), entao nao conta.
    printf("[3] 4 bytes no CS1 (ESP esperado: nada; recebido aqui e ignorado)\n");
    rajada(1);

    // 4) Varias velocidades: cada uma deve dar "32 bits: 11 22 33 44"
    printf("[4] varredura de velocidade (ESP esperado: 5x 32 bits)\n");
    uint32_t divs[] = { 99, 49, 24, 9, 4 };
    for (uint32_t i = 0; i < 5; i++) {
        configura(divs[i]);
        if (!rajada(0)) ok = 0;
    }

    printf("=== Resultado: %s ===\n", ok ? "PASSOU" : "FALHOU");
    //GPIO_SET = ok ? 0x1 : 0x2;
    while (1) ;
}