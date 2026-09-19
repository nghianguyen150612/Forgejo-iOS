#include "../probe.h"

int main(void) {
	install_probe_signal_handlers();
	printf("BEFORE=ISB\n");
	fflush(stdout);
	__asm__ volatile("isb sy" ::: "memory");
	printf("AFTER=ISB\n");
	return 0;
}
