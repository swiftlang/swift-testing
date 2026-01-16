//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if canImport(Foundation) && _runtime(_ObjC)
private import ObjectiveC
#endif

// TODO: update this documentation to clarify .serialized vs. .serialized(for:)

/// A type that defines whether the testing library runs this test serially
/// or in parallel.
///
/// When you add this trait to a parameterized test function, that test runs its
/// cases serially instead of in parallel. This trait has no effect when you
/// apply it to a non-parameterized test function.
///
/// When you add this trait to a test suite, that suite runs its
/// contained test functions (including their cases, when parameterized) and
/// sub-suites serially instead of in parallel. If the sub-suites have children,
/// they also run serially.
///
/// This trait does not affect the execution of a test relative to its peers or
/// to unrelated tests. This trait has no effect if you disable test
/// parallelization globally (for example, by passing `--no-parallel` to the
/// `swift test` command.)
///
/// To add this trait to a test, use ``Trait/serialized``.
public struct ParallelizationTrait: TestTrait, SuiteTrait {
#if !hasFeature(Embedded)
  /// A type that describes a data-based dependency that a test may have.
  ///
  /// When a test has a dependency, the testing library assumes it cannot run at
  /// the same time as other tests with the same dependency.
  @_spi(Experimental)
  public struct Dependency: Sendable {
    /// An enumeration describing the supported kinds of dependencies.
    enum Kind: Equatable, Hashable {
      /// An unbounded dependency.
      case unbounded

      /// A dependency on all or part of the process' environment block.
      case environ

      /// A dependency on a given key path.
      ///
      /// This case is used when a test author writes `.serialized(for: T.self)`
      /// because key paths are equatable and hashable, but metatypes are not.
      ///
      /// - Note: Currently, we only provide an interface to describe a Swift
      ///   type. If the standard library adds API to decompose a key path, we
      ///   can support other kinds of key paths.
      case keyPath(AnyKeyPath)

      /// A dependency on an address in memory.
      case address(UnsafeMutableRawPointer)

      /// A dependency on a tag.
      case tag(Tag)
    }

    /// The kind of this dependency.
    nonisolated(unsafe) var kind: Kind
  }

  /// This instance's dependency, if any.
  ///
  /// If the value of this property is `nil`, it is the otherwise-unspecialized
  /// ``serialized`` trait.
  var dependency: Dependency?

  /// A mapping of dependencies to serializers.
  private static nonisolated(unsafe) let _serializers = Locked<[Dependency.Kind: Serializer]>()
#endif
}

#if !hasFeature(Embedded)
// MARK: - Parallelization over a dependency

extension ParallelizationTrait {
  public var isRecursive: Bool {
    // If the trait has a dependency, apply it to child tests/suites so that
    // they are able to "see" parent suites' dependencies and correctly account
    // for them.
    dependency != nil
  }

  public func prepare(for test: Test) async throws {
    guard let dependency else {
      return
    }

    // Ensure a serializer has been created for this trait's dependency (except
    // .unbounded which is special-cased.)
    let kind = dependency.kind
    if kind != .unbounded {
      Self._serializers.withLock { serializers in
        if serializers[kind] == nil {
          serializers[kind] = Serializer()
        }
      }
    }
  }

  public func _reduce(into other: any Trait) -> (any Trait)? {
    guard var other = other as? Self else {
      // The other trait is not a ParallelizationTrait instance, so ignore it.
      return nil
    }

    let selfKind = dependency?.kind
    let otherKind = other.dependency?.kind

    switch (selfKind, otherKind) {
    case (.none, .none),
      (.some, .some) where selfKind == otherKind:
      // Both traits have equivalent (or no) dependencies. Use the other trait
      // and discard this one.
      break
    case (.some, .some):
      // The two traits have different dependencies. Combine them into a single
      // .unbounded dependency.
      other = .serialized(for: *)
    case (.some, .none):
      // This trait specifies a dependency, but the other one does not. Use this
      // trait and discard the other one.
      other = self
    case (.none, .some):
      // The other trait specifies a dependency, but this one does not. Use the
      // other trait and discard this one.
      break
    }

    // NOTE: We always reduce to a single ParallelizationTrait instance, so this
    // function always returns the other instance.
    return other
  }
}
#endif

// MARK: - TestScoping

