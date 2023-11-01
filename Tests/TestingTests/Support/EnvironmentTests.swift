//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing
import TestingInternals
import Foundation

@Suite("Environment Tests")
struct EnvironmentTests {
  var name = "SWT_ENVIRONMENT_VARIABLE_\(UUID())"

  @Test("Read environment variable")
  func readEnvironmentVariable() throws {
    let value = "\(UInt64.random(in: 0 ... .max))"
    try #require(nil == Environment.variable(named: name))
    defer {
      Environment.setVariable(nil, named: name)
    }
    try #require(Environment.setVariable(value, named: name))
    #expect(Environment.variable(named: name) == value)
  }

  @Test("Read true environment flags",
    arguments: [
      "1", String(describing: UInt64.max), String(describing: Int64.min),
      String(describing: UInt64.random(in: 1 ... .max)), String(describing: Int64.random(in: .min ..< 0)),
      "YES", "yes", "yEs", "TRUE", "true", "tRuE",
    ]
  )
  func readTrueFlag(value: String) throws {
    try #require(nil == Environment.variable(named: name))
    defer {
      Environment.setVariable(nil, named: name)
    }
    try #require(Environment.setVariable(value, named: name))
    #expect(Environment.variable(named: name) == value)
    #expect(Environment.flag(named: name) == true)
  }

  @Test("Read false environment flags",
    arguments: [
      "0", "", " ", "\t",
      "NO", "no", "nO", "FALSE", "false", "fAlSe",
      "alphabetical", "ümlaut", "😀",
    ]
  )
  func readFalseFlag(value: String) throws {
    try #require(nil == Environment.variable(named: name))
    defer {
      Environment.setVariable(nil, named: name)
    }
    try #require(Environment.setVariable(value, named: name))
    #expect(Environment.variable(named: name) == value)
    #expect(Environment.flag(named: name) == false)
  }
}

// MARK: - Fixtures

extension Environment {
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
