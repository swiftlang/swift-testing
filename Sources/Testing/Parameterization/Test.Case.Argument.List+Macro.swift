//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test.Case {
  /// A type representing a sequence of arguments passed to a test function.
  ///
  /// An argument list's underlying sequence _must_ be iterable multiple times.
  /// Hence, ``Test``'s factory functions accept only _collections_, not
  /// sequences. The constraint here is only to `Sequence` to allow the storage
  /// of computed sequences over collections (such as `CartesianProduct` or
  /// `Zip2Sequence`) that are safe to iterate multiple times.
  ///
  /// - Warning: This type is used to implement the `@Test` macro. Do not use it
  ///   directly.
  public struct __ArgumentList<S>: Sendable where S: Sendable & Sequence, S.Element: Sendable {
    /// The underlying sequence of arguments passed to the test.
    var sequence: S

    /// A function that transforms an element of `sequence` to zero or more
    /// instances of ``Test/Case/Argument/Value``.
    ///
    /// - Parameters:
    ///   - element: The element to transform.
    ///
    /// - Returns: An array of values corresponding to `element`. The array's
    ///   count depends on the number of parameters to the test function.
    var makeArgumentValues: @Sendable (_ element: S.Element) -> [Test.Case.Argument.Value]

    init(_ sequence: S, makingArgumentValuesWith makeArgumentValues: @escaping @Sendable (_ element: S.Element) -> [Test.Case.Argument.Value]) {
      self.sequence = sequence
      self.makeArgumentValues = makeArgumentValues
    }
  }
}

// MARK: -

/// Make an argument list from the given sequence of arguments.
///
/// - Parameters:
///   - arguments: The sequence of arguments. In most cases, this type also
///     conforms to ``Collection``.
///   - parameterCount: The number of parameters passed to the test function.
///
/// - Returns: An argument list.
///
/// - Warning: This function is used to implement the `@Test` macro. Do not use
///   it directly.
@_disfavoredOverload
public func __makeArgumentList<S>(_ arguments: S, parameterCount: Int = 1) -> Test.Case.__ArgumentList<S> {
  Test.Case.__ArgumentList(arguments) { element in
    var testDescription: String?
#if !hasFeature(Embedded)
    var mirror: Mirror?
    if parameterCount > 1 {
      mirror = Mirror(reflectingForTest: element)
      if let mirror, mirror.displayStyle == .tuple {
        return mirror.children.lazy
          .map { unsafeBitCast($0.value, to: (any Sendable).self) }
          .map { Test.Case.Argument.Value($0) }
      }
    }

    // The value did not appear to be a tuple or we didn't need to split the
    // element. If we created a mirror above, we can reuse it here.
    if mirror?.displayStyle == .tuple {
      testDescription = String(describingForTest: element, reflectedBy: mirror)
    }
#else
    // We can't break down the tuple in Embedded Swift, but we can at
    // least present the correct number of arguments.
    if parameterCount > 1 {
      let unavailable = Test.Case.Argument.Value(UnavailableInEmbeddedSwift())
      return Array(repeatElement(unavailable, count: parameterCount))
    }
#endif
    return [Test.Case.Argument.Value(element, testDescription: testDescription)]
  }
}

/// Make an argument list from the given sequence of arguments.
///
/// - Parameters:
///   - arguments: The sequence of arguments. In most cases, this type also
///     conforms to ``Collection``.
///   - parameterCount: The number of parameters passed to the test function.
///
/// - Returns: An argument list.
///
/// This overload is specialized for collections of 2-tuples to efficiently
/// de-structure their elements when appropriate.
///
/// - Warning: This function is used to implement the `@Test` macro. Do not use
///   it directly.
public func __makeArgumentList<S, E1, E2>(_ arguments: S, parameterCount: Int = 1) -> Test.Case.__ArgumentList<S> where S.Element == (E1, E2) {
  Test.Case.__ArgumentList(arguments) { element in
    if parameterCount > 1 {
      return [Test.Case.Argument.Value(element.0), Test.Case.Argument.Value(element.1)]
    } else {
#if !hasFeature(Embedded)
      let testDescription = "(\(String(describingForTest: element.0)), \(String(describingForTest: element.1)))"
#else
      let testDescription = "(\(UnavailableInEmbeddedSwift.testDescription), \(UnavailableInEmbeddedSwift.testDescription))"
#endif
      return [Test.Case.Argument.Value(element, testDescription: testDescription)]
    }
  }
}

