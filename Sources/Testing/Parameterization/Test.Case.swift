//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test {
  /// A single test case from a parameterized ``Test``.
  ///
  /// A test case represents a test run with a particular combination of inputs.
  /// Tests that are _not_ parameterized map to a single instance of
  /// ``Test/Case``.
  public struct Case: Sendable {
    /// A type representing an argument passed to a parameter of a parameterized
    /// test function.
    @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
    public struct Argument: Sendable {
      /// A type representing the stable, unique identifier of a parameterized
      /// test argument.
      @_spi(ForToolsIntegrationOnly)
      public struct ID: Sendable {
        /// The raw bytes of this instance's identifier.
        public var bytes: [UInt8]

        /// Whether or not this argument ID is considered stable across
        /// successive runs.
        ///
        /// If the value of this property is `true`, the testing library can use
        /// this ID to deterministically match against the original argument
        /// it represents, and a user can selectively (re-)run that argument
        /// of the associated parameterized test. If it is `false`, that
        /// functionality is not supported for the argument this ID represents.
        public var isStable: Bool

        public init(bytes: some Sequence<UInt8>, isStable: Bool) {
          self.bytes = Array(bytes)
          self.isStable = isStable
        }
      }

      /// The value of this parameterized test argument.
      public var value: any Sendable

      /// The ID of this parameterized test argument.
      ///
      /// The uniqueness of this value is narrow: it is considered unique only
      /// within the scope of the parameter of the test function this argument
      /// was passed to.
      ///
      /// ## See Also
      ///
      /// - ``CustomTestArgumentEncodable``
      public var id: ID

      /// The parameter of the test function to which this argument was passed.
      public var parameter: Parameter

      /// Initialize an instance of this type representing the specified
      /// argument value.
      ///
      /// - Parameters:
      ///   - value: The value of this parameterized test argument.
      ///   - encodableValue: An encodable representation of `value`, if one is
      ///     available. When non-`nil`, this is used to attempt to form a
      ///     stable identifier.
      ///   - parameter: The parameter of the test function to which this
      ///     argument was passed.
      ///
      /// This forms an ``ID`` identifying `value` using `encodableValue`.
      init(value: any Sendable, encodableValue: (any Encodable)?, parameter: Parameter) {
        self.value = value
        self.id = .init(identifying: value, encodableValue: encodableValue, parameter: parameter)
        self.parameter = parameter
      }
    }

    /// The arguments passed to this test case.
    ///
    /// If the argument was a tuple but its elements were passed to distinct
    /// parameters of the test function, each element of the tuple will be
    /// represented as a separate ``Argument`` instance paired with the
    /// ``Test/Parameter`` to which it was passed. However, if the test
    /// function has a single tuple parameter, the tuple will be preserved and
    /// represented as one ``Argument`` instance.
    ///
    /// Non-parameterized test functions will have a single test case instance,
    /// and the value of this property will be an empty array for such test
    /// cases.
    @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
    public var arguments: [Argument]

    /// A number used to distinguish this test case from others associated with
    /// the same test function whose arguments have the same ID.
    ///
    /// As an example, imagine the same argument is passed more than once to a
    /// parameterized test:
    ///
    /// ```swift
    /// @Test(arguments: [1, 1])
    /// func example(x: Int) { ... }
    /// ```
    ///
    /// There will be two ``Test/Case`` instances associated with this test
    /// function. Each will represent one instance of the repeated argument `1`,
    /// and each will have a different value for this property.
    ///
    /// The value of this property for successive runs of the same test are not
    /// guaranteed to be the same. The value of this property may be equal for
    /// two test cases associated with the same test if the IDs of their
    /// arguments are different.
    @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
    public var discriminator: Int = 0

    /// Initialize a test case for a non-parameterized test function.
    ///
    /// - Parameters:
    ///   - body: The body closure of this test case.
    ///
    /// The resulting test case will have zero arguments.
    init(body: @escaping @Sendable () async throws -> Void) {
      self.arguments = []
      self.body = body
    }

    /// Initialize a test case by pairing values with their corresponding
    /// parameters to form the ``arguments`` array.
    ///
    /// - Parameters:
    ///   - values: The values passed to the parameters for this test case.
    ///   - parameters: The parameters of the test function for this test case.
    ///   - body: The body closure of this test case.
    init(
      values: [any Sendable],
      parameters: [Parameter],
      body: @escaping @Sendable () async throws -> Void
    ) {
      // Attempt to obtain an encodable representation of each value in order
      // to construct a stable ID.
      let encodingResult = values.reduce(into: ([any Encodable](), hasFailure: false)) { result, value in
        // If we couldn't get an encodable representation of one of the values,
        // give up and mark the overall attempt as a failure. This allows
        // skipping unnecessary encoding work later: if any individual argument
        // doesn't have a stable ID, the Test.Case.ID can't be considered stable,
        // so there's no point encoding the values which _are_ encodable.
        guard !result.hasFailure, let encodableValue = encodableArgumentValue(for: value) else {
          return result.hasFailure = true
        }
        result.0.append(encodableValue)
      }
      let encodableValues: [any Encodable]? = if !encodingResult.hasFailure {
        encodingResult.0
      } else {
        nil
      }

      self.arguments = zip(values.enumerated(), parameters).map { value, parameter in
        Argument(value: value.1, encodableValue: encodableValues?[value.0], parameter: parameter)
      }
      self.body = body
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
  @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
  public struct Parameter: Sendable {
    /// The zero-based index of this parameter within its associated test's
    /// parameter list.
    public var index: Int

    /// The first name of this parameter.
    public var firstName: String

    /// The second name of this parameter, if specified.
    public var secondName: String?

    /// Information about the type of this parameter.
    ///
    /// The value of this property represents the type of the parameter, but
    /// arguments passed to this parameter may be of different types. For
    /// example, an argument may be a subclass or conforming type of the
    /// declared parameter type.
    ///
    /// For information about runtime type of an argument to a parameterized
    /// test, use ``TypeInfo/init(describingTypeOf:)``, passing the argument
    /// value obtained by calling ``Test/Case/Argument/value``.
    @_spi(ForToolsIntegrationOnly)
    public var typeInfo: TypeInfo

    init(index: Int, firstName: String, secondName: String? = nil, type: Any.Type) {
      self.index = index
      self.firstName = firstName
      self.secondName = secondName
      self.typeInfo = TypeInfo(describing: type)
    }
  }
}

// MARK: - Codable

extension Test.Parameter: Codable {}
extension Test.Case.Argument.ID: Codable {
  public init(from decoder: some Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // The `isStable` property was added after this type was introduced.
    // Previously, only stable argument IDs were ever encoded, so if we're
    // attempting to decode one, we can safely assume it is stable.
    let isStable = try container.decodeIfPresent(type(of: isStable), forKey: .isStable) ?? true

    let bytes = try container.decode(type(of: bytes), forKey: .bytes)
    self.init(bytes: bytes, isStable: isStable)
  }
}

// MARK: - Equatable, Hashable

extension Test.Case: Hashable {
  public static func ==(lhs: Test.Case, rhs: Test.Case) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension Test.Parameter: Hashable {}
extension Test.Case.Argument.ID: Hashable {}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Snapshotting

extension Test.Case {
  /// A serializable snapshot of a ``Test/Case`` instance.
  @_spi(ForToolsIntegrationOnly)
  public struct Snapshot: Sendable, Codable {
    /// The ID of this test case.
    public var id: ID

    /// The arguments passed to this test case.
    public var arguments: [Argument.Snapshot]

    /// Whether or not this test case is from a parameterized test.
    public var isParameterized: Bool {
      !arguments.isEmpty
    }

    /// Initialize an instance of this type by snapshotting the specified test
    /// case.
    ///
    /// - Parameters:
    ///   - testCase: The original test case to snapshot.
    public init(snapshotting testCase: borrowing Test.Case) {
      id = testCase.id
      arguments = testCase.arguments.map(Test.Case.Argument.Snapshot.init)
    }
  }
}

extension Test.Case.Argument {
  /// A serializable snapshot of a ``Test/Case/Argument`` instance.
  @_spi(ForToolsIntegrationOnly)
  public struct Snapshot: Sendable, Codable {
    /// The ID of this parameterized test argument.
    public var id: Test.Case.Argument.ID

    /// A representation of this parameterized test argument's
    /// ``Test/Case/Argument/value`` property.
    public var value: Expression.Value

    /// The parameter of the test function to which this argument was passed.
    public var parameter: Test.Parameter

    /// Initialize an instance of this type by snapshotting the specified test
    /// case argument.
    ///
    /// - Parameters:
    ///   - argument: The original test case argument to snapshot.
    public init(snapshotting argument: Test.Case.Argument) {
      id = argument.id
      value = Expression.Value(reflecting: argument.value) ?? .init(describing: argument.value)
      parameter = argument.parameter
    }

    public init(from decoder: some Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)

      // The `id` property was optional when this type was first introduced,
      // and a `nil` value represented an argument whose ID was non-stable.
      // To maintain previous behavior, if this value is absent when decoding,
      // default to an argument ID marked as non-stable.
      id = try container.decodeIfPresent(Test.Case.Argument.ID.self, forKey: .id)
        ?? ID(bytes: [], isStable: false)

      value = try container.decode(type(of: value), forKey: .value)
      parameter = try container.decode(type(of: parameter), forKey: .parameter)
    }
  }
}
#endif
