//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing types with a custom reflection when presented as part
/// of a test's output.
///
/// ## See Also
///
/// - ``Swift/Mirror/init(reflectingForTest:)``
@_spi(Experimental)
public protocol CustomTestReflectable {
  /// The custom mirror for this instance.
  ///
  /// Do not use this property directly. To get the test reflection of a value,
  /// use ``Swift/Mirror/init(reflectingForTest:)``.
  var customTestMirror: Mirror { get }
}

@_spi(Experimental)
extension Mirror {
  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - subject: The value to reflect.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestReflectable``
  public init(reflectingForTest subject: some CustomTestReflectable) {
    self = subject.customTestMirror
  }

  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - subject: The value to reflect.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestReflectable``
  public init(reflectingForTest subject: some Any) {
    if let subject = subject as? any CustomTestReflectable {
      self.init(reflectingForTest: subject)
    } else {
      self.init(reflecting: subject)
    }
  }
}
