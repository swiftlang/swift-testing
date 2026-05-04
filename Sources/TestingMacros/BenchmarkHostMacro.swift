//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftDiagnostics
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

/// A type describing the expansion of the `@BenchmarkHost` attribute macro.
///
/// This type is used to implement the `@BenchmarkHost` attribute macro. Do not
/// use it directly.
public struct BenchmarkHostMacro: Sendable {
  /// Diagnose issues with a declaration this macro is attached to.
  ///
  /// - Parameters:
  ///   - declaration: The declaration to diagnose.
  ///   - node: The `@BenchmarkHost` attribute applied to `declaration`.
  ///   - context: The macro context in which the declaration is being parsed.
  ///
  /// - Returns: Whether or not macro expansion should continue.
  fileprivate static func diagnoseIssues(
    with declaration: some DeclGroupSyntax,
    attribute node: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> Bool {
    if declaration.is(ExtensionDeclSyntax.self) || declaration.is(ProtocolDeclSyntax.self) {
      context.diagnose(
        DiagnosticMessage(
          syntax: Syntax(node),
          message: "Attribute 'Benchmark.Host' cannot be applied to this declaration; apply it to the type that conforms to 'Benchmark.Host'",
          severity: .error
        )
      )
      return false
    }

    // A benchmark host is instantiated by a C function pointer that takes no
    // arguments, so its type cannot be generic.
    if let generics = declaration.asProtocol((any WithGenericParametersSyntax).self)?.genericParameterClause {
      context.diagnose(
        DiagnosticMessage(
          syntax: Syntax(generics),
          message: "Attribute 'Benchmark.Host' cannot be applied to a generic type",
          severity: .error
        )
      )
      return false
    }

    return true
  }
}

// MARK: - ExtensionMacro

extension BenchmarkHostMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard diagnoseIssues(with: declaration, attribute: node, in: context) else {
      return []
    }

    // If the declaration already states the conformance, `protocols` is empty and
    // there is nothing to add.
    guard !protocols.isEmpty else {
      return []
    }

    return [
      try ExtensionDeclSyntax("extension \(type.trimmed): Testing.Benchmark.Host {}")
    ]
  }
}

// MARK: - MemberMacro

extension BenchmarkHostMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard diagnoseIssues(with: declaration, attribute: node, in: context) else {
      return []
    }

    // A placeholder type name is sufficient here: it only tells
    // makeTestContentRecordDecl() that the record is a member of a type and so
    // needs the `static` keyword.
    let containingType = TypeSyntax(IdentifierTypeSyntax(name: .keyword(.Self)))

    return [
      makeTestContentRecordDecl(
        named: .identifier("__benchmarkHostRecord"),
        in: containingType,
        ofKind: .benchmarkHost,
        accessingWith: """
        { outValue, type, _, _ in
            Testing.Benchmark.HostRegistration.store(Self(), into: outValue, asTypeAt: type)
        }
        """,
        context: benchmarkHostABIVersion,
        in: context
      )
    ]
  }

  public static var formatMode: FormatMode {
    .disabled
  }
}

/// The value stored in the `context` field of a benchmark host test content
/// record.
///
/// - Note: Keep this value in sync with
///   `Testing.Benchmark.HostRegistration.currentABIVersion`.
private let benchmarkHostABIVersion: UInt32 = 1
