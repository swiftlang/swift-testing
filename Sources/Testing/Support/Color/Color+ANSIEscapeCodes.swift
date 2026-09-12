//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// The ANSI escape code prefix.
private let _ansiEscapeCodePrefix = "\u{001B}["

/// The ANSI escape code to reset text output to default settings.
let resetANSIEscapeCode = "\(_ansiEscapeCodePrefix)0m"

extension Color {
  /// Get an ANSI escape code that sets the foreground text color to this color.
  ///
  /// - Parameters:
  ///   - bitDepth: The maximum supported color bit depth.
  ///
  /// - Returns: The corresponding ANSI escape code, or `nil` if the bit depth
  ///   is too low to support ANSI escape codes.
  func ansiEscapeCode(withBitDepth bitDepth: Int8) -> String? {
    switch bitDepth {
    case 24...:
      return "\(_ansiEscapeCodePrefix)38;2;\(redComponent);\(greenComponent);\(blueComponent)m"
    case 8...:
      // The formula for converting an RGB value to a 256-color ANSI color
      // code can be found at https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
      let r = (Int(redComponent) * 5) / Int(UInt8.max)
      let g = (Int(greenComponent) * 5) / Int(UInt8.max)
      let b = (Int(blueComponent) * 5) / Int(UInt8.max)
      let index = 16 + 36 * r + 6 * g + b
      return "\(_ansiEscapeCodePrefix)38;5;\(index)m"
    case 4...:
      return closest16ColorEscapeCode()
    default:
      return nil
    }
  }

  /// Get the ANSI escape code that sets the foreground text color to whichever
  /// 16-color value is closest to this instance.
  ///
  /// - Returns: The corresponding ANSI escape code.
  ///
  /// An idealized color space is assumed.
  func closest16ColorEscapeCode() -> String {
    "\(_ansiEscapeCodePrefix)\(closest16ColorEscapeCodeValue())m"
  }

  /// Get the ANSI escape code that sets the foreground text color to whichever
  /// 16-color value is closest to this instance.
  ///
  /// - Returns: The integer value of the corresponding ANSI escape code.
  ///
  /// An idealized color space is assumed.
  func closest16ColorEscapeCodeValue() -> Int {
    if self == .orange {
      // Special-case orange to dark yellow as it doesn't have a good mapping in
      // most low-color terminals. NOTE: Historically, the IBM PC's CGA adapter
      // and monitor had dedicated circuitry to display dark yellow as a shade
      // of orange-brown, but modern terminal applications rarely emulate it.
      return 33
    } else if self == .purple {
      // Special-case purple as well since it is declared as true purple rather
      // than magenta.
      return 95
    }

    let (hue, saturation, value) = hsvComponents
    if saturation <= 0.25 {
      // Some shade of gray (or a very pale color.)
      switch Int(value * 3.0) {
      case 0: // black
        return 30
      case 1: // dark gray
        return 90
      case 2: // light gray
        return 37
      default: // 3, white
        return 97
      }
    } else if value < 0.1 {
      // Saturated, but very dark, so map to black. HSV is conic, so there is no
      // equivalent white mapping for high values.
      return 30
    } else {
      // There is some saturation, so figure out the closest available color.
      let brightAddend = if value > 0.5 {
        60
      } else {
        0
      }
      let hueAddend = switch Int(hue * 6.0) {
      case 0, 6: // red
        31
      case 1: // yellow
        33
      case 2: // green
        32
      case 3: // cyan
        36
      case 4: // blue
        34
      default: // 5, magenta
        35
      }
      return hueAddend + brightAddend
    }
  }
}