/// Make an argument list from the given sequence of arguments.
///
/// - Parameters:
///   - arguments: The sequence of arguments. In most cases, this type also
///     conforms to ``Collection``.
///   - parameterCount: The number of parameters passed to the test function.
///
/// - Returns: An argument list.
///
/// This overload is specialized for dictionary-like collections to efficiently
/// de-structure their elements (which are known to be 2-tuples) when
/// appropriate. This overload is distinct from those for other collections of
/// 2-tuples because the `Element` tuple type for these kinds of collections
/// includes labels (`(key: Key, value: Value)`).
///
/// - Warning: This function is used to implement the `@Test` macro. Do not use
///   it directly.
public func __makeArgumentList<S, K, V>(_ arguments: S, parameterCount: Int = 1) -> Test.Case.__ArgumentList<S> where S: ExpressibleByDictionaryLiteral, S.Element == (key: K, value: V) {
  Test.Case.__ArgumentList(arguments) { element in
    if parameterCount > 1 {
      return [Test.Case.Argument.Value(element.key), Test.Case.Argument.Value(element.value)]
    } else {
#if !hasFeature(Embedded)
      let testDescription = "(key: \(String(describingForTest: element.key)), value: \(String(describingForTest: element.value)))"
#else
      let testDescription = "(key: \(UnavailableInEmbeddedSwift.testDescription), value: \(UnavailableInEmbeddedSwift.testDescription))"
#endif
      return [Test.Case.Argument.Value(element, testDescription: testDescription)]
    }
  }
}

#if hasFeature(Embedded)
public func __makeArgumentList<S>(_ arguments: S, parameterCount: Int = 1) -> Test.Case.__ArgumentList<S> where S.Element: CustomTestStringConvertible {
  Test.Case.__ArgumentList(arguments) { element in
    // We can't break down the tuple in Embedded Swift, but we can at
    // least present the correct number of arguments.
    if parameterCount > 1 {
      let unavailable = Test.Case.Argument.Value(UnavailableInEmbeddedSwift())
      return Array(repeatElement(unavailable, count: parameterCount))
    }
    return [Test.Case.Argument.Value(element)]
  }
}

public func __makeArgumentList<S, E1, E2>(_ arguments: S, parameterCount: Int = 1) -> Test.Case.__ArgumentList<S> where S.Element == (E1, E2), E1: CustomTestStringConvertible, E2: CustomTestStringConvertible {
  Test.Case.__ArgumentList(arguments) { element in
    if parameterCount > 1 {
      return [Test.Case.Argument.Value(element.0), Test.Case.Argument.Value(element.1)]
    } else {
      let testDescription = "(\(String(describingForTest: element.0)), \(String(describingForTest: element.1)))"
      return [Test.Case.Argument.Value(element, testDescription: testDescription)]
    }
  }
}

public func __makeArgumentList<S, K, V>(_ arguments: S, parameterCount: Int = 1) -> Test.Case.__ArgumentList<S> where S: ExpressibleByDictionaryLiteral, S.Element == (key: K, value: V), K: CustomTestStringConvertible, V: CustomTestStringConvertible {
  Test.Case.__ArgumentList(arguments) { element in
    if parameterCount > 1 {
      return [Test.Case.Argument.Value(element.key), Test.Case.Argument.Value(element.value)]
    } else {
      let testDescription = "(key: \(String(describingForTest: element.key)), value: \(String(describingForTest: element.value)))"
      return [Test.Case.Argument.Value(element, testDescription: testDescription)]
    }
  }
}
#endif
