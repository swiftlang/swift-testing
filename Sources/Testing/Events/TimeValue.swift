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
#if !SWT_NO_SNAPSHOT_TYPES
  private var seconds: Int64
  private var attoseconds: Int64

  var rawValue: Duration {
    get {
      Duration(secondsComponent: seconds, attosecondsComponent: attoseconds)
    }
    set {
      (seconds, attoseconds) = newValue.components
    }
  }

  init(rawValue: Duration) {
    (seconds, attoseconds) = rawValue.components
  }
#else
  var rawValue: Duration
#endif
}

extension TimeValue {
  init(_ components: (seconds: Int64, attoseconds: Int64)) {
    self.init(rawValue: Duration(secondsComponent: components.seconds, attosecondsComponent: components.attoseconds))
  }

  /// Construct an instance of this type from a floating-point value (where
  /// `1.0` is one whole second).
  ///
  /// - Parameters:
  ///   - seconds: The number of seconds, including fractional seconds, since
  ///     the time value's epoch.
  ///
  /// The precision and accuracy of this initializer are ultimately determined
  /// by the definition of `FloatLiteralType` used at compile time.
  init(_ seconds: FloatLiteralType) {
    let components = (
      seconds: Int64(seconds.rounded(.towardZero)),
      attoseconds: Int64(seconds.remainder(dividingBy: 1.0).magnitude * 1_000_000_000_000_000_000.0)
    )
    self.init(components)
  }

  /// This instance as a floating-point value (where `1.0` is one whole second).
  ///
  /// The precision and accuracy of this property are ultimately determined by
  /// the definition of `FloatLiteralType` used at compile time.
  var floatingPointValue: FloatLiteralType {
    let components = rawValue.components
    return FloatLiteralType(components.seconds) + (FloatLiteralType(components.attoseconds) / 1_000_000_000_000_000_000.0)
  }
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Codable

extension TimeValue: Codable {}
#endif

// MARK: - CustomStringConvertible

extension TimeValue: CustomStringConvertible {
  var description: String {
    let seconds = rawValue.components.seconds
    var milliseconds = rawValue.components.attoseconds / 1_000_000_000_000_000
    if seconds == 0 && milliseconds == 0 && rawValue > .zero {
      milliseconds = 1
    }

    let strSeconds = String(describing: seconds)
    var strMilliseconds = String(describing: milliseconds)
    if strMilliseconds.count < 3 {
      strMilliseconds = String(repeating: "0", count: 3 - strMilliseconds.count) + strMilliseconds
    }
    return "\(strSeconds).\(strMilliseconds) seconds"
  }
}
