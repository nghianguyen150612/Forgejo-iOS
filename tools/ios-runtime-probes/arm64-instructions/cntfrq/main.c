#include "../probe.h"

int main(void) {
	uint64_t value = 0;
	install_probe_signal_handlers();
	printf("BEFORE=CNTFRQ_EL0\n");
	fflush(stdout);
	__asm__ volatile("mrs %0, CNTFRQ_EL0" : "=r"(value));
	printf("AFTER=CNTFRQ_EL0 VALUE=%llu\n", (unsigned long long)value);
	return 0;
}
