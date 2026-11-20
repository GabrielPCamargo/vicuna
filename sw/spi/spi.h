// Driver minimo do spi_periph. Ajuste SPI_BASE ao seu mapa de enderecos.
#ifndef SPI_H
#define SPI_H

#include <stdint.h>

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
    while (SPI_STATUS & 1u) ;
    return (uint8_t)SPI_DATA;
}

// Exemplo: ler um registrador de um sensor (bit 7 = leitura, comum em
// sensores como BME280 e ADXL345; confira no datasheet do seu).
static inline uint8_t spi_read_reg(uint32_t cs, uint8_t reg) {
    spi_select(cs);
    spi_transfer(reg | 0x80u);
    uint8_t v = spi_transfer(0x00);
    spi_deselect();
    return v;
}

#endif