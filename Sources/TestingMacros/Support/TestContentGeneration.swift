//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftIfConfig
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension TestContentKind {
  /// This kind value as a comment (`/* 'abcd' */`) if it looks like it might be
  /// a [FourCC](https://en.wikipedia.org/wiki/FourCC) value, or empty trivia if
  /// not.
  fileprivate var commentRepresentation: Trivia {
    guard let fourCharacterCodeValue, !fourCharacterCodeValue.contains("*/") else {
      return []
    }
    return .blockComment("/* '\(fourCharacterCodeValue)' */")
  }
}

/// Make a test content record that can be discovered at runtime by the testing
/// library.
///
/// - Parameters:
///   - name: The name of the record declaration to use in Swift source. The
///     value of this argument should be unique in the context in which the
///     declaration will be emitted.
///   - typeName: The name of the type enclosing the resulting declaration, or
///     `nil` if it will not be emitted into a type's scope.
///   - kind: The kind of test content record being emitted.
///   - accessorExpr: An expression to use as the record's accessor function.
///   - contextFieldValue: A value to emit as the `context` field of the test
///     content record.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: A variable declaration that, when emitted into Swift source, will
///   cause the linker to emit data in a location that is discoverable at
///   runtime.
func makeTestContentRecordDecl(named name: TokenSyntax, in typeName: TypeSyntax? = nil, ofKind kind: TestContentKind, accessingWith accessorExpr: ExprSyntax, context contextFieldValue: UInt32 = 0, in context: some MacroExpansionContext) -> DeclSyntax {
  let kindExpr = IntegerLiteralExprSyntax(kind.rawValue, radix: .hex)
  let contextExpr = if contextFieldValue == 0 {
    IntegerLiteralExprSyntax(0)
  } else {
    IntegerLiteralExprSyntax(contextFieldValue, radix: .binary)
  }

  var result: DeclSyntax = """
  @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
  private nonisolated \(staticKeyword(for: typeName)) let \(name): Testing.__TestContentRecord = (
    \(kindExpr), \(kind.commentRepresentation)
    0,
    \(raw: accessorExpr),
    \(contextExpr),
    0
  )
  """

  result = """
  @used
  \(result)
  """

  let objectFormatsAndSectionNames: [(objectFormat: String, sectionName: String)] = [
    ("MachO", "__DATA_CONST,__swift5_tests"),
    ("ELF", "swift5_tests"),
    ("COFF", ".sw5test$B"),
    ("Wasm", "swift5_tests"),
  ]

  if let buildConfiguration = context.buildConfiguration {
    let objectFormatAndSectionName = try? objectFormatsAndSectionNames.first { objectFormat, _ in
      try buildConfiguration.isActiveTargetObjectFormat(name: objectFormat)
    }
    if let (_, sectionName) = objectFormatAndSectionName {
      result = """
      @section(\(literal: sectionName))
      \(result)
      """
    } else {
      result = """
      @Testing.__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
      \(result)
      """
    }
  } else {
    // In practice, this path is only taken when running our macro test target.
    // SEE: https://github.com/swiftlang/swift-syntax/pull/3191
    for (objectFormat, sectionName) in objectFormatsAndSectionNames {
      result = """
      #if objectFormat(\(raw: objectFormat))
      @section(\(literal: sectionName))
      #endif
      \(result)
      """
    }
  }

  return result
}
