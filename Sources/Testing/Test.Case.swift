//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ExperimentalParameterizedTesting)
extension Test {
  /// A single test case from a parameterized ``Test``.
  ///
  /// A test case represents a test run with a particular combination of inputs.
  /// Tests that are _not_ parameterized map to a single instance of
  /// ``Test/Case``.
  public struct Case: Sendable {
    /// The zero-based index of this test case.
    public var index: Int

    /// The parameterized inputs to this test case.
    public var arguments: [any Sendable]

    /// Returns a sequence of this test case's arguments paired with the
    /// specified test function parameters.
    ///
    /// - Parameters:
    ///   - parameters: The parameters to pair this test case's arguments with.
    ///
    /// - Returns: A sequence with each argument in this test case paired with
    ///   its corresponding parameter from the specified test function
    ///   parameters.
    ///
    /// If the count of `arguments` does not equal the count of `parameters` and
    /// the elements in `arguments` are tuples, the arguments included in the
    /// returned sequence will be replaced by the flattened list of those
    /// tuples' values.
    public func arguments(pairedWith parameters: [ParameterInfo]) -> some Sequence<(ParameterInfo, any Sendable)> {
      if parameters.count > 1 && arguments.count == 1 {
        let argument = arguments[0]
        let mirror = Mirror(reflecting: argument)
        if mirror.displayStyle == .tuple {
          let desugaredArguments = mirror.children.map { unsafeBitCast($0.value, to: (any Sendable).self) }
          return zip(parameters, desugaredArguments)
        }
      }

      return zip(parameters, arguments)
    }

    /// Whether or not this test case is from a parameterized test.
    public var isParameterized: Bool {
      !arguments.isEmpty
    }

    /// The body closure of this test case.
    ///
    /// Do not invoke this closure directly. Always use a ``Runner`` to invoke a
    /// test or test case.
    var body: @Sendable () async throws -> Void
  }

  /// A type representing a single parameter to a parameterized test function.
  ///
  /// This represents the parameter itself, and does not contain a specific
  /// value that might be passed via this parameter to a test function. To
  /// obtain the arguments of a particular ``Test/Case`` paired with their
  /// corresponding parameters, use ``Test/Case/arguments(pairedWith:)``.
  public struct ParameterInfo: Sendable {
    /// The first name of this parameter.
    public var firstName: String

    /// The second name of this parameter, if specified.
    public var secondName: String?
  }
}

/// A type-erased protocol describing a sequence of ``Test/Case`` instances.
///
/// This protocol is necessary because it is not currently possible to express
/// `Sequence<Test.Case> & Sendable` as an existential (`any`)
/// ([96960993](rdar://96960993)). It is also not possible to have a value of
/// an underlying generic sequence type without specifying its generic
/// parameters.
@_spi(ExperimentalParameterizedTesting)
public protocol TestCases: Sequence & Sendable where Element == Test.Case {
  /// Whether this sequence is for a parameterized test.
  ///
  /// Both non-parameterized and parameterized tests may have an associated
  /// sequence of ``Test/Case`` instances, so this can be used to distinguish
  /// between them.
  var isParameterized: Bool { get }
}
