// Teste de loopback SPI: ligue o pino MOSI direto no pino MISO.
// SCK e CS podem ficar desconectados.

#include <stdio.h>
#include <stdint.h>

// ---------------------------------------------------------------------------
// Driver minimo do spi_periph. Ajuste SPI_BASE ao seu mapa de enderecos.
// ---------------------------------------------------------------------------

#define SPI_BASE    0xFF003000u
#define SPI_CTRL    (*(volatile uint32_t *)(SPI_BASE + 0x00))
#define SPI_CLKDIV  (*(volatile uint32_t *)(SPI_BASE + 0x04))
#define SPI_CS      (*(volatile uint32_t *)(SPI_BASE + 0x08))
#define SPI_DATA    (*(volatile uint32_t *)(SPI_BASE + 0x0C))
#define SPI_STATUS  (*(volatile uint32_t *)(SPI_BASE + 0x10))

#define SPI_CS_NONE 0xFFu

// mode: 0..3 (bit 1 = CPOL, bit 0 = CPHA)
// f_sclk = f_clk / (2 * (clkdiv + 1))
static inline void spi_init(uint32_t mode, uint32_t clkdiv) {
    SPI_CS     = SPI_CS_NONE;
    SPI_CLKDIV = clkdiv;
    SPI_CTRL   = ((mode & 3u) << 1) | 1u;
}

static inline void spi_select(uint32_t n) { SPI_CS = SPI_CS_NONE & ~(1u << n); }
static inline void spi_deselect(void)     { SPI_CS = SPI_CS_NONE; }

static inline uint8_t spi_transfer(uint8_t b) {
    SPI_DATA = b;
    // Se os bytes recebidos vierem "atrasados" (igual ao byte anterior),
    // o busy esta subindo depois desta leitura. Nesse caso, descomente:
    // while (!(SPI_STATUS & 1u)) ;   // espera a transferencia comecar
    while (SPI_STATUS & 1u) ;         // espera a transferencia terminar
    return (uint8_t)SPI_DATA;
}

// ---------------------------------------------------------------------------
// Teste de loopback
// ---------------------------------------------------------------------------

#define CLKDIV 12   // clk de 25 MHz -> SCK de ~962 kHz

int main(void) {
    const uint8_t pat[] = {0x00, 0xFF, 0xA5, 0x5A, 0x01, 0x80, 0x3C, 0xC3};
    int total_erros = 0;

    printf("Teste de loopback SPI (MOSI -> MISO)\n\n");

    for (uint32_t mode = 0; mode < 4; mode++) {
        int erros = 0;

        spi_init(mode, CLKDIV);
        spi_select(0);   // inofensivo; cobre o caso de o HDL exigir CS ativo

        printf("Modo %lu:\n", (unsigned long)mode);
        for (unsigned i = 0; i < sizeof pat; i++) {
            uint8_t r = spi_transfer(pat[i]);
            printf("  enviado 0x%02X  recebido 0x%02X  %s\n",
                   pat[i], r, r == pat[i] ? "ok" : "ERRO");
            if (r != pat[i]) erros++;
        }

        spi_deselect();
        printf("  %s (%d erros)\n\n", erros ? "FALHOU" : "PASSOU", erros);
        total_erros += erros;
    }

    printf("Resultado final: %s\n", total_erros ? "FALHOU" : "SPI OK");

    while (1) ;
}