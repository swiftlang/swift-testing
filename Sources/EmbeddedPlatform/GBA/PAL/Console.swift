#if hasFeature(Embedded)

import _Volatile
import EmbeddedPlatformGBACShims_Testing
import tonc

/// The height of background 0's tile map, in pixels.
private let mapHeight = 256

private var displayControl: VolatileMappedRegister<UInt16> {
  .init(unsafeBitPattern: 0x0400_0000)
}
private var background0VerticalOffset: VolatileMappedRegister<UInt16> {
  .init(unsafeBitPattern: 0x0400_0012)
}

private nonisolated(unsafe) var isStarted = false
private nonisolated(unsafe) var lineCount = 1

private func startConsole() {
  if isStarted {
    return
  }
  isStarted = true

  // Mode 0, text on background 0 (character block 0, screen block 31).
  displayControl.store(UInt16(DCNT_MODE0 | DCNT_BG0))
  gba_tte_init_se(0, 31 << 8)
  tte_set_margins(0, 0, Int32(SCREEN_WIDTH), Int32(mapHeight))
}

/// Moves the cursor to the start of the next line and clears it.
private func startLine(_ context: UnsafeMutablePointer<TTC>) {
  lineCount += 1
  let lineHeight = Int(context.pointee.font.pointee.charH)

  // Wrap the cursor within the map, and clear whatever it held from
  // mapHeight / lineHeight lines ago.
  context.pointee.cursorX = Int16(context.pointee.marginLeft)
  context.pointee.cursorY = (context.pointee.cursorY + Int16(lineHeight)) % Int16(mapHeight)
  tte_erase_line()

  // Scroll so the new line is at the bottom of the screen.
  let bottom = lineCount * lineHeight
  if bottom > Int(SCREEN_HEIGHT) {
    background0VerticalOffset.store(UInt16((bottom - Int(SCREEN_HEIGHT)) % mapHeight))
  }
}

// UTF-8 decoding intermediate scalar values.
private nonisolated(unsafe) var scalar: UInt32 = 0
private nonisolated(unsafe) var scalarBytesRemaining = 0

/// Checks for known multi-byte UTF-8 scalars and maps them to appropriate
/// ASCII substitute characters.
private func asciiSubstitute(_ byte: UInt8) -> UInt8? {
  if byte < 0x80 {
    scalarBytesRemaining = 0
    return byte
  }
  if byte >= 0xC0 {
    // Start of a multi-byte sequence.
    scalarBytesRemaining = byte >= 0xF0 ? 3 : byte >= 0xE0 ? 2 : 1
    scalar = UInt32(byte & (0x3F >> scalarBytesRemaining))
    return nil
  }
  if scalarBytesRemaining == 0 {
    // Stray continuation byte.
    return UInt8(ascii: "?")
  }
  scalar = scalar << 6 | UInt32(byte & 0x3F)
  scalarBytesRemaining -= 1
  if scalarBytesRemaining > 0 {
    return nil
  }

  switch scalar {
  case 0x2714: return UInt8(ascii: "+") // ✔ (passed)
  case 0x2718: return UInt8(ascii: "x") // ✘ (failed)
  case 0x25C7: return UInt8(ascii: "*") // ◇ (started)
  case 0x279C, 0x2192: return UInt8(ascii: ">") // ➜, → (skipped)
  case 0x2501: return UInt8(ascii: "-") // ━ (known issue)
  case 0x26A0: return UInt8(ascii: "!") // ⚠
  case 0x21B3: return UInt8(ascii: "|") // ↳ (details)
  case 0x00B1: return UInt8(ascii: "~") // ± (difference)
  case 0x2018, 0x2019: return UInt8(ascii: "'") // curly single quotes
  case 0x201C, 0x201D: return UInt8(ascii: "\"") // curly quotes
  case 0xFE0E, 0xFE0F: return nil // variation selectors
  default: return UInt8(ascii: "?")
  }
}

@implementation @c
func gba_console_put(_ c: CChar, _ file: UnsafeMutablePointer<FILE>!) -> CInt {
  startConsole()
  let character = UInt8(bitPattern: c)
  guard let substitute = asciiSubstitute(character) else {
    return CInt(character)
  }

  let context = tte_get_context()!
  if substitute == UInt8(ascii: "\n") {
    startLine(context)
    return CInt(character)
  }

  // Check if a character is not gonna fit and wrap it manually.
  let characterWidth = Int(context.pointee.font.pointee.charW)
  if Int(context.pointee.cursorX) + characterWidth > Int(context.pointee.marginRight) {
    startLine(context)
  }
  tte_putc(CInt(substitute))
  return CInt(character)
}

#endif
