#include "../probe.h"

int main(void) {
	uint64_t value = 0;
	install_probe_signal_handlers();
	printf("BEFORE=CNTVCT_EL0\n");
	fflush(stdout);
	__asm__ volatile("mrs %0, CNTVCT_EL0" : "=r"(value));
	printf("AFTER=CNTVCT_EL0 VALUE=%llu\n", (unsigned long long)value);
	return 0;
}
