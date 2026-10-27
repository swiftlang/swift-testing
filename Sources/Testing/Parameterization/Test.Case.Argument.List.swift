//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test.Case.Argument {
  /// A type representing a sequence of arguments passed to a test function.
  ///
  /// This type is declared as a type alias rather than a structure because it
  /// has the same shape as `__ArgumentList` but that type must be public and is
  /// not part of the testing library's public interface. This name is preferred
  /// outside macro expansion support code.
  typealias List<S> = Test.Case.__ArgumentList<S> where S: Sendable & Sequence, S.Element: Sendable
}
