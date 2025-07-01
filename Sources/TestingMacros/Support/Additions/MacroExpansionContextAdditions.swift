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
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

extension MacroExpansionContext {
  /// Get the type of the given lexical context.
  ///
  /// - Parameters:
  ///   - lexicalContext: The lexical context.
  ///
  /// - Returns: The type represented by `lexicalContext`, or `nil` if one could
  ///   not be derived (for example, because the lexical context inclues a
  ///   function, closure, or some other non-type scope.)
  ///
  /// If the lexical context includes functions, closures, or some other
  /// non-type scope, the value of this property is `nil`.
  func type(ofLexicalContext lexicalContext: some RandomAccessCollection<Syntax>) -> TypeSyntax? {
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
  }

  /// The type of the lexical context enclosing the given node.
  ///
  /// If the lexical context includes functions, closures, or some other
  /// non-type scope, the value of this property is `nil`.
  var typeOfLexicalContext: TypeSyntax? {
    type(ofLexicalContext: lexicalContext)
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
    let hashValue = SHA256.hash(identifierCharacters.utf8).withUnsafeBytes { sha256 in
      sha256.loadUnaligned(as: UInt64.self)
    }
    let suffix = String(hashValue, radix: 16, uppercase: false)

    // If the caller did not specify a prefix and the hash value starts with a
    // digit, include a single-character prefix to ensure that Swift's name
    // demangling still works correctly.
    var prefix = prefix
    if prefix.isEmpty, let firstSuffixCharacter = suffix.first, firstSuffixCharacter.isWholeNumber {
      prefix = "Z"
    }

    // Get the source location of the function declaration for better uniqueness
    let sourceLocation = location(of: functionDecl)

    return makeUniqueName("\(prefix)\(suffix)", sourceLocation: sourceLocation)
  }
}

// MARK: -

extension MacroExpansionContext {
  /// Whether or not our generated warnings are suppressed in the current
  /// lexical context.
  ///
  /// The value of this property is `true` if the current lexical context
  /// contains a node with the `@__testing(semantics: "nowarnings")` attribute
  /// applied to it.
  ///
  /// - Warning: This functionality is not part of the public interface of the
  ///   testing library. It may be modified or removed in a future update.
  var areWarningsSuppressed: Bool {
#if DEBUG
    return lexicalContext
      .compactMap { $0.asProtocol((any WithAttributesSyntax).self) }
      .flatMap { semantics(of: $0) }
      .contains("nomacrowarnings")
#else
    return false
#endif
  }

  /// Emit a diagnostic message.
  ///
  /// - Parameters:
  ///   - message: The diagnostic message to emit. The `node` and `position`
  ///     arguments to `Diagnostic.init()` are derived from the message's
  ///     `syntax` property.
  func diagnose(_ message: DiagnosticMessage) {
    diagnose(CollectionOfOne(message))
  }

  /// Emit a sequence of diagnostic messages.
  ///
  /// - Parameters:
  ///   - messages: The diagnostic messages to emit.
  func diagnose(_ messages: some Collection<DiagnosticMessage>) {
    lazy var areWarningsSuppressed = areWarningsSuppressed
    for message in messages {
      if message.severity == .warning && areWarningsSuppressed {
        continue
      }
      diagnose(
        Diagnostic(
          node: message.syntax,
          position: message.syntax.positionAfterSkippingLeadingTrivia,
          message: message,
          fixIts: message.fixIts
        )
      )
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
