//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if compiler(>=5.11)
import SwiftSyntax
import SwiftSyntaxMacros
#else
public import SwiftSyntax
public import SwiftSyntaxMacros
#endif
import SwiftDiagnostics

extension MacroExpansionContext {
  /// Get the type of the lexical context enclosing the given node.
  ///
  /// - Parameters:
  ///   - node: The node whose lexical context should be examined.
  ///
  /// - Returns: The type of the lexical context enclosing `node`, or `nil` if
  ///   the lexical context cannot be represented as a type.
  ///
  /// If the lexical context includes functions, closures, or some other
  /// non-type scope, the value of this property is `nil`.
  ///
  /// If swift-syntax-600 or newer is available, `node` is ignored. The argument
  /// will be removed once the testing library's swift-syntax dependency is
  /// updated to swift-syntax-600 or later.
  func typeOfLexicalContext(containing node: some WithAttributesSyntax) -> TypeSyntax? {
#if canImport(SwiftSyntax600)
    var typeNames = [String]()
    for lexicalContext in lexicalContext.reversed() {
      guard let decl = lexicalContext.asProtocol((any DeclGroupSyntax).self) else {
        return nil
      }
      typeNames.append(decl.type.trimmedDescription)
    }
    if typeNames.isEmpty {
      return nil
    }

    return "\(raw: typeNames.joined(separator: "."))"
#else
    // Find the beginning of the first attribute on the declaration, including
    // those embedded in #if statements, to account for patterns like
    // `@MainActor @Test func` where there's a space ahead of @Test, but the
    // whole function is still at the top level.
    func firstAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
      attributes.lazy
        .compactMap { attribute in
          switch (attribute as AttributeListSyntax.Element?) {
          case let .ifConfigDecl(ifConfigDecl):
            ifConfigDecl.clauses.lazy
              .compactMap { clause in
                if case let .attributes(attributes) = clause.elements {
                  return firstAttribute(in: attributes)
                }
                return nil
              }.first
          case let .attribute(attribute):
            attribute
          default:
            nil
          }
        }.first
    }
    let firstAttribute = firstAttribute(in: node.attributes)!

    // HACK: If the test function appears to be indented, assume it is nested in
    // a type. Use `Self` as the presumptive name of the type.
    //
    // This hack works around rdar://105470382.
    if let lastLeadingTrivia = firstAttribute.leadingTrivia.pieces.last,
       lastLeadingTrivia.isWhitespace && !lastLeadingTrivia.isNewline {
      return TypeSyntax(IdentifierTypeSyntax(name: .keyword(.Self)))
    }
    return nil
#endif
  }
}

// MARK: -

extension MacroExpansionContext {
  /// Create a unique name for a function that thunks another function.
  ///
  /// - Parameters:
  ///   - functionDecl: The function to thunk.
  ///   - prefix: A prefix to apply to the thunked name before returning.
  ///
  /// - Returns: A unique name to use for a thunk function that thunks
  ///   `functionDecl`.
  func makeUniqueName(thunking functionDecl: FunctionDeclSyntax, withPrefix prefix: String = "") -> TokenSyntax {
    // Find all the tokens of the function declaration including argument
    // types, specifiers, etc. (but not any attributes nor the body of the
    // function.) Use them as the base name we pass to makeUniqueName(). This
    // ensures that we will end up with a unique identifier even if two
    // functions in the same scope have the exact same identifier.
    let identifierCharacters = functionDecl
      .with(\.attributes, [])
      .with(\.body, nil)
      .tokens(viewMode: .fixedUp)
      .map(\.textWithoutBackticks)
      .joined()

    // Strip out any characters in the function's signature that won't play well
    // in a generated symbol name.
    let identifier = String(
      identifierCharacters.map { character in
        if character.isLetter || character.isWholeNumber {
          return character
        }
        return "_"
      }
    )

    // If there is a non-ASCII character in the identifier, we might be
    // stripping it out above because we are only looking for letters and
    // digits. If so, add in a hash of the identifier to improve entropy and
    // reduce the risk of a collision.
    //
    // For example, the following function names will produce identical unique
    // names without this mutation:
    //
    // @Test(arguments: [0]) func A(🙃: Int) {}
    // @Test(arguments: [0]) func A(🙂: Int) {}
    //
    // Note the check here is not the same as the one above: punctuation like
    // "(" should be replaced, but should not cause a hash to be emitted since
    // it does not contribute any entropy to the makeUniqueName() algorithm.
    //
    // The intent here is not to produce a cryptographically strong hash, but to
    // disambiguate between superficially similar function names. A collision
    // may still occur, but we only need it to be _unlikely_. CRC-32 is good
    // enough for our purposes.
    if !identifierCharacters.allSatisfy(\.isASCII) {
      let crcValue = crc32(identifierCharacters.utf8)
      let suffix = String(crcValue, radix: 16, uppercase: false)
      return makeUniqueName("\(prefix)\(identifier)_\(suffix)")
    }

    return makeUniqueName("\(prefix)\(identifier)")
  }
}

// MARK: -

extension MacroExpansionContext {
  /// Emit a diagnostic message.
  ///
  /// - Parameters:
  ///   - message: The diagnostic message to emit. The `node` and `position`
  ///     arguments to `Diagnostic.init()` are derived from the message's
  ///     `syntax` property.
  func diagnose(_ message: DiagnosticMessage) {
    diagnose(
      Diagnostic(
        node: message.syntax,
        position: message.syntax.positionAfterSkippingLeadingTrivia,
        message: message,
        fixIts: message.fixIts
      )
    )
  }

  /// Emit a sequence of diagnostic messages.
  ///
  /// - Parameters:
  ///   - messages: The diagnostic messages to emit.
  func diagnose(_ messages: some Sequence<DiagnosticMessage>) {
    for message in messages {
      diagnose(message)
    }
  }

  /// Emit a diagnostic message for debugging purposes during development of the
  /// testing library.
  ///
  /// - Parameters:
  ///   - message: The message to emit into the build log.
  func debug(_ message: some Any, node: some SyntaxProtocol) {
    diagnose(DiagnosticMessage(syntax: Syntax(node), message: String(describing: message), severity: .warning))
  }
}
