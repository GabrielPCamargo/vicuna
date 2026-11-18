#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include "uart.h"


int main() {
    // Desabilita o buffer do stdout para garantir que os prints saiam imediatamente via UART
    setvbuf(stdout, NULL, _IONBF, 0);
    
    uart_printf("\n================================\n");
    uart_printf("=== VICUNA STDLIB STRESS TEST ==\n");
    uart_printf("================================\n\n");

    /* --- TESTE 1: STDLIB (Alocação de Memória e Strings) --- */
    printf("[1] Testando malloc(), strcpy() e snprintf()...\n");
    
    // Aloca 64 bytes no Heap (aciona o seu _sbrk)
    char *texto_dinamico = (char *)malloc(64 * sizeof(char));
    
    if (texto_dinamico == NULL) {
        printf("ERRO: malloc() falhou. Verifique _sbrk e o limite do Heap.\n");
    } else {
        // Manipulação de blocos de memória e cópia de strings
        memset(texto_dinamico, 0, 64);
        strcpy(texto_dinamico, "Alocacao no Heap funcionou! Valor = ");
        
        // Formatação de inteiros complexa
        int valor_teste = 2026;
        char buffer_int[16];
        snprintf(buffer_int, 16, "%d", valor_teste);
        strcat(texto_dinamico, buffer_int);
        
        printf("    -> SUCESSO: %s\n", texto_dinamico);
        
        // Libera a memória
        free(texto_dinamico);
    }
    printf("\n");

    /* --- TESTE 2: MATH.H (Cálculos Escalares) --- */
    printf("[2] Testando a biblioteca matematica ...\n");
    
    // Teste com double (soft-float, será pesado no .text)
    double angulo_rad = 3.14159265 / 4.0; // 45 graus
    double seno = sin(angulo_rad);
    double raiz = sqrt(144.0);
    
    // Nota: O nano.specs desabilita o %f no printf por padrão para economizar espaço.
    // Para imprimir floats, extraímos a parte inteira e a fracionária.
    int seno_int = (int)seno;
    int seno_frac = (int)((seno - seno_int) * 10000); 
    
    printf("    -> SUCESSO: sqrt(144) = %d\n", (int)raiz);
    printf("    -> SUCESSO: sin(45 deg) = %d.%04d\n", seno_int, seno_frac);
    printf("\n");


    /* --- TESTE 3: MATRIZES (Preparação para OBPMark) --- */
    printf("[3] Testando memset() pesado em matrizes na BSS...\n");
    
    // Aloca uma matriz de 1024 bytes na Stack
    uint32_t matriz[256];
    
    // Preenche com um valor e testa
    memset(matriz, 0xAA, sizeof(matriz));
    
    if (matriz[0] == 0xAAAAAAAA && matriz[255] == 0xAAAAAAAA) {
        printf("    -> SUCESSO: Memoria de matriz integra.\n");
    } else {
        printf("    -> ERRO: Corrupcao de memoria na Stack.\n");
    }

    uart_printf("\n=== TESTE CONCLUIDO COM SUCESSO ===\n");
    
    asm volatile("csrci mstatus, 8");

    while(1) {
        // Halt
        for(volatile int j = 0; j < 500000; j++); 
    }
    
    return 0;
}
