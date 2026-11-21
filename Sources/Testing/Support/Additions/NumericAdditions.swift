//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Numeric where Self: CustomStringConvertible {
  /// Form an English noun phrase describing this number of values.
  ///
  /// - Parameters:
  ///   - noun: A singular noun describing the kind of values being counted,
  ///     such as `"issue"` or `"test"`.
  ///
  /// - Returns: An English-language string composed of `self` and `noun`, with
  ///   `noun` being pluralized if `self` does not equal `1`. For example,
  ///   `5.counting("duck")` produces `"5 ducks"`.
  func counting(_ noun: String) -> String {
    if self == 1 {
      return "1 \(noun)"
    }
    return "\(self) \(noun)s"
  }
}

// MARK: -

extension UInt8 {
  /// Whether or not this instance is an ASCII newline character (`\n` or `\r`).
  var isASCIINewline: Bool {
    self == UInt8(ascii: "\r") || self == .asciiNewlineCharacter
  }

  /// The canonical ASCII newline character, `"\n"`.
  @inline(always) static var asciiNewlineCharacter: Self {
    UInt8(ascii: "\n")
  }
}

// MARK: -

extension FixedWidthInteger where Self: ConvertibleToBytes {
  /// Store this value as a sequence of hexadecimal ASCII characters to the
  /// given address.
  ///
  /// - Parameters:
  ///   - destination: A pointer to memory large enough to hold the hexadecimal
  ///   	ASCII representation of this value, which is always twice the size of
  ///     this numeric value (2 bytes for an instance of `UInt8`, 4 bytes for an
  ///     instance of `UInt16`, etc.) This function does _not_ verify the size
  ///     of the memory at `destination`.
  ///
  /// For example, if `self` is an instance of `UInt8` and its value is 30
  /// (`0x1E`), this function stores `UInt8(ascii: "1")` and `UInt8(ascii: "e")`
  /// in `destination[0]` and `destination[1]`, respectively.
  ///
  /// This function always produces lowercase letters.
  func storeASCIIHexadecimalValue(to destination: UnsafeMutablePointer<UInt8>) {
    withUnsafeBytes(of: self.bigEndian) { bytes in
      func storeNybble(_ nybble: UInt8, to dest: UnsafeMutablePointer<UInt8>) {
        if nybble < 0xA {
          dest.initialize(to: UInt8(ascii: "0") + nybble - 0x0)
        } else {
          dest.initialize(to: UInt8(ascii: "a") + nybble - 0xA)
        }
      }
      for i in 0 ..< bytes.count {
        storeNybble((bytes[i] & 0xF0) >> 4, to: destination + (i * 2) + 0)
        storeNybble((bytes[i] & 0x0F) >> 0, to: destination + (i * 2) + 1)
      }
    }
  }
}
