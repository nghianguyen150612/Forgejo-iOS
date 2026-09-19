#ifndef IOS_ARM64_INSTRUCTION_PROBE_H
#define IOS_ARM64_INSTRUCTION_PROBE_H

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void probe_signal_handler(int signal_number) {
	printf("SIGNAL=%d\n", signal_number);
	fflush(stdout);
	_Exit(128 + signal_number);
}

static void install_probe_signal_handlers(void) {
	signal(SIGILL, probe_signal_handler);
	signal(SIGBUS, probe_signal_handler);
	signal(SIGSEGV, probe_signal_handler);
}

#endif
