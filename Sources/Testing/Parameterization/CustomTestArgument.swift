//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol for customizing how arguments passed to parameterized tests are
/// represented.
@_spi(ExperimentalParameterizedTesting)
public protocol CustomTestArgument: Sendable {
  /// Get the ID of this test argument, using the provided context.
  ///
  /// - Parameters:
  ///   - context: Context about this argument which may be useful in forming
  ///     its ID.
  ///
  /// - Returns: The ID of this test argument scoped to the provided context
  ///
  /// The ID of a test argument should be stable and unique in order to allow
  /// re-running specific test cases of a parameterized test function. It does
  /// not need to be human-readable.
  ///
  /// By default, the testing library derives an ID for a test argument using
  /// `String(describing:)`. The resulting string may not be stable or unique.
  /// If the type of the argument conforms to `Identifiable` and its associated
  /// `ID` type is `String`, the value of calling its `id` property is used
  /// instead.
  ///
  /// It is possible that neither of the approaches for obtaining an ID detailed
  /// above provide sufficient stability or uniqueness. If the type of the
  /// argument is made to conform to ``CustomTestArgument``, then the ID
  /// returned by this method is used.
  func argumentID(in context: Test.Case.Argument.Context) -> String
}

extension String {
  /// Initialize this instance with an ID for the specified test argument.
  ///
  /// - Parameters:
  ///   - value: The value of a test argument for which to get an ID.
  ///   - context: The context in which the argument was passed.
  ///
  /// This function is not part of the public interface of the testing library.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestArgument``
  init(identifyingTestArgument argument: some Sendable, in context: Test.Case.Argument.Context) {
    self = if let argument = argument as? any CustomTestArgument {
      argument.argumentID(in: context)
    } else if let argument = argument as? any Identifiable, let id = argument.id as? String {
      id
    } else {
      String(describing: argument)
    }
  }
}

// MARK: - Argument context

extension Test.Case.Argument {
  /// A type describing the context in which an argument was passed to a
  /// parameterized test function.
  public struct Context: Sendable {
    /// The parameter of the test function to which this instance's associated
    /// argument was passed.
    public var parameter: Test.ParameterInfo
  }
}
