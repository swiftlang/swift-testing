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

#if _runtime(_ObjC)
public import ObjectiveC

/// An XCTest-compatible Objective-C selector.
///
/// - Warning: This type alias is used to implement the `@Test` macro. Do not
///   use it directly.
public typealias __XCTestCompatibleSelector = Selector
#else
/// Unused.
///
/// - Warning: This type alias is used to implement the `@Test` macro. Do not
///   use it directly.
public typealias __XCTestCompatibleSelector = Never
#endif

/// Make an XCTest-compatible Objective-C selector from a string.
///
/// - Parameters:
///   - selector: The string representation of the selector.
///
/// - Returns: A selector equivalent to `selector`. On platforms without
///   Objective-C interop, this function always returns `nil`.
///
/// - Warning: This function is used to implement the `@Test` macro. Do not use
///   it directly.
@inlinable public func __xcTestCompatibleSelector(_ selector: String) -> __XCTestCompatibleSelector? {
#if _runtime(_ObjC)
  __XCTestCompatibleSelector(selector)
#else
  nil
#endif
}

/// This file provides support for the `@Test` macro. Other than the macro
/// itself, the symbols in this file should not be used directly and are subject
/// to change as the testing library evolves.

// MARK: - @Suite

/// Declare a test suite.
///
/// - Parameters:
///   - traits: Zero or more traits to apply to this test suite.
///
/// A test suite is a type that contains one or more test functions. Any
/// copyable type (that is, any type that is not marked `~Copyable`) may be a
/// test suite.
///
/// The use of the `@Suite` attribute is optional; types are recognized as test
/// suites even if they do not have the `@Suite` attribute applied to them.
///
/// When adding test functions to a type extension, do not use the `@Suite`
/// attribute. Only a type's primary declaration may have the `@Suite` attribute
/// applied to it.
///
/// ## See Also
///
/// - <doc:OrganizingTests>
@_documentation(visibility: private)
@attached(member) @attached(peer) public macro Suite(
  _ traits: any SuiteTrait...
) = #externalMacro(module: "TestingMacros", type: "SuiteDeclarationMacro")

/// Declare a test suite.
///
/// - Parameters:
///   - displayName: The customized display name of this test suite. If the
///     value of this argument is `nil`, the display name of the test is derived
///     from the associated type's name.
///   - traits: Zero or more traits to apply to this test suite.
///
/// A test suite is a type that contains one or more test functions. Any
/// copyable type (that is, any type that is not marked `~Copyable`) may be a
/// test suite.
///
/// The use of the `@Suite` attribute is optional; types are recognized as test
/// suites even if they do not have the `@Suite` attribute applied to them.
///
/// When adding test functions to a type extension, do not use the `@Suite`
/// attribute. Only a type's primary declaration may have the `@Suite` attribute
/// applied to it.
///
/// ## See Also
///
/// - <doc:OrganizingTests>
@attached(member) @attached(peer) public macro Suite(
  _ displayName: _const String? = nil,
  _ traits: any SuiteTrait...
) = #externalMacro(module: "TestingMacros", type: "SuiteDeclarationMacro")

extension Test {
  /// Create an instance of ``Test`` for a suite type.
  ///
  /// - Warning: This function is used to implement the `@Suite` macro. Do not
  ///   call it directly.
  public static func __type(
    _ containingType: Any.Type,
    displayName: String? = nil,
    traits: [any SuiteTrait],
    sourceLocation: SourceLocation
  ) -> Self {
    let typeName = _typeName(containingType, qualified: false)
    return Self(name: typeName, displayName: displayName, traits: traits, sourceLocation: sourceLocation, containingType: containingType, testCases: nil)
  }
}

// MARK: - @Test

/// This macro declaration is necessary to help the compiler disambiguate
/// display names from traits, but it does not need to be documented separately.
///
/// ## See Also
///
/// - ``Test(_:_:)``
@_documentation(visibility: private)
@attached(peer) public macro Test(
  _ traits: any TestTrait...
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro")

/// Declare a test.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer) public macro Test(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro")

extension Test {
  /// Information about a parameter to a test function.
  ///
  /// - Warning: This type alias is used to implement the `@Test` macro. Do not
  ///   use it directly.
  public typealias __ParameterInfo = (firstName: String, secondName: String?)

  /// Create an instance of ``Test`` for a function.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __function(
    named testFunctionName: String,
    in containingType: Any.Type?,
    xcTestCompatibleSelector: __XCTestCompatibleSelector?,
    displayName: String? = nil,
    traits: [any TestTrait],
    sourceLocation: SourceLocation,
    parameters: [__ParameterInfo] = [],
    testFunction: @escaping @Sendable () async throws -> Void
  ) -> Self {
    let caseGenerator = Case.Generator(testFunction: testFunction)
    return Self(name: testFunctionName, displayName: displayName, traits: traits, sourceLocation: sourceLocation, containingType: containingType, xcTestCompatibleSelector: xcTestCompatibleSelector, testCases: caseGenerator, parameters: [])
  }
}