extension ParallelizationTrait: TestScoping {
  public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
    // When applied to a test function, this trait should provide scope to the
    // test function itself, not its individual test cases, since that allows
    // Runner to correctly interpret the configuration setting to disable
    // parallelization.
    test.isSuite || testCase == nil ? self : nil
  }

  public func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
    guard var configuration = Configuration.current else {
      throw SystemError(description: "There is no current Configuration when attempting to provide scope for test '\(test.name)'. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }

    configuration.isParallelizationEnabled = false
#if !hasFeature(Embedded)
    try await Configuration.withCurrent(configuration) {
      if test.isSuite {
        // Suites do not need to use a serializer since they don't run their own
        // code. Test functions within the suite will use serializers as needed.
        return try await function()
      }
      guard let dependency else {
        // This trait does not specify a dependency to serialize for.
        return try await function()
      }

      switch dependency.kind {
      case .unbounded:
        try await withoutActuallyEscaping(function) { function in
          // The function we're running depends on all global state, so it
          // should be serialized by all serializers that were created by
          // prepare(). See Runner._applyScopingTraits() for an explanation of
          // what this code does.
          // TODO: share an implementation with that function?
          let function = Self._serializers.rawValue.values.lazy
            .reduce(function) { function, serializer in
              {
                try await serializer.run {
                  try await function()
                }
              }
            }
          try await function()
        }
      case let kind:
        // This test function has declared a single dependency, so fetch the
        // serializer for that dependency and run the test in serial with any
        // other tests that have the same dependency.
        let serializer = Self._serializers.withLock { serializers in
          serializers[kind]!
        }
        try await serializer.run {
          try await function()
        }
      }
    }
#else
    try await Configuration.withCurrent(configuration, perform: function)
#endif
  }
}

// MARK: -

extension Trait where Self == ParallelizationTrait {
  /// A trait that serializes the test to which it is applied.
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  public static var serialized: Self {
    Self()
  }
}

#if !hasFeature(Embedded)
@_spi(Experimental)
extension Trait where Self == ParallelizationTrait {
  /// Constructs a trait that describes a dependency on a Swift type.
  ///
  /// - Parameters:
  ///   - type: The type of interest.
  ///
  /// - Returns: An instance of ``ParallelizationTrait`` that adds a dependency
  ///   on `type` to any test it is applied to.
  ///
  /// Use this trait when you write a test function is dependent on global
  /// mutable state contained within `type`:
  ///
  /// ```swift
  /// import Foundation
  ///
  /// @Test(.serialized(for: ProcessInfo.self))
  /// func `HAS_FREEZER environment variable`() {
  ///   _ = setenv("HAS_FREEZER", "1", 1)
  ///   #expect(FoodTruck.hasFreezer)
  ///   _ = setenv("HAS_FREEZER", "0", 1)
  ///   #expect(!FoodTruck.hasFreezer)
  /// }
  /// ```
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  public static func serialized<T>(for type: T.Type) -> Self {
    var isEnvironment = false
#if canImport(Foundation)
    var processInfoClass: AnyClass?
#if _runtime(_ObjC)
    processInfoClass = objc_getClass("NSProcessInfo") as? AnyClass
#else
    processInfoClass = _typeByName("20FoundationEssentials11ProcessInfoC") as? AnyClass
#endif
    if let type = type as? AnyClass, let processInfoClass, isClass(type, subclassOf: processInfoClass) {
      // Assume that all accesses to `ProcessInfo` are accessing the environment
      // block (as the only mutable state it contains.)
      isEnvironment = true
    }
#endif
#if DEBUG
    isEnvironment = isEnvironment || type == Environment.self
#endif

    if isEnvironment {
      return Self(dependency: .init(kind: .environ))
    } else {
      return Self(dependency: .init(kind: .keyPath(\T.self)))
    }
  }

  /// Constructs a trait that describes a dependency on an address in memory.
  ///
  /// - Parameters:
  ///   - address: The address of the dependency.
  ///
  /// - Returns: An instance of ``ParallelizationTrait`` that adds a dependency
  ///   on `address` to any test it is applied to.
  ///
  /// Use this trait when you write a test function is dependent on global
  /// mutable state that must be accessed using an unsafe pointer:
  ///
  /// ```swift
  /// import Darwin
  ///
  /// @Test(.serialized(for: environ))
  /// func `HAS_FREEZER environment variable`() {
  ///   _ = setenv("HAS_FREEZER", "1", 1)
  ///   #expect(FoodTruck.hasFreezer)
  ///   _ = setenv("HAS_FREEZER", "0", 1)
  ///   #expect(!FoodTruck.hasFreezer)
  /// }
  /// ```
  ///
  /// - Note: When compiling with [strict memory safety checking](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/memorysafety/)
  ///   enabled, you must use the `unsafe` keyword when adding a dependency on
  ///   an address in memory.
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  @unsafe public static func serialized(@_nonEphemeral for address: UnsafeMutableRawPointer) -> Self {
    var isEnvironment = false
    if let environ = Environment.unsafeAddress, address == environ {
      isEnvironment = true
    }
#if !SWT_NO_ENVIRONMENT_VARIABLES && SWT_TARGET_OS_APPLE
    isEnvironment = isEnvironment || address == _NSGetEnviron()
#endif
    if isEnvironment {
      return Self(dependency: .init(kind: .environ))
    } else {
      return Self(dependency: .init(kind: .address(UnsafeMutableRawPointer(address))))
    }
  }

