// stdout and stderr, drawn on screen by GBAPlatform's console.
//
// picolibc writes through whatever FILE these point to, so these have to be
// C globals with exactly these names; Swift can't define them.

#include "CGBAPlatform.h"

static FILE console = FDEV_SETUP_STREAM(gba_console_put, NULL, NULL, _FDEV_SETUP_WRITE);

FILE *const stdout = &console;
FILE *const stderr = &console;

// These must stay out of line: callers rely on the calls as compiler barriers.

uint16_t gba_disable_interrupts(void) {
  uint16_t ime = REG_IME;
  REG_IME = 0;
  return ime;
}

void gba_restore_interrupts(uint16_t ime) {
  REG_IME = ime;
}

void gba_set_errno(int value) {
  errno = value;
}
