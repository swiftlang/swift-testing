//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test.Case {
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

      init(bytes: some Sequence<UInt8>) {
        self.bytes = Array(bytes)
      }
    }

    /// A type representing an argument's value.
    struct Value: Sendable {
      /// An enumeration describing the different kinds of value that this type
      /// can represent.
      private enum _Kind: Sendable {
        /// A copyable value with no custom test description.
        ///
        /// - Parameters:
        ///   - value: The wrapped value.
        case `default`(_ value: any Sendable)

        /// A copyable value with a custom test description.
        ///
        /// - Parameters:
        ///   - value: The wrapped value.
        ///   - testDescription: A description of `value`.
        indirect case withCustomTestDescription(_ value: any Sendable, testDescription: String)

#if !hasFeature(Embedded)
        /// A move-only value.
        ///
        /// - Parameters:
        ///   - typeInfo: The type of the wrapped value.
        ///
        /// In the future, we may want to make this case store a yield-once
        /// function so it can represent `~Copyable` values directly.
        indirect case moveOnlyValue(_ typeInfo: TypeInfo)
#else
        /// A move-only value.
        case moveOnlyValue
#endif
      }

      /// The kind of value.
      private var _kind: _Kind

      /// The underlying argument value.
      var wrappedValue: any Sendable {
        switch _kind {
        case let .default(value), let .withCustomTestDescription(value, _):
          value
        case .moveOnlyValue:
          ()
        }
      }

#if !hasFeature(Embedded)
      /// The type of ``wrappedValue``.
      ///
      /// This property is necessary to support move-only values as they are
      /// borrowed and cannot be stored directly in an instance of ``Value``.
      var typeInfo: TypeInfo {
        switch _kind {
        case let .default(value), let .withCustomTestDescription(value, _):
          TypeInfo(describingTypeOf: value)
        case let .moveOnlyValue(typeInfo):
          typeInfo
        }
      }
#endif

      init<W>(_ wrappedValue: W, testDescription: String? = nil) where W: Sendable {
        if let testDescription {
          _kind = .withCustomTestDescription(wrappedValue, testDescription: testDescription)
        } else {
          _kind = .default(wrappedValue)
        }
      }

      init<W>(_ wrappedValue: borrowing W, testDescription: String? = nil) where W: Sendable & ~Copyable {
#if !hasFeature(Embedded)
        _kind = .moveOnlyValue(TypeInfo(describing: W.self))
#else
        _kind = .moveOnlyValue
#endif
      }

      init<W>(_ wrappedValue: W, testDescription: String? = nil) where W: Sendable & CustomTestStringConvertible {
        let testDescription = testDescription ?? String(describingForTest: wrappedValue)
        _kind = .withCustomTestDescription(wrappedValue, testDescription: testDescription)
      }

      /// Construct an instance of this type representing a tuple of two other
      /// other instances.
      ///
      /// - Parameters:
      ///   - value1: The instance representing the first element of the tuple.
      ///   - value2: The instance representing the second element of the tuple.
      init(tupleOf value1: Self, _ value2: Self) {
#if !hasFeature(Embedded)
        func open<each W>(_ wrappedValues: repeat each W) -> (repeat each W) where repeat each W: Sendable {
          (repeat each wrappedValues)
        }
        let wrappedValue = open(value1.wrappedValue, value2.wrappedValue)
#else
        let wrappedValue = (value1.wrappedValue, value2.wrappedValue)
#endif
        let testDescription = "(\(value1.testDescription), \(value2.testDescription))"
        self.init(wrappedValue, testDescription: testDescription)
      }
    }

    /// Storage for ``value``.
    private var _value: Value

    /// The value of this parameterized test argument.
    public var value: any Sendable {
      _value.wrappedValue
    }

    /// The type of this parameterized test argument's value.
    var typeInfo: TypeInfo {
#if !hasFeature(Embedded)
      _value.typeInfo
#else
      parameter.typeInfo
#endif
    }

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
    public var parameter: Test.Parameter

    init(id: ID, value: Value, parameter: Test.Parameter) {
      self.id = id
      self._value = value
      self.parameter = parameter
    }
  }
}

