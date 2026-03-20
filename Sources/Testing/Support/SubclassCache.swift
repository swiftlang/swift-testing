//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if _runtime(_ObjC)
private import ObjectiveC
#else
private import _TestDiscovery
#endif

/// A type that contains a cache of classes and their known subclasses.
///
/// - Note: In general, this type is not able to dynamically discover generic
///   classes that are subclasses of a given class.
struct SubclassCache {
#if !_runtime(_ObjC)
  /// A dictionary keyed by classes whose values are arrays of all known
  /// subclasses of those classes.
  ///
  /// This dictionary is constructed in reverse by walking all known classes in
  /// the current process and recursively querying each one for its immediate
  /// superclass. This is less efficient than the Objective-C-based
  /// implementation (which can avoid realizing classes that aren't of
  /// interest to us).
  private static let _allSubclasses: [TypeInfo: [AnyClass]] = {
    var result = [TypeInfo: [AnyClass]]()

    for clazz in allClasses() {
      let superclasses = sequence(first: clazz, next: _getSuperclass).dropFirst()
      for superclass in superclasses {
        let typeInfo = TypeInfo(describing: superclass)
        result[typeInfo, default: []].append(clazz)
      }
    }

    return result
  }()
#endif

  /// An entry in the subclass cache.
  private struct _CacheEntry {
    /// Whether or not the represented type belongs in the cache.
    var inCache: Bool

    /// The set of known subclasses for this entry, if cached.
    var subclasses: [AnyClass]?
  }

  /// The set of cached information, keyed by type (class).
  ///
  /// Negative entries (`inCache = false`) indicate that a type is known _not_
  /// to be contained in this cache (after considering superclasses and
  /// subclasses).
  private var _cache: [TypeInfo: _CacheEntry]

  /// Initialize an instance of this type to provide information for the given
  /// set of base classes.
  ///
  /// - Parameters:
  ///   - baseClasses: The set of base classes for which this instance will
  ///     cache information.
  init(_ baseClasses: some Sequence<AnyClass>) {
    let baseClasses = Set(baseClasses.lazy.map { TypeInfo(describing: $0) })
    _cache = Dictionary(uniqueKeysWithValues: baseClasses.lazy.map { ($0, _CacheEntry(inCache: true)) })
  }

  /// Look up the given type in the cache.
  ///
  /// - Parameters:
  ///   - typeInfo: The type to look up.
  ///
  /// - Returns: Whether or not the given type is contained in this cache.
  ///
  /// If `typeInfo` represents a class, and one of that class' superclasses is
  /// contained in this cache, then that class is _also_ considered to be
  /// contained in the cache.
  private mutating func _find(_ typeInfo: TypeInfo) -> _CacheEntry? {
    if let cached = _cache[typeInfo] {
      return cached.inCache ? cached : nil
    }

    var superclassFound = false
    if let clazz = typeInfo.class, let superclass = _getSuperclass(clazz) {
      superclassFound = _find(TypeInfo(describing: superclass)) != nil
    }
    let result = _CacheEntry(inCache: superclassFound)
    _cache[typeInfo] = result
    return result
  }

  /// Check whether or not a given class is contained in this cache.
  ///
  /// - Parameters:
  ///   - clazz: The class to look up.
  ///
  /// - Returns: Whether or not the given class is contained in this cache.
  ///
  /// If one of the superclasses of `clazz` is contained in this cache, then
  /// `clazz` is _also_ considered to be contained in the cache.
  mutating func contains(_ clazz: AnyClass) -> Bool {
    _find(TypeInfo(describing: clazz)) != nil
  }

  /// Look up all known subclasses of a given class.
  ///
  /// - Parameters:
  ///   - clazz: The base class of interest.
  ///
  /// - Returns: An array of all known subclasses of the given class.
  ///
  /// If `clazz` or a superclass thereof was not passed to ``init(_:)``, this
  /// function returns the empty array.
  mutating func subclasses(of clazz: AnyClass) -> [AnyClass] {
    let typeInfo = TypeInfo(describing: clazz)

    guard let cached = _find(typeInfo) else {
      return []
    }

    if let result = cached.subclasses {
      return result
    }
#if _runtime(_ObjC)
    let result = Array(objc_enumerateClasses(subclassing: clazz))
#else
    let result = Self._allSubclasses[typeInfo] ?? []
#endif
    _cache[typeInfo]!.subclasses = result
    return result
  }
}
