private import _TestingInternals

package struct UUID: Sendable, BitwiseCopyable {
  /// The type of an underlying UUID value.
  ///
  /// In the future, this type will be replaced with `InlineArray`.
  private typealias _Bytes = (
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8
  )

  /// Storage for the underlying value.
  private var _bytes: _Bytes

  /// Initialize an instance of this type containing the UUID in the given
  /// buffer.
  ///
  /// - Parameters:
  ///   - bytes: A buffer pointer to a UUID. The size of this buffer must
  ///     exactly equal the size of a UUID.
  package init(_ bytes: UnsafeRawBufferPointer) {
    precondition(MemoryLayout<_Bytes>.size == bytes.count, "Tried to initialize an instance of UUID from a memory buffer containing \(bytes.count) bytes (expected \(MemoryLayout<_Bytes>.size))")
    _bytes = bytes.loadUnaligned(as: _Bytes.self)
  }

  /// Create a randomly generated UUID.
  package init() {
#if SWT_TARGET_OS_APPLE
      // We deploy to Apple platforms that do not have UInt128, so fake it with
      // two UInt64s. (This is a bit less efficient than making a single call.)
      var randomNumber = (UInt64.random(in: 0 ... .max), UInt64.random(in: 0 ... .max))
#else
      var randomNumber = UInt128.random(in: 0 ... .max)
#endif
    assert(MemoryLayout.size(ofValue: randomNumber) == MemoryLayout<_Bytes>.size, "Unexpected size of UUID (expected \(MemoryLayout.size(ofValue: randomNumber)), had \(MemoryLayout<_Bytes>.size))")

    _bytes = withUnsafeMutableBytes(of: &randomNumber) { buffer in
      // Set the appropriate bits in a UUID that indicate it's a version 4
      // (random) identifier.
      buffer[6] = (buffer[6] & 0x0F) | 0x40
      buffer[8] = (buffer[8] & 0x3F) | 0x80

      return buffer.loadUnaligned(as: _Bytes.self)
    }
  }

  package init?(uuidString: String) {
    var hexDigits: [Character] = uuidString.filter(\.isHexDigit)
    var bytes = [UInt8]()
    bytes.reserveCapacity(MemoryLayout<_Bytes>.size)
    while hexDigits.count >= 2 {
      defer {
        hexDigits.removeFirst(2)
      }
      let hexByte = hexDigits[0 ..< 2]
      guard let byte = UInt8(String(hexByte), radix: 16) else {
        return nil
      }
      bytes.append(byte)
    }
    guard bytes.count == MemoryLayout<_Bytes>.size else {
      return nil
    }
    self = bytes.withUnsafeBytes { bytes in
      Self(bytes)
    }
  }

  package var uuidString: String {
    withUnsafeBytes { bytes in
      Self._byteRangesForDescription.lazy
        .map { range in
          bytes[range].lazy.map { byte in
            if byte < 0x10 {
              "0\(String(byte, radix: 16))"
            } else {
              String(byte, radix: 16)
            }
          }.joined()
        }.joined(separator: "-")
    }
  }

  /// Invoke a function and pass it a buffer containing the bytes of this UUID.
  ///
  /// - Parameters:
  ///   - body: A function to call. The bytes of this instance are passed to it.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  package func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    try Swift.withUnsafeBytes(of: _bytes, body)
  }
}

// MARK: - Equatable, Hashable

extension UUID: Equatable, Hashable {
  package static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.withUnsafeBytes { lhs in
      rhs.withUnsafeBytes { rhs in
        lhs.elementsEqual(rhs)
      }
    }
  }

  package func hash(into hasher: inout Hasher) {
    withUnsafeBytes { bytes in
      hasher.combine(bytes: bytes)
    }
  }
}

// MARK: - CustomStringConvertible

extension UUID: CustomStringConvertible {
  /// The ranges of bytes from a UUID when converted to a string of the form
  /// `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"`.
  private static let _byteRangesForDescription = [0 ... 3, 4 ... 5, 6 ... 7, 8 ... 9, 10 ... 15]

  package var description: String {
    uuidString
  }
}

// MARK: - Codable

extension UUID: Codable {
  package init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let uuidString = try container.decode(String.self)
    guard let uuid = UUID(uuidString: uuidString) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Attempted to decode UUID from invalid UUID string."
        )
      )
    }
    self = uuid
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(uuidString)
  }
}
