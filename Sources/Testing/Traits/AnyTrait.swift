//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import Synchronization

#if hasFeature(Embedded)
/// Storage for the next trait type's unique ID.
private let _nextUniqueID = Atomic<Int>(0)

extension Trait {
  /// Get the next available unique ID for a trait type.
  ///
  /// - Returns: An integer.
  ///
  /// This function is not part of the public interface of the testing library.
  /// It may be removed in a future update.
  public static func _nextUniqueID() -> Int {
    _nextUniqueID.add(1, ordering: .sequentiallyConsistent)
  }
}
#endif

/// A type that represents a type-erased trait.
struct AnyTrait: Sendable {
  private final class _Storage: Sendable {
    private nonisolated(unsafe) let _traitAddress: UnsafeRawPointer
    private let _deinit: @Sendable () -> Void
    private let _uniqueID: Int

    private init<T>(_trait trait: T, isSuiteTrait: Bool = false, isRecursive: Bool = false) where T: Trait {
      nonisolated(unsafe) let traitAddress = UnsafeMutablePointer<T>.allocate(capacity: 1)
      traitAddress.initialize(to: trait)
      self._traitAddress = .init(traitAddress)
      self._deinit = {
        traitAddress.deinitialize(count: 1)
        traitAddress.deallocate()
      }
      self._uniqueID = T._uniqueID

      self.prepare = { test in
        try await traitAddress.pointee.prepare(for: test)
      }
      self.comments = {
        traitAddress.pointee.comments
      }
      self.scopeProvider = { test, testCase in
        traitAddress.pointee
          .scopeProvider(for: test, testCase: testCase)
          .map { $0.provideScope(for:testCase:performing:) }
      }
      self.isSuiteTrait = isSuiteTrait
      self.isRecursive = isRecursive

#if !hasFeature(Embedded)
      self._asAnyTrait = { traitAddress.pointee }
#endif
    }

    convenience init<T>(_ trait: T) where T: Trait {
      self.init(_trait: trait)
    }

    convenience init<T>(_ trait: T) where T: Trait & SuiteTrait {
      self.init(_trait: trait, isSuiteTrait: true, isRecursive: trait.isRecursive)
    }

    deinit {
      _deinit()
    }

    let prepare: @Sendable (Test) async throws -> Void
    let comments: @Sendable () -> [Comment]
    let scopeProvider: @Sendable (Test, Test.Case?) -> (
      @Sendable (Test, Test.Case?, @Sendable () async throws -> Void) async throws -> Void
    )?
    let isSuiteTrait: Bool
    let isRecursive: Bool

    func `as`<T>(_ type: T.Type) -> T? where T: Trait {
      if T._uniqueID == _uniqueID {
        return _traitAddress.load(as: T.self)
      }
      return nil
    }

#if !hasFeature(Embedded)
    private let _asAnyTrait: @Sendable () -> any Trait

    func `as`(_: (any Trait).Type) -> any Trait {
      _asAnyTrait()
    }
#endif
  }

  private var _storage: _Storage

  init(_ trait: some Trait) {
    _storage = _Storage(trait)
  }

  init(_ trait: some SuiteTrait) {
    _storage = _Storage(trait)
  }

  func `as`<T>(_ type: T.Type) -> T? where T: Trait {
    _storage.as(type)
  }

#if !hasFeature(Embedded)
  func `as`(_ type: (any Trait).Type) -> any Trait {
    _storage.as(type)
  }
#endif
}

// MARK: - Trait, TestTrait, SuiteTrait

extension AnyTrait: Trait, TestTrait, SuiteTrait {
  func prepare(for test: Test) async throws {
    try await _storage.prepare(test)
  }

  var comments: [Comment] {
    _storage.comments()
  }

  struct TestScopeProvider: TestScoping {
    var scopeProvider: @Sendable (Test, Test.Case?, @Sendable () async throws -> Void) async throws -> Void

    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
      try await scopeProvider(test, testCase, function)
    }
  }

  func scopeProvider(for test: Test, testCase: Test.Case?) -> TestScopeProvider? {
    _storage.scopeProvider(test, testCase).map(TestScopeProvider.init(scopeProvider:))
  }

  var isSuiteTrait: Bool {
    _storage.isSuiteTrait
  }

  var isRecursive: Bool {
    _storage.isRecursive
  }
}

// MARK: -

extension Array where Element == AnyTrait {
  init<each T>(_ traits: repeat each T) where repeat each T: Trait {
    self = []
    for trait in repeat each traits {
      self.append(AnyTrait(trait))
    }
  }

  init<each T>(_ traits: repeat each T) where repeat each T: SuiteTrait {
    self = []
    for trait in repeat each traits {
      self.append(AnyTrait(trait))
    }
  }
}
