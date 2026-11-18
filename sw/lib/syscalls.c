#include <sys/stat.h>
#include <stddef.h>
#include <stdint.h>
#include <errno.h>
#include <stddef.h>
#include "uart.h"

// O símbolo _end é injetado pelo linker script (marca o fim da seção .bss)
extern char _end;
static char *heap_ptr = &_end;

/* 
 * Stubs para resolver referências da Newlib (printf) 
 * a conversões de ponto flutuante omitidas pelo -nodefaultlibs
 */
double __trunctfdf2(long double a) {
    return (double)a;
}

// Opcional: declare a função de UART se quiser manter o aviso
//extern void uart_printf(const char* format, ...);



extern char _heap_start[], _heap_end[];

void *_sbrk(ptrdiff_t incr)
{
    static char *heap_ptr = _heap_start;
    char *prev = heap_ptr;

    if (heap_ptr + incr > _heap_end || heap_ptr + incr < _heap_start) {
        errno = ENOMEM;
        return (void *)-1;
    }
    heap_ptr += incr;
    return prev;
}

int _write(int file, const char *ptr, int len) {
    for (int i = 0; i < len; i++) {
        uart_putc(ptr[i]); // Use uart_putc, não uart_write
    }
    return len;
}

int _close(int file) { return -1; }

int _fstat(int file, struct stat *st) {
    if (file == 1 || file == 2) { // stdout ou stderr
        st->st_mode = S_IFCHR;
        return 0;
    }
    st->st_mode = S_IFREG;
    return 0;
}
int _isatty(int file) { return 1; }
int _lseek(int file, int ptr, int dir) { return 0; }
int _read(int file, char *ptr, int len) { return 0; }
void _exit(int status) { while (1); }
int _kill(int pid, int sig) { return -1; }
int _getpid(void) { return 1; }


#include "uart.h"
#include <stdint.h>

// Endereços dos registradores de controle e status (CSRs)
// O mcause guarda o código da exceção que fez a CPU travar.
// O mepc guarda o endereço (PC) exato da instrução que deu pau.

static inline uint32_t read_mcause(void) {
    uint32_t val;
    __asm__ volatile ("csrr %0, mcause" : "=r" (val));
    return val;
}

static inline uint32_t read_mepc(void) {
    uint32_t val;
    __asm__ volatile ("csrr %0, mepc" : "=r" (val));
    return val;
}

// Esta função será chamada pelo crt0.S quando a CPU bater de frente com o erro
void exception_handler(void) {
    uint32_t cause = read_mcause();
    uint32_t epc = read_mepc();

    uart_printf("\n\r!!! FATAL EXCEPTION !!!\n\r");
    uart_printf("mcause (Motivo)   : 0x%x\n\r", cause);
    uart_printf("mepc   (Endereco) : 0x%x\n\r", epc);

    // Entra num loop infinito para não tentar continuar
    while(1);
}