extension [Test.__ParameterInfo] {
  /// An array of ``Test/ParameterInfo`` values based on this array of parameter
  /// tuples.
  ///
  /// This conversion derives the value of the `index` property of the resulting
  /// parameter instances from the position of the tuple in the original array.
  fileprivate var parameters: [Test.ParameterInfo] {
    enumerated().map { index, parameter in
      Test.ParameterInfo(index: index, firstName: parameter.firstName, secondName: parameter.secondName)
    }
  }
}

// MARK: - @Test(arguments:)

/// This macro declaration is necessary to help the compiler disambiguate
/// display names from traits, but it does not need to be documented separately.
///
/// ## See Also
///
/// - ``Test(_:arguments:)-35dat``
@_documentation(visibility: private)
@attached(peer) public macro Test<C>(
  _ traits: any TestTrait...,
  arguments collection: C
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C: Collection & Sendable, C.Element: Sendable

/// Declare a test parameterized over a collection of values.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///   - collection: A collection of values to pass to the associated test
///     function.
///
/// During testing, the associated test function is called once for each element
/// in `collection`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer) public macro Test<C>(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...,
  arguments collection: C
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C: Collection & Sendable, C.Element: Sendable

extension Test {
  /// Create an instance of ``Test`` for a parameterized function.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __function<C>(
    named testFunctionName: String,
    in containingType: Any.Type?,
    xcTestCompatibleSelector: __XCTestCompatibleSelector?,
    displayName: String? = nil,
    traits: [any TestTrait],
    arguments collection: C,
    sourceLocation: SourceLocation,
    parameters paramTuples: [__ParameterInfo],
    testFunction: @escaping @Sendable (C.Element) async throws -> Void
  ) -> Self where C: Collection & Sendable, C.Element: Sendable {
    let caseGenerator = Case.Generator(arguments: collection, testFunction: testFunction)
    return Self(name: testFunctionName, displayName: displayName, traits: traits, sourceLocation: sourceLocation, containingType: containingType, xcTestCompatibleSelector: xcTestCompatibleSelector, testCases: caseGenerator, parameters: paramTuples.parameters)
  }
}

// MARK: - @Test(arguments:_:)

/// Declare a test parameterized over two collections of values.
///
/// - Parameters:
///   - traits: Zero or more traits to apply to this test.
///   - collection1: A collection of values to pass to `testFunction`.
///   - collection2: A second collection of values to pass to `testFunction`.
///
/// During testing, the associated test function is called once for each pair of
/// elements in `collection1` and `collection2`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@_documentation(visibility: private)
@attached(peer) public macro Test<C1, C2>(
  _ traits: any TestTrait...,
  arguments collection1: C1, _ collection2: C2
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable

/// Declare a test parameterized over two collections of values.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///   - collection1: A collection of values to pass to `testFunction`.
///   - collection2: A second collection of values to pass to `testFunction`.
///
/// During testing, the associated test function is called once for each pair of
/// elements in `collection1` and `collection2`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer) public macro Test<C1, C2>(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...,
  arguments collection1: C1, _ collection2: C2
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable

// MARK: - @Test(arguments: zip(...))

/// Declare a test parameterized over two zipped collections of values.
///
/// - Parameters:
///   - traits: Zero or more traits to apply to this test.
///   - zippedCollections: Two zipped collections of values to pass to
///     `testFunction`.
///
/// During testing, the associated test function is called once for each element
/// in `zippedCollections`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@_documentation(visibility: private)
@attached(peer) public macro Test<C1, C2>(
  _ traits: any TestTrait...,
  arguments zippedCollections: Zip2Sequence<C1, C2>
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable

/// Declare a test parameterized over two zipped collections of values.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///   - zippedCollections: Two zipped collections of values to pass to
///     `testFunction`.
///
/// During testing, the associated test function is called once for each element
/// in `zippedCollections`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer) public macro Test<C1, C2>(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...,
  arguments zippedCollections: Zip2Sequence<C1, C2>
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable

extension Test {
  /// Create an instance of ``Test`` for a parameterized function.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __function<C1, C2>(
    named testFunctionName: String,
    in containingType: Any.Type?,
    xcTestCompatibleSelector: __XCTestCompatibleSelector?,
    displayName: String? = nil,
    traits: [any TestTrait],
    arguments collection1: C1, _ collection2: C2,
    sourceLocation: SourceLocation,
    parameters paramTuples: [__ParameterInfo],
    testFunction: @escaping @Sendable (C1.Element, C2.Element) async throws -> Void
  ) -> Self where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable {
    let caseGenerator = Case.Generator(arguments: collection1, collection2, testFunction: testFunction)
    return Self(name: testFunctionName, displayName: displayName, traits: traits, sourceLocation: sourceLocation, containingType: containingType, xcTestCompatibleSelector: xcTestCompatibleSelector, testCases: caseGenerator, parameters: paramTuples.parameters)
  }

  /// Create an instance of ``Test`` for a parameterized function.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __function<C1, C2>(
    named testFunctionName: String,
    in containingType: Any.Type?,
    xcTestCompatibleSelector: __XCTestCompatibleSelector?,
    displayName: String? = nil,
    traits: [any TestTrait],
    arguments zippedCollections: Zip2Sequence<C1, C2>,
    sourceLocation: SourceLocation,
    parameters paramTuples: [__ParameterInfo],
    testFunction: @escaping @Sendable (C1.Element, C2.Element) async throws -> Void
  ) -> Self where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable {
    let caseGenerator = Case.Generator(arguments: zippedCollections) {
      try await testFunction($0, $1)
    }
    return Self(name: testFunctionName, displayName: displayName, traits: traits, sourceLocation: sourceLocation, containingType: containingType, xcTestCompatibleSelector: xcTestCompatibleSelector, testCases: caseGenerator, parameters: paramTuples.parameters)
  }
}

