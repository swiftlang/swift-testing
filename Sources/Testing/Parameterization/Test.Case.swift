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
    /// A type representing an argument passed to a parameter of a parameterized
    /// test function.
    public struct Argument: Sendable {
      /// A type representing the stable, unique identifier of a parameterized
      /// test argument.
      public struct ID: Sendable {
        /// The raw bytes of this instance's identifier.
        public var bytes: [UInt8]
      }

      /// The ID of this parameterized test argument, if any.
      ///
      /// The uniqueness of this value is narrow: it is considered unique only
      /// within the scope of the parameter of the test function this argument
      /// was passed to.
      ///
      /// The value of this property is `nil` when an ID cannot be formed. This
      /// may occur if the type of ``value`` does not conform to one of the
      /// protocols used for encoding a stable and unique representation of the
      /// value.
      ///
      /// ## See Also
      ///
      /// - ``CustomTestArgumentEncodable``
      public var id: ID?

      /// The value of this parameterized test argument.
      public var value: any Sendable

      /// The parameter of the test function to which this argument was passed.
      public var parameter: ParameterInfo
    }

    /// The arguments passed to this test case.
    ///
    /// If the argument was a tuple but its elements were passed to distinct
    /// parameters of the test function, each element of the tuple will be
    /// represented as a separate ``Argument`` instance paired with the
    /// ``Test/ParameterInfo`` to which it was passed. However, if the test
    /// function has a single tuple parameter, the tuple will be preserved and
    /// represented as one ``Argument`` instance.
    ///
    /// Non-parameterized test functions will have a single test case instance,
    /// and the value of this property will be an empty array for such test
    /// cases.
    public var arguments: [Argument]

    init(
      arguments: [Argument],
      body: @escaping @Sendable () async throws -> Void
    ) {
      self.arguments = arguments
      self.body = body
    }

    /// Initialize a test case by pairing values with their corresponding
    /// parameters to form the ``arguments`` array.
    ///
    /// - Parameters:
    ///   - values: The values passed to the parameters for this test case.
    ///   - parameters: The parameters of the test function for this test case.
    ///   - body: The body closure of this test case.
    ///
    /// - Throws: Any error encountered attempting to encode test arguments.
    init(
      values: [any Sendable],
      parameters: [ParameterInfo],
      body: @escaping @Sendable () async throws -> Void
    ) throws {
      let arguments = try zip(values, parameters).map { value, parameter in
        let context = Argument.Context(parameter: parameter)
        let id = try Argument.ID(identifying: value, in: context)
        return Argument(id: id, value: value, parameter: parameter)
      }
      self.init(arguments: arguments, body: body)
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
  /// corresponding parameters, use ``Test/Case/arguments``.
  public struct ParameterInfo: Sendable {
    /// The zero-based index of this parameter within its associated test's
    /// parameter list.
    public var index: Int

    /// The first name of this parameter.
    public var firstName: String

    /// The second name of this parameter, if specified.
    public var secondName: String?
  }
}

// MARK: - Codable

extension Test.Case.Argument.ID: Codable {}

// MARK: - Equatable, Hashable

extension Test.Case.Argument.ID: Hashable {}