  @available(*, unavailable, message: "Pointers passed to 'serialized(for:)' must be mutable")
  @_documentation(visibility: private)
  @unsafe public static func serialized(@_nonEphemeral for address: UnsafeRawPointer) -> Self {
    swt_unreachable()
  }

  /// Constructs a trait that describes a dependency on a tag.
  ///
  /// - Parameters:
  ///   - tag: The tag representing the dependency.
  ///
  /// - Returns: An instance of ``ParallelizationTrait`` that adds a dependency
  ///   on `tag` to any test it is applied to.
  ///
  /// Use this trait when you write a test function is dependent on global
  /// mutable state and you want to track that state using a tag:
  ///
  /// ```swift
  /// import Foundation
  ///
  /// extension Tag {
  ///   @Tag static var freezer: Self
  /// }
  ///
  /// @Test(.serialized(for: .freezer))
  /// func `Freezer door works`() {
  ///   let freezer = FoodTruck.shared.freezer
  ///   freezer.openDoor()
  ///   #expect(freezer.isOpen)
  ///   freezer.closeDoor()
  ///   #expect(!freezer.isOpen)
  /// }
  /// ```
  ///
  /// - Note: If you add `tag` to a test using the ``Trait/tags(_:)`` trait,
  ///   that test does not automatically become serialized.
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  /// - ``Tag``
  public static func serialized(for tag: Tag) -> Self {
    Self(dependency: .init(kind: .tag(tag)))
  }
}
#endif

#if !hasFeature(Embedded)
// MARK: - Unbounded dependencies (*)

@_spi(Experimental)
extension ParallelizationTrait.Dependency {
  /// A dependency.
  ///
  /// An unbounded dependency is a dependency on the complete state of the
  /// current process. To specify an unbounded dependency when using
  /// ``Trait/serialized(for:)-(Self.Unbounded)``, pass a reference
  /// to this function:
  ///
  /// ```swift
  /// @Test(.serialized(for: *))
  /// func `All food truck environment variables`() { ... }
  /// ```
  ///
  /// If a test has more than one dependency, the testing library automatically
  /// treats it as if it is dependent on the program's complete state.
  @_documentation(visibility: private)
  public static func *(_: Self, _: Never) {}

  /// A type describing unbounded dependencies.
  ///
  /// An unbounded dependency is a dependency on the complete state of the
  /// current process. To specify an unbounded dependency when using
  /// ``Trait/serialized(for:)-(Self.Dependency.Unbounded)``, pass a reference
  /// to the `*` operator:
  ///
  /// ```swift
  /// @Test(.serialized(for: *))
  /// func `All food truck environment variables`() { ... }
  /// ```
  ///
  /// If a test has more than one dependency, the testing library automatically
  /// treats it as if it is dependent on the program's complete state.
  public typealias Unbounded = (Self, Never) -> Void
}

@_spi(Experimental)
extension Trait where Self == ParallelizationTrait {
  /// Constructs a trait that describes a dependency on the complete state of
  /// the current process.
  ///
  /// - Returns: An instance of ``ParallelizationTrait`` that adds a dependency
  ///   on the complete state of the current process to any test it is applied
  ///   to.
  ///
  /// Pass `*` to this trait when you write a test function is dependent on
  /// global mutable state in the current process that cannot be fully described
  /// or that isn't known at compile time:
  ///
  /// ```swift
  /// @Test(.serialized(for: *))
  /// func `All food truck environment variables`() { ... }
  /// ```
  ///
  /// If a test has more than one dependency, the testing library automatically
  /// treats it as if it is dependent on the program's complete state.
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  public static func serialized(for _: Self.Dependency.Unbounded) -> Self {
    Self(dependency: .init(kind: .unbounded))
  }

  @available(*, unavailable, message: "Pass a Swift type, a pointer to mutable global state, or '*' instead")
  @_documentation(visibility: private)
  public static func serialized<T>(for _: borrowing T) -> Self where T: ~Copyable & ~Escapable {
    swt_unreachable()
  }
}
#endif
