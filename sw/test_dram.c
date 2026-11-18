/*
 * test_dram.c - Teste da DRAM do PS acessada pelo Vicuna (AXI -> S_AXI_HP0)
 *
 * Testes, do mais simples ao mais pesado:
 *   [1] Uma palavra (se travar aqui, o caminho AXI nao responde)
 *   [2] Barramento de dados (walking ones em 32 bits)
 *   [3] Barramento de enderecos (aliasing em offsets potencia de 2)
 *   [4] Escritas de byte e meia palavra (byte enables / WSTRB)
 *   [5] Array grande: escreve um padrao que depende do endereco e confere
 *   [6] Load/store vetorial (vle32/vse32) DRAM -> DRAM
 *
 * Compilar (na pasta do sw, com o Makefile atual):
 *   make PROG=test_dram OBJ=test_dram.o
 */

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

/* Precisa bater com DDR_V_BASE e DDR_SIZE do gen_demo_ps.tcl */
#define DDR_BASE        0x20000000u
#define DDR_SIZE        0x20000000u     /* 256 MB */

/* Tamanho do teste do array grande. Comece pequeno; 256 MB inteiros
 * podem levar varios minutos a 25 MHz sem cache. */
#define TESTE_BYTES     (4u * 1024u * 1024u)   /* 4 MB */

/* Comente para pular o teste vetorial */
#define TESTE_VETORIAL

#define MAX_ERROS_IMPRESSOS 8

static volatile uint32_t *const ddr32 = (volatile uint32_t *)DDR_BASE;

/* Padrao que depende do indice: detecta dados errados E enderecos trocados */
static inline uint32_t padrao(uint32_t i, uint32_t semente)
{
    uint32_t x = (i + semente) * 0x9E3779B1u;
    return x ^ (x >> 15) ^ i;
}

static unsigned erros_total = 0;

static void reporta_erro(const char *teste, uintptr_t addr, uint32_t esperado, uint32_t lido)
{
    if (erros_total < MAX_ERROS_IMPRESSOS) {
        printf("    ERRO %s @0x%08x: esperado 0x%08x, lido 0x%08x (xor 0x%08x)\n",
               teste, (unsigned)addr, (unsigned)esperado, (unsigned)lido,
               (unsigned)(esperado ^ lido));
    }
    erros_total++;
}

static unsigned resultado(unsigned erros_antes)
{
    unsigned n = erros_total - erros_antes;
    if (n == 0) printf("    -> OK\n\n");
    else        printf("    -> FALHOU: %u erro(s)\n\n", n);
    return n;
}

/* [1] Uma palavra */
static void teste_palavra(void)
{
    unsigned e0 = erros_total;
    
    
    printf("[0] Lendo 0x%08x sem escrever antes...\n", (unsigned)DDR_BASE);
uint32_t v0 = ddr32[0];
printf("    leitura ok: 0x%08x\n", (unsigned)v0);
    printf("[1] Escrevendo uma palavra em 0x%08x...\n", (unsigned)DDR_BASE);
    ddr32[0] = 0xDEADBEEFu;
    printf("    escrita ok, lendo...\n");
    uint32_t v = ddr32[0];
    if (v != 0xDEADBEEFu) reporta_erro("palavra", DDR_BASE, 0xDEADBEEFu, v);
    resultado(e0);
}

/* [2] Walking ones: cada bit de dados sozinho */
static void teste_dados(void)
{
    unsigned e0 = erros_total;
    printf("[2] Barramento de dados (walking ones)...\n");
    for (int b = 0; b < 32; b++) {
        uint32_t p = 1u << b;
        ddr32[1] = p;
        ddr32[2] = ~p;          /* outra escrita no meio, para nao ler "resto" do barramento */
        uint32_t v = ddr32[1];
        if (v != p) reporta_erro("dados", DDR_BASE + 4, p, v);
        v = ddr32[2];
        if (v != ~p) reporta_erro("dados", DDR_BASE + 8, ~p, v);
    }
    resultado(e0);
}

/* [3] Enderecos: valor unico em cada offset potencia de 2 */
static void teste_enderecos(void)
{
    unsigned e0 = erros_total;
    printf("[3] Barramento de enderecos (offsets potencia de 2 ate %u MB)...\n",
           (unsigned)(DDR_SIZE >> 20));

    ddr32[0] = 0xA5A5A5A5u;
    for (uint32_t off = 4; off < DDR_SIZE; off <<= 1)
        ddr32[off / 4] = 0xA5A5A5A5u ^ off;

    uint32_t v = ddr32[0];
    if (v != 0xA5A5A5A5u) reporta_erro("enderecos", DDR_BASE, 0xA5A5A5A5u, v);
    for (uint32_t off = 4; off < DDR_SIZE; off <<= 1) {
        v = ddr32[off / 4];
        if (v != (0xA5A5A5A5u ^ off))
            reporta_erro("enderecos", DDR_BASE + off, 0xA5A5A5A5u ^ off, v);
    }
    resultado(e0);
}