// MARK: - Helper functions

/// A value that abstracts away whether or not the `try` keyword is needed on an
/// expression.
///
/// - Warning: This value is used to implement the `@Test` macro. Do not use
///   it directly.
@inlinable public var __requiringTry: Void {
  @inlinable get throws {}
}

/// A value that abstracts away whether or not the `await` keyword is needed on
/// an expression.
///
/// - Warning: This value is used to implement the `@Test` macro. Do not use
///   it directly.
@inlinable public var __requiringAwait: Void {
  @inlinable get async {}
}

#if !SWT_NO_GLOBAL_ACTORS
/// Invoke a function isolated to the main actor if appropriate.
///
/// - Parameters:
///   - thenBody: The function to invoke, isolated to the main actor, if actor
///     isolation is required.
///   - elseBody: The function to invoke if actor isolation is not required.
///
/// - Returns: Whatever is returned by `thenBody` or `elseBody`.
///
/// - Throws: Whatever is thrown by `thenBody` or `elseBody`.
///
/// `thenBody` and `elseBody` should represent the same function with differing
/// actor isolation. Which one is invoked depends on whether or not synchronous
/// test functions need to run on the main actor.
///
/// - Warning: This function is used to implement the `@Test` macro. Do not call
///   it directly.
public func __ifMainActorIsolationEnforced<R>(
  _ thenBody: @Sendable @MainActor () async throws -> R,
  else elseBody: @Sendable () async throws -> R
) async throws -> R where R: Sendable {
  if Configuration.current?.isMainActorIsolationEnforced == true {
    try await thenBody()
  } else {
    try await elseBody()
  }
}
#else
/// Invoke a function.
///
/// - Parameters:
///   - body: The function to invoke.
///
/// - Returns: Whatever is returned by `body`.
///
/// - Throws: Whatever is thrown by `body`.
///
/// This function simply invokes `body`. Its signature matches that of the same
/// function when `SWT_NO_GLOBAL_ACTORS` is not defined so that it can be used
/// during expansion of the `@Test` macro without knowing the value of that
/// compiler conditional on the target platform.
///
/// - Warning: This function is used to implement the `@Test` macro. Do not call
///   it directly.
@inlinable public func __ifMainActorIsolationEnforced<R>(
  _: @Sendable () async throws -> R,
  else body: @Sendable () async throws -> R
) async throws -> R where R: Sendable {
  try await body()
}
#endif

/// Run a test function as an `XCTestCase`-compatible method.
///
/// This overload is used for types that are not classes. It always returns
/// `false`.
///
/// - Warning: This function is used to implement the `@Test` macro. Do not call
///   it directly.
@inlinable public func __invokeXCTestCaseMethod<T>(
  _ selector: __XCTestCompatibleSelector?,
  onInstanceOf type: T.Type,
  sourceLocation: SourceLocation
) async throws -> Bool {
  false
}

// TODO: implement a hook in XCTest that __invokeXCTestCaseMethod() can call to
// run an XCTestCase nested in the current @Test function.

/// The `XCTestCase` Objective-C class.
let xcTestCaseClass: AnyClass? = {
#if _runtime(_ObjC)
  objc_getClass("XCTestCase") as? AnyClass
#else
  _typeByName("6XCTest0A4CaseC") as? AnyClass // _mangledTypeName(XCTest.XCTestCase.self)
#endif
}()

