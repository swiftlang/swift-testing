//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public import SwiftSyntax

extension DeclGroupSyntax {
  /// The type declared or extended by this instance.
  var type: TypeSyntax {
    if let namedDecl = asProtocol((any NamedDeclSyntax).self) {
      return TypeSyntax(IdentifierTypeSyntax(name: namedDecl.name))
    } else if let extensionDecl = `as`(ExtensionDeclSyntax.self) {
      return extensionDecl.extendedType
    }
    fatalError("Unexpected DeclGroupSyntax type \(Swift.type(of: self)). Please file a bug report at https://github.com/apple/swift-testing/issues/new")
  }

  /// Check whether or not this instance includes a given type name in its
  /// inheritance clause.
  ///
  /// - Parameters:
  ///   - typeName: The name of the possible parent type.
  ///   - moduleName: The name of the module the specified type is declared in.
  ///
  /// - Returns: Whether or not the represented type inherits from the specified
  ///   type. If the represented type inherits _indirectly_ from that type, or
  ///   inherits via another declaration group (such as an `extension`), this
  ///   function is unable to detect it and will return `false.`
  func inherits(fromTypeNamed typeName: String, inModuleNamed moduleName: String) -> Bool {
    if let inherited = inheritanceClause?.inheritedTypes {
      return inherited.lazy
        .map(\.type)
        .contains { $0.isNamed(typeName, inModuleNamed: moduleName) }
    }
    return false
  }
}
