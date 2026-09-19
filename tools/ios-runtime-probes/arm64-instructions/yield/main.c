#include "../probe.h"

int main(void) {
	install_probe_signal_handlers();
	printf("BEFORE=YIELD\n");
	fflush(stdout);
	__asm__ volatile("yield" ::: "memory");
	printf("AFTER=YIELD\n");
	return 0;
}
