//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A container type representing a time value that is suitable for storage,
/// conversion, encoding, and decoding.
///
/// This type models time values as durations. When representing a timestamp, an
/// instance of this type represents that timestamp as an offset from an epoch
/// such as the January 1, 1970 POSIX epoch or the system's boot time; which
/// epoch depends on the calling code.
///
/// This type is not part of the public interface of the testing library. Time
/// values exposed to clients of the testing library should generally be
/// represented as instances of ``Test/Clock/Instant`` or a type from the Swift
/// standard library like ``Duration``.
struct TimeValue: Sendable, RawRepresentable {
  var rawValue: Duration

  init(rawValue: Duration) {
    self.rawValue = rawValue
  }

  /// The amount of time represented by this instance as a tuple.
  var components: (seconds: Int64, attoseconds: Int64) {
    rawValue.components
  }

  init(_ components: (seconds: Int64, attoseconds: Int64)) {
    rawValue = Duration(secondsComponent: components.seconds, attosecondsComponent: components.attoseconds)
  }

  init(_ instant: SuspendingClock.Instant) {
    self.init(rawValue: SuspendingClock().systemEpoch.duration(to: instant))
  }
}

// MARK: - Equatable, Hashable, Comparable

extension TimeValue: Equatable, Hashable, Comparable {
  static func <(lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Codable

extension TimeValue: Codable {
  /// A structure representing an instance of ``TimeValue`` whose `Codable`
  /// conformance is compatible with Xcode 16.
  private struct _Xcode16EncodedForm: Codable {
    var seconds: Int64
    var attoseconds: Int64
  }

  func encode(to encoder: any Encoder) throws {
    let encodedForm = _Xcode16EncodedForm(seconds: components.seconds, attoseconds: components.attoseconds)
    var container = encoder.singleValueContainer()
    try container.encode(encodedForm)
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let encodedForm = try container.decode(_Xcode16EncodedForm.self)
    self.init(rawValue: Duration(secondsComponent: encodedForm.seconds, attosecondsComponent: encodedForm.attoseconds))
  }
}
#endif

// MARK: - CustomStringConvertible

extension TimeValue: CustomStringConvertible {
  var description: String {
    let (secondsFromAttoseconds, attosecondsRemaining) = components.attoseconds.quotientAndRemainder(dividingBy: 1_000_000_000_000_000_000)
    let seconds = components.seconds + secondsFromAttoseconds
    var milliseconds = attosecondsRemaining / 1_000_000_000_000_000
    if seconds == 0 && milliseconds == 0 && attosecondsRemaining > 0 {
      milliseconds = 1
    }

    return withUnsafeTemporaryAllocation(of: CChar.self, capacity: 512) { buffer in
      withVaList([CLongLong(seconds), CInt(milliseconds)]) { args in
        _ = vsnprintf(buffer.baseAddress!, buffer.count, "%lld.%03d seconds", args)
      }
      return String(cString: buffer.baseAddress!)
    }
  }
}
