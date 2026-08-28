//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Event {
  /// A type describing metadata regarding a test run, the current environment,
  /// etc.
  ///
  /// Metadata is human-readable information such as the operating system
  /// version that can be used to help diagnose issues recorded during a test
  /// run.
  ///
  /// - Important: The properties of instances of this type are human-readable.
  ///   They are not guaranteed to remain stable over multiple releases of the
  ///   testing library. You should not attempt to parse them.
  public struct Metadata: Sendable {
    /// The name of the datum.
    public var name: String

    /// The value of the datum.
    public var value: String

    /// Whether or not this instance is recorded in human-readable output with
    /// the given verbosity level.
    ///
    /// - Parameters:
    ///   - verbosity: The verbosity level at which output is being recorded.
    ///
    /// - Returns: Whether or not this instance should be recorded.
    func shouldRecord(withVerbosity verbosity: Int) -> Bool {
      switch name {
      case Self._testingLibraryVersionName, Self._testingLibraryCommitName, Self._targetPlatformName:
        true
      default:
        verbosity > 0
      }
    }
  }
}

// MARK: - CustomStringConvertible

extension Event.Metadata: CustomStringConvertible {
  public var description: String {
    "\(name): \(value)"
  }
}

// MARK: - "Standard" metadata

extension Event.Metadata {
  /// The names of various metadata that the testing library collects.
  private static var _swiftStandardLibraryVersionName: String { "Swift Standard Library Version" }
  private static var _swiftCompilerVersionName: String { "Swift Compiler Version" }
  private static var _gnuCLibraryVersionName: String { "GNU C Library Version" }
  private static var _testingLibraryVersionName: String { "Testing Library Version" }
  private static var _testingLibraryCommitName: String { "Testing Library Commit" }
  private static var _targetPlatformName: String { "Target Platform" }
  private static var _simulatorOSVersionName: String { "OS Version (Simulator)" }
  private static var _hostOSVersionName: String { "OS Version (Host)" }
  private static var _osVersionName: String { "OS Version" }
  private static var _apiLevelName: String { "API Level" }

  /// All metadata that the testing library collects.
  static var all: [Self] {
    var result = [Self]()

    func append(_ name: String, _ value: some CustomStringConvertible) {
      let metadata = Event.Metadata(name: name, value: String(describing: value))
      result.append(metadata)
    }

    if let swiftStandardLibraryVersion {
      append(_swiftStandardLibraryVersionName, swiftStandardLibraryVersion)
    }
    append(_swiftCompilerVersionName, swiftCompilerVersion)
#if os(Linux) && canImport(Glibc)
    append(_gnuCLibraryVersionName, glibcVersion)
#endif
    if let testingLibraryVersion {
      append(_testingLibraryVersionName, testingLibraryVersion)
    }
    if let testingLibraryCommit {
      append(_testingLibraryCommitName, testingLibraryCommit)
    }
    if let targetTriple {
      append(_targetPlatformName, targetTriple)
    }
#if targetEnvironment(simulator)
    append(_simulatorOSVersionName, simulatorVersion)
    append(_hostOSVersionName, operatingSystemVersion)
#else
    append(_osVersionName, operatingSystemVersion)
#endif
#if os(Android)
    append(_apiLevelName, apiLevel)
#endif

    return result
  }
}