/// Run a test function as an `XCTestCase`-compatible method.
///
/// This overload is used when XCTest can be directly imported and the compiler
/// can tell that the test suite type is a subclass of `XCTestCase`.
///
/// - Warning: This function is used to implement the `@Test` macro. Do not call
///   it directly.
public func __invokeXCTestCaseMethod<T>(
  _ selector: __XCTestCompatibleSelector?,
  onInstanceOf xcTestCaseSubclass: T.Type,
  sourceLocation: SourceLocation
) async throws -> Bool where T: AnyObject {
  // Any NSObject subclass might end up on this code path, so only record an
  // issue if it is really an XCTestCase subclass.
  guard let xcTestCaseClass, isClass(xcTestCaseSubclass, subclassOf: xcTestCaseClass) else {
    return false
  }
  Issue.record(
    .apiMisused,
    comments: ["The @Test attribute cannot be applied to methods on a subclass of XCTestCase."],
    backtrace: nil,
    sourceLocation: sourceLocation
  )
  return true
}

// MARK: - Discovery

/// A protocol describing a type that contains tests.
///
/// - Warning: This protocol is used to implement the `@Test` macro. Do not use
///   it directly.
@_alwaysEmitConformanceMetadata
public protocol __TestContainer {
  /// The set of tests contained by this type.
  static var __tests: [Test] { get async }
}

extension Test {
  /// A string that appears within all auto-generated types conforming to the
  /// `__TestContainer` protocol.
  private static let _testContainerTypeNameMagic = "__🟠$test_container__"

  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified.
  static var all: some Sequence<Test> {
    get async {
      // Convert the raw sequence of tests to a dictionary keyed by ID.
      var result = await testsByID(_all)

      // Ensure test suite types that don't have the @Suite attribute are still
      // represented in the result.
      _synthesizeSuiteTypes(into: &result)

      return result.values
    }
  }

  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified. This sequence may
  /// contain duplicates; callers should use ``all`` instead.
  private static var _all: some Sequence<Self> {
    get async {
      await withTaskGroup(of: [Self].self) { taskGroup in
        swt_enumerateTypes({ typeName, _ in
          // strstr() lets us avoid copying either string before comparing.
          Self._testContainerTypeNameMagic.withCString { testContainerTypeNameMagic in
            nil != strstr(typeName, testContainerTypeNameMagic)
          }
        }, /*typeEnumerator:*/ { type, context in
          if let type = unsafeBitCast(type, to: Any.Type.self) as? any __TestContainer.Type {
            let taskGroup = context!.assumingMemoryBound(to: TaskGroup<[Self]>.self)
            taskGroup.pointee.addTask {
              await type.__tests
            }
          }
        }, &taskGroup)

        return await taskGroup.reduce(into: [], +=)
      }
    }
  }

  /// Create a dictionary mapping the IDs of a sequence of tests to those tests.
  ///
  /// - Parameters:
  ///   - tests: The sequence to convert to a dictionary.
  ///
  /// - Returns: A dictionary containing `tests` keyed by those tests' IDs.
  static func testsByID(_ tests: some Sequence<Self>) -> [ID: Self] {
    [ID: Self](
      tests.lazy.map { ($0.id, $0) },
      uniquingKeysWith: { existing, _ in existing }
    ) 
  }

  /// Synthesize any missing test suite types (that is, types containing test
  /// content that do not have the `@Suite` attribute) and add them to a
  /// dictionary of tests.
  ///
  /// - Parameters:
  ///   - tests: A dictionary of tests to amend.
  ///
  /// - Returns: The number of key-value pairs added to `tests`.
  ///
  /// - Bug: This function is necessary because containing type information is
  ///   not available during expansion of the `@Test` macro.
  ///   ([105470382](rdar://105470382))
  @discardableResult private static func _synthesizeSuiteTypes(into tests: inout [ID: Self]) -> Int {
    let originalCount = tests.count

    // Find any instances of Test in the input that are *not* suites. We'll be
    // checking the containing types of each one.
    for test in tests.values where !test.isSuite {
      guard let suiteType = test.containingType else {
        continue
      }
      let suiteID = ID(type: suiteType)
      if tests[suiteID] == nil {
        // If the real test is hidden, so shall the synthesized test be hidden.
        // Copy the exact traits from the real test in case they someday carry
        // any interesting metadata.
        let traits = test.traits.compactMap { $0 as? HiddenTrait }
        tests[suiteID] = .__type(suiteType, displayName: nil, traits: traits, sourceLocation: test.sourceLocation)
      }
    }

    return tests.count - originalCount
  }
}