// MARK: - Making arguments from parameters

extension Test.Case.Argument {
  /// Make a sequence of instances of this type corresponding to the given test
  /// function parameters.
  ///
  /// - Parameters:
  ///   - values: The values passed as arguments to some test case.
  ///   - parameters: The parameters of the test function for some test case.
  ///
  /// - Returns: A tuple containing a sequence of instances of `Argument`
  ///   corresponding to the inputs as well as a flag indicating if the
  ///   arguments' IDs are stable over time.
  static func makeArguments(
    withValues values: some Sequence<Value>,
    for parameters: some Sequence<Test.Parameter>
  ) -> ([Self], isStable: Bool) {
    var isStable = true

    let arguments = zip(values, parameters).map { value, parameter in
      var stableArgumentID: ID?

      // Attempt to get a stable, encoded representation of this value if no
      // such attempts for previous values have failed.
      if isStable {
        do {
          stableArgumentID = try .init(identifying: value.wrappedValue, parameter: parameter)
        } catch {
          // FIXME: Capture the error and propagate to the user, not as a test
          // failure but as an advisory warning. A missing stable argument ID
          // will prevent re-running the test case, but isn't a blocking issue.
        }
      }

      let argumentID: ID
      if let stableArgumentID {
        argumentID = stableArgumentID
      } else {
        // If we couldn't get a stable representation of at least one value,
        // give up and consider the overall test case non-stable. This allows
        // skipping unnecessary work later: if any individual argument doesn't
        // have a stable ID, there's no point encoding the values which _are_
        // encodable.
        isStable = false
        argumentID = .init(bytes: String(describingForTest: value).utf8)
      }

      return Self(id: argumentID, value: value, parameter: parameter)
    }

    return (arguments, isStable)
  }
}

// MARK: - Making argument values

// FIXME: switch to variadic generics when Embedded Swift support improves

extension Test.Case.Argument.Value {
  /// Make the default `makeArgumentValues` callback for the given argument
  /// types and parameters.
  ///
  /// - Parameters:
  ///   - parameters: The parameters of the test function for which test cases
  ///     should be generated.
  ///
  /// - Returns: The default `makeArgumentValues` callback for the given
  ///   argument types and parameters.
  static func makeArgumentValues<E1, E2>(
    for parameters: [Test.Parameter]
  ) -> @Sendable (E1, E2) -> [Test.Case.Argument.Value] where E1: Sendable, E2: Sendable {
    let splitsArguments = parameters.count > 1
    return { e1, e2 in
      if splitsArguments {
        [Test.Case.Argument.Value(e1), Test.Case.Argument.Value(e2)]
      } else {
        [Test.Case.Argument.Value((e1, e2))]
      }
    }
  }
}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension Test.Case.Argument.ID: Codable {}
#endif

// MARK: - Equatable, Hashable

extension Test.Case.Argument.ID: Equatable, Hashable {}

// MARK: - CustomTestStringConvertible

extension Test.Case.Argument: CustomTestStringConvertible {
  public var testDescription: String {
    String(describingForTest: _value)
  }
}

extension Test.Case.Argument.Value: CustomTestStringConvertible {
  var testDescription: String {
    switch _kind {
    case let .default(value):
#if !hasFeature(Embedded)
      String(describingForTest: value)
#else
      UnavailableInEmbeddedSwift.testDescription
#endif
    case let .withCustomTestDescription(_, testDescription):
      testDescription
#if !hasFeature(Embedded)
    case let .moveOnlyValue(typeInfo):
      // TODO: extend CustomTestStringConvertible to ~Copyable
      "(instance of \(typeInfo))"
#else
    case .moveOnlyValue:
      UnavailableInEmbeddedSwift.testDescription
#endif
    }
  }
}

extension Test.Case.Argument.ID: CustomTestStringConvertible {
  public var testDescription: String {
    String(describingForTest: bytes)
  }
}
