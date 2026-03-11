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

  init(_ components: (seconds: Int64, attoseconds: Int64)) {
    (seconds, attoseconds) = components
  }
#else
  var rawValue: Duration
#endif
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Codable

extension TimeValue: Codable {}
#endif

// MARK: - CustomStringConvertible

extension TimeValue: CustomStringConvertible {
  var description: String {
    let seconds = CLongLong(rawValue.components.seconds)
    var milliseconds = CInt((rawValue - .seconds(rawValue.components.seconds)) / .milliseconds(1))
    if seconds == 0 && milliseconds == 0 && rawValue > .zero {
      milliseconds = 1
    }

    return withUnsafeTemporaryAllocation(of: CChar.self, capacity: 512) { buffer in
      withVaList([seconds, milliseconds]) { args in
        _ = vsnprintf(buffer.baseAddress!, buffer.count, "%lld.%03d seconds", args)
      }
      return String(cString: buffer.baseAddress!)
    }
  }
}
