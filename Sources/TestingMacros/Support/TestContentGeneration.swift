//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax
import SwiftSyntaxMacros

/// An enumeration representing the different kinds of test content known to the
/// testing library.
///
/// When adding cases to this enumeration, be sure to also update the
/// corresponding enumeration in TestContent.md.
enum TestContentKind: UInt32 {
  /// A test or suite declaration.
  case testDeclaration = 0x74657374

  /// An exit test.
  case exitTest = 0x65786974

  /// This kind value as a comment (`/* 'abcd' */`) if it looks like it might be
  /// a [FourCC](https://en.wikipedia.org/wiki/FourCC) value, or `nil` if not.
  var commentRepresentation: Trivia? {
    return withUnsafeBytes(of: rawValue.bigEndian) { bytes in
      if bytes.allSatisfy(Unicode.ASCII.isASCII) {
        let characters = String(decoding: bytes, as: Unicode.ASCII.self)
        let allAlphanumeric = characters.allSatisfy { $0.isLetter || $0.isWholeNumber }
        if allAlphanumeric {
          return .blockComment("/* '\(characters)' */")
        }
      }
      return nil
    }
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
///   - accessorName: The Swift name of an `@convention(c)` function to emit
///     into the resulting record.
///   - context: A value to emit as the `context` field of the test content
///     record.
///
/// - Returns: A variable declaration that, when emitted into Swift source, will
///   cause the linker to emit data in a location that is discoverable at
///   runtime.
func makeTestContentRecordDecl(named name: TokenSyntax, in typeName: TypeSyntax? = nil, ofKind kind: TestContentKind, accessingWith accessorName: TokenSyntax, context: UInt32 = 0) -> DeclSyntax {
  let kindExpr = IntegerLiteralExprSyntax(kind.rawValue, radix: .hex)
  let kindComment = kind.commentRepresentation.map { .space + $0 } ?? Trivia()
  let contextExpr = if context == 0 {
    IntegerLiteralExprSyntax(0)
  } else {
    IntegerLiteralExprSyntax(context, radix: .binary)
  }

  return """
  #if hasFeature(SymbolLinkageMarkers)
  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
  @_section("__DATA_CONST,__swift5_tests")
  #elseif os(Linux) || os(FreeBSD) || os(Android) || os(WASI)
  @_section("swift5_tests")
  #elseif os(Windows)
  @_section(".sw5test$B")
  #else
  @__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
  #endif
  @_used
  @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
  private \(staticKeyword(for: typeName)) let \(name): Testing.__TestContentRecord = (
    \(kindExpr),\(kindComment)
    0,
    0,
    \(accessorName),
    \(contextExpr),
    0
  )
  #endif
  """
}