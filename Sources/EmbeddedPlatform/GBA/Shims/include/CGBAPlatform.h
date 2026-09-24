#ifndef CGBA_PLATFORM_H
#define CGBA_PLATFORM_H

#include <errno.h>
#include <stdio.h>
#include <tonc.h>

/// Draws a character written to stdout or stderr on screen.
/// (see GBAPlatform/Console.swift for the implementation)
int gba_console_put(char c, FILE *file);

/// Sets `errno`
void gba_set_errno(int value);

/// Clears the interrupt master enable register (REG_IME), returning its old
/// value for `gba_restore_interrupts()`.
uint16_t gba_disable_interrupts(void);

/// Restores REG_IME to a value returned by `gba_disable_interrupts()`.
void gba_restore_interrupts(uint16_t ime);

/// Sets up TTE for tiled text on a background.
static inline void gba_tte_init_se(int bgnr, u16 bgcnt) {
  tte_init_se(bgnr, bgcnt, 0xF000, CLR_WHITE, 0, &sys8Font, NULL);
}

#endif