/* [4] Byte e meia palavra: testa o WSTRB e o alinhamento no adaptador */
static void teste_bytes(void)
{
    unsigned e0 = erros_total;
    volatile uint8_t  *p8  = (volatile uint8_t  *)(DDR_BASE + 0x100);
    volatile uint16_t *p16 = (volatile uint16_t *)(DDR_BASE + 0x100);
    volatile uint32_t *p32 = (volatile uint32_t *)(DDR_BASE + 0x100);

    printf("[4] Escritas de byte e meia palavra...\n");

    /* Bytes individuais */
    p32[0] = 0x00000000u;
    p8[0] = 0x11; p8[1] = 0x22; p8[2] = 0x33; p8[3] = 0x44;
    uint32_t v = p32[0];
    if (v != 0x44332211u) reporta_erro("byte-escrita", (uintptr_t)p32, 0x44332211u, v);

    /* Um byte no meio nao pode alterar os vizinhos */
    p32[1] = 0xFFFFFFFFu;
    p8[4 + 2] = 0x00;
    v = p32[1];
    if (v != 0xFF00FFFFu) reporta_erro("byte-vizinho", (uintptr_t)&p32[1], 0xFF00FFFFu, v);

    /* Meias palavras */
    p32[2] = 0x00000000u;
    p16[4] = 0xBEEF; p16[5] = 0xDEAD;
    v = p32[2];
    if (v != 0xDEADBEEFu) reporta_erro("half-escrita", (uintptr_t)&p32[2], 0xDEADBEEFu, v);

    /* Leituras de byte e meia palavra */
    p32[3] = 0x89ABCDEFu;
    uint8_t  b2 = p8[12 + 2];
    uint16_t h1 = p16[7];
    if (b2 != 0xAB)   reporta_erro("byte-leitura", (uintptr_t)&p8[14], 0xAB, b2);
    if (h1 != 0x89AB) reporta_erro("half-leitura", (uintptr_t)&p16[7], 0x89AB, h1);

    resultado(e0);
}

/* [5] Array grande */
static void teste_array(uint32_t semente)
{
    unsigned e0 = erros_total;
    uint32_t n = TESTE_BYTES / 4;

    printf("[5] Array grande: %u KB a partir de 0x%08x (semente 0x%08x)\n",
           (unsigned)(TESTE_BYTES >> 10), (unsigned)DDR_BASE, (unsigned)semente);

    printf("    escrevendo");
    for (uint32_t i = 0; i < n; i++) {
        ddr32[i] = padrao(i, semente);
        if ((i & 0x3FFFF) == 0x3FFFF) printf(".");    /* um ponto a cada 1 MB */
    }
    printf("\n    conferindo");
    for (uint32_t i = 0; i < n; i++) {
        uint32_t esp = padrao(i, semente);
        uint32_t v = ddr32[i];
        if (v != esp) reporta_erro("array", DDR_BASE + 4 * i, esp, v);
        if ((i & 0x3FFFF) == 0x3FFFF) printf(".");
    }
    printf("\n");
    resultado(e0);
}

#ifdef TESTE_VETORIAL
/* [6] Copia DRAM -> DRAM com vle32/vse32 e confere com acesso escalar */
static void teste_vetorial(void)
{
    unsigned e0 = erros_total;
    const uint32_t n = 4096;                         /* 16 KB */
    uint32_t *src = (uint32_t *)(DDR_BASE + 0x00100000u);
    uint32_t *dst = (uint32_t *)(DDR_BASE + 0x00200000u);
    volatile uint32_t *vsrc = src, *vdst = dst;

    printf("[6] Load/store vetorial: copiando %u palavras DRAM -> DRAM...\n", (unsigned)n);

    for (uint32_t i = 0; i < n; i++) {
        vsrc[i] = padrao(i, 0x1234u);
        vdst[i] = 0;
    }

    uint32_t restante = n;
    uint32_t *s = src, *d = dst;
    while (restante > 0) {
        uint32_t vl;
        asm volatile("vsetvli %0, %1, e32, m4, ta, ma" : "=r"(vl) : "r"(restante));
        asm volatile("vle32.v v8, (%0)" : : "r"(s) : "memory");
        asm volatile("vse32.v v8, (%0)" : : "r"(d) : "memory");
        s += vl; d += vl; restante -= vl;
    }

    for (uint32_t i = 0; i < n; i++) {
        uint32_t esp = padrao(i, 0x1234u);
        uint32_t v = vdst[i];
        if (v != esp) reporta_erro("vetorial", (uintptr_t)&vdst[i], esp, v);
    }
    resultado(e0);
}
#endif

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);

    printf("\n================================\n");
    printf("===   VICUNA  DRAM  TEST     ===\n");
    printf("================================\n");
    printf("DDR: 0x%08x - 0x%08x\n\n",
           (unsigned)DDR_BASE, (unsigned)(DDR_BASE + DDR_SIZE - 1));
           

    teste_palavra();
    teste_dados();
    teste_enderecos();
    teste_bytes();
    teste_array(0x00000000u);
    teste_array(0xCAFEF00Du);    /* segunda passada com outro padrao */
#ifdef TESTE_VETORIAL
    teste_vetorial();
#endif

    if (erros_total == 0)
        printf("=== DRAM OK: todos os testes passaram ===\n");
    else
        printf("=== DRAM COM PROBLEMAS: %u erro(s) no total ===\n", erros_total);

    asm volatile("csrci mstatus, 8");
    while (1) {
        for (volatile int j = 0; j < 500000; j++);
    }
    return 0;
}
