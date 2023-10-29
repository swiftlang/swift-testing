//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import TestingInternals

/// A type describing the environment of the current process.
///
/// This type can be used to access the current process' environment variables.
///
/// This type is not part of the public interface of the testing library.
enum Environment {
#if SWT_NO_ENVIRONMENT_VARIABLES
  /// Storage for the simulated environment.
  ///
  /// The mechanism by which this dictionary is initially populated depends on
  /// platform-specific implementation details.
  @Locked
  private static var _environment = [String: String]()
#endif

  /// Get the environment variable with the specified name.
  ///
  /// - Parameters:
  ///   - name: The name of the environment variable.
  ///
  /// - Returns: The value of the specified environment variable, or `nil` if it
  ///   is not set for the current process.
  static func variable(named name: String) -> String? {
#if SWT_NO_ENVIRONMENT_VARIABLES
    _environment[name]
#elseif SWT_TARGET_OS_APPLE || os(Linux)
    getenv(name).flatMap { String(validatingUTF8: $0) }
#elseif os(Windows)
    name.withCString(encodedAs: UTF16.self) { name in
      func getVariable(maxCount: Int) -> String? {
        withUnsafeTemporaryAllocation(of: wchar_t.self, capacity: maxCount) { buffer in
          let count = GetEnvironmentVariableW(name, buffer.baseAddress!, DWORD(buffer.count))
          if count <= 0 {
            // Failed to get the environment variable. Presumably it is not set.
            return nil
          } else if count > buffer.count {
            // Try again with the larger count.
            return getVariable(maxCount: Int(count))
          }
          return String.decodeCString(buffer.baseAddress!, as: UTF16.self)?.result
        }
      }
      return getVariable(maxCount: 256)
    }
#else
#warning("Platform-specific implementation missing: environment variables unavailable")
    nil
#endif
  }

  /// Get the boolean value of the environment variable with the specified name.
  ///
  /// - Parameters:
  ///   - name: The name of the environment variable.
  ///
  /// - Returns: The value of the specified environment variable, interpreted as
  ///   a boolean value, or `nil` if it is not set for the current process.
  ///
  /// If a value is set for the specified environment variable, it is parsed as
  /// a boolean value:
  ///
  /// - String values that can be parsed as instances of `Int64` or `UInt64` are
  ///   interpreted as `false` if they are equal to `0`, and `true` otherwise;
  /// - String values beginning with the letters `"t"`, `"T"`, `"y"`, or `"Y"`
  ///   are interpreted as `true`; and
  /// - All other non-`nil` string values are interpreted as `false`.
  static func flag(named name: String) -> Bool? {
    variable(named: name).map {
      if let signedValue = Int64($0) {
        return signedValue != 0
      }
      if let unsignedValue = UInt64($0) {
        return unsignedValue != 0
      }

      let first = $0.first
      return first == "t" || first == "T" || first == "y" || first == "Y"
    }
  }

  /// Set the environment variable with the specified name.
  ///
  /// - Parameters:
  ///   - value: The new value for the specified environment variable. Pass
  ///     `nil` to remove the variable from the current process' environment.
  ///   - name: The name of the environment variable.
  ///
  /// - Returns: Whether or not the environment variable was successfully set.
  @discardableResult
  static func setVariable(_ value: String?, named name: String) -> Bool {
#if SWT_NO_ENVIRONMENT_VARIABLES
    $_environment.withLock { environment in
      environment[name] = value
    }
    return true
#elseif SWT_TARGET_OS_APPLE || os(Linux)
    if let value {
      return 0 == setenv(name, value, 1)
    }
    return 0 == unsetenv(name)
#elseif os(Windows)
    name.withCString(encodedAs: UTF16.self) { name in
      if let value {
        return value.withCString(encodedAs: UTF16.self) { value in
          SetEnvironmentVariableW(name, value)
        }
      }
      return SetEnvironmentVariableW(name, nil)
    }
#else
#warning("Platform-specific implementation missing: environment variables unavailable")
    false
#endif
  }
}
