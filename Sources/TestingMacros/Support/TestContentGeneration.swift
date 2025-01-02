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
enum TestContentKind: Int32 {
  /// A test or suite declaration.
  case testDeclaration = 100

  /// An exit test.
  case exitTest = 101
}

/// The value of the implicit `n_name` field of ``SWTTestContentHeader`` for
/// all recognized test content records.
///
/// This value must match the value of `_testContentHeaderName` in
/// Discovery.swift.
private let _testContentHeaderName = "Swift Testing"

/// The value of the implicit `n_name` field of ``SWTTestContentHeader`` for
/// all recognized test content records, as a sequence of C characters.
///
/// This value includes one or more trailing null characters.
private let _testContentHeaderNameCChars: [CChar] = {
  // The size of the note name field. This value must be a multiple of the size
  // of a pointer (on the target) plus four to ensure correct alignment.
  let count = 20
  assert((count - 4) % MemoryLayout<UInt64>.stride == 0, "Swift Testing note name length must be a multiple of pointer size +4")

  // Convert the constant name to UTF-8.
  var name = _testContentHeaderName.utf8.map { CChar(bitPattern: $0) }
  assert(count > name.count, "Insufficient space for Swift Testing note name")

  // Pad out to the correct length with zero bytes.
  name += repeatElement(0, count: count - name.count)

  return name
}()

/// The value of the implicit `n_name` field of ``SWTTestContentHeader`` for
/// all recognized test content records, as a tuple expression and its
/// corresponding type.
private var _testContentHeaderNameTuple: (expression: TupleExprSyntax, type: TupleTypeSyntax) {
  let name = _testContentHeaderNameCChars

  return (
    TupleExprSyntax {
      for c in name {
        LabeledExprSyntax(expression: IntegerLiteralExprSyntax(Int(c)))
      }
    },
    TupleTypeSyntax(
      elements: TupleTypeElementListSyntax {
        repeatElement(
          TupleTypeElementSyntax(
            type: MemberTypeSyntax(
              baseType: IdentifierTypeSyntax(name: .identifier("Swift")),
              name: .identifier("CChar")
            )
          ),
          count: name.count
        )
      }
    )
  )
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
///   - kind: The kind of note being emitted.
///   - accessorName: The Swift name of an `@convention(c)` function to emit
///     into the resulting record.
///   - flags: Flags to emit as part of this note. The value of this argument is
///     dependent on the kind of test content this instance represents.
///
/// - Returns: A variable declaration that, when emitted into Swift source, will
///   cause the linker to emit data in a location that is discoverable at
///   runtime.
func makeTestContentRecordDecl(named name: TokenSyntax, in typeName: TypeSyntax? = nil, ofKind kind: TestContentKind, accessingWith accessorName: TokenSyntax, flags: UInt32 = 0) -> DeclSyntax {
  let (testContentHeaderNameExpr, testContentHeaderNameType) = _testContentHeaderNameTuple
  return """
  #if hasFeature(SymbolLinkageMarkers)
  #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
  @_section("__DATA_CONST,__swift5_tests")
  #elseif os(Linux) || os(FreeBSD) || os(Android)
  @_section(".note.swift5.test")
  #elseif os(WASI)
  @_section("swift5_tests")
  #elseif os(Windows)
  @_section(".sw5test$B")
  #else
  @__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
  #endif
  @_used
  @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
  private \(staticKeyword(for: typeName)) let \(name): (
    namesz: Swift.Int32,
    descsz: Swift.Int32,
    type: Swift.Int32,
    name: \(testContentHeaderNameType),
    accessor: @convention(c) (Swift.UnsafeMutableRawPointer, Swift.UnsafeRawPointer?) -> Swift.Bool,
    flags: Swift.UInt32,
    reserved: Swift.UInt32
  ) = (
    \(literal: _testContentHeaderNameCChars.count),
    Swift.Int32(Swift.MemoryLayout<Swift.UnsafeRawPointer>.stride + Swift.MemoryLayout<Swift.UInt32>.stride + Swift.MemoryLayout<Swift.UInt32>.stride),
    \(literal: kind.rawValue),
    \(testContentHeaderNameExpr), /* \(literal: _testContentHeaderName) */
    \(accessorName),
    \(literal: flags),
    0
  )
  #endif
  """
}
