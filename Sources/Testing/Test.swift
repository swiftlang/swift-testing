//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if _runtime(_ObjC)
import ObjectiveC
#endif

/// A type representing a test or suite.
///
/// An instance of this type may represent:
///
/// - A type containing zero or more tests (i.e. a _test suite_);
/// - An individual test function (possibly contained within a type); or
/// - A test function parameterized over one or more sequences of inputs.
///
/// Two instances of this type are considered to be equal if the values of their
/// ``Test/id-swift.property`` properties are equal.
public struct Test: Sendable {
  /// The name of this instance.
  ///
  /// The value of this property is equal to the name of the symbol to which the
  /// ``Test`` attribute is applied (that is, the name of the type or function.)
  /// To get the customized display name specified as part of the ``Test``
  /// attribute, use the ``Test/displayName`` property.
  public var name: String

  /// The customized display name of this instance, if specified.
  public var displayName: String?

  /// The set of traits added to this instance when it was initialized.
  public var traits: [any Trait] {
    willSet {
      // Prevent programmatically adding suite traits to test functions or test
      // traits to test suites.
      func traitsAreCorrectlyTyped() -> Bool {
        if isSuite {
          return newValue.allSatisfy { $0 is any SuiteTrait }
        } else {
          return newValue.allSatisfy { $0 is any TestTrait }
        }
      }
      precondition(traitsAreCorrectlyTyped(), "Programmatically added an inapplicable trait to test \(self)")
    }
  }

  /// The source location of this test.
  public var sourceLocation: SourceLocation

  /// The type containing this test, if any.
  ///
  /// If a test is associated with a free function or static function, the value
  /// of this property is `nil`. To determine if a specific instance of ``Test``
  /// refers to this type itself, check the ``isSuite`` property.
  var containingType: Any.Type?

  /// The XCTest-compatible Objective-C selector corresponding to this
  /// instance's underlying test function.
  ///
  /// On platforms that do not support Objective-C interop, the value of this
  /// property is always `nil`.
  @_spi(ExperimentalTestRunning)
  public var xcTestCompatibleSelector: __XCTestCompatibleSelector?

  /// Storage for the ``testCases`` property.
  ///
  /// This use of `AnySequence` is necessary because it is not currently
  /// possible to express `Sequence<Test.Case> & Sendable` as an existential
  /// (`any`) ([96960993](rdar://96960993)). It is also not possible to have a
  /// value of an underlying generic sequence type without specifying its
  /// generic parameters.
  private var _testCases: (@Sendable () async -> AnySequence<Test.Case>)?

  /// The set of test cases associated with this test, if any.
  ///
  /// For parameterized tests, each test case is associated with a single
  /// combination of parameterized inputs. For non-parameterized tests, a single
  /// test case is synthesized. For test suite types (as opposed to test
  /// functions), the value of this property is `nil`.
  ///
  /// - Warning: The parameterized inputs to a test may have limited
  ///   availability if the test has the `@available` attribute applied to it.
  ///   This property does not evaluate availability, and the effect of reading
  ///   it on a platform where the inputs are unavailable is undefined.
  @_spi(ExperimentalParameterizedTesting)
  public var testCases: (some Sequence<Test.Case> & Sendable)? {
    get async {
      await _testCases?()
    }
  }

  /// Whether or not this test is parameterized.
  @_spi(ExperimentalParameterizedTesting)
  public var isParameterized: Bool {
    guard let parameterCount = parameters?.count else {
      return false
    }
    return parameterCount != 0
  }

  /// The test function parameters, if any.
  ///
  /// If this instance represents a test function, the value of this property is
  /// an array of values describing its parameters, which may be empty if the
  /// test function is non-parameterized. If this instance represents a test
  /// suite, the value of this property is `nil`.
  @_spi(ExperimentalParameterizedTesting)
  public var parameters: [ParameterInfo]?

  /// Whether or not this instance is a test suite containing other tests.
  ///
  /// Instances of ``Test`` attached to types rather than functions are test
  /// suites. They do not contain any test logic of their own, but they may
  /// have traits added to them that also apply to their subtests.
  ///
  /// A test suite can be declared using the ``Suite(_:_:)`` macro.
  public var isSuite: Bool {
    containingType != nil && _testCases == nil
  }

  /// Initialize an instance of this type representing a test suite type.
  init(
    name: String,
    displayName: String? = nil,
    traits: [any Trait],
    sourceLocation: SourceLocation,
    containingType: Any.Type
  ) {
    self.name = name
    self.displayName = displayName
    self.traits = traits
    self.sourceLocation = sourceLocation
    self.containingType = containingType
  }

  /// Initialize an instance of this type representing a test function.
  init<S>(
    name: String,
    displayName: String? = nil,
    traits: [any Trait],
    sourceLocation: SourceLocation,
    containingType: Any.Type? = nil,
    xcTestCompatibleSelector: __XCTestCompatibleSelector? = nil,
    testCases: Test.Case.Generator<S>,
    parameters: [ParameterInfo]
  ) {
    self.name = name
    self.displayName = displayName
    self.traits = traits
    self.sourceLocation = sourceLocation
    self.containingType = containingType
    self.xcTestCompatibleSelector = xcTestCompatibleSelector
    self._testCases = { await .init(testCases.generate()) }
    self.parameters = parameters
  }
}

// MARK: - Equatable, Hashable

extension Test: Equatable, Hashable {
  public static func ==(lhs: Test, rhs: Test) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
