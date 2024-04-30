//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Tag {
  /// Create a tag representing a static member of ``Tag`` such as ``Tag/red``.
  ///
  /// - Parameters:
  ///   - type: The type in which the tag is declared. This type must either be
  ///     ``Tag`` or a type nested within it.
  ///   - name: The name of the declared variable, not including its parent
  ///     type, module name, or a leading period.
  ///
  /// - Returns: An instance of ``Tag``.
  ///
  /// - Warning: This function is used to implement the `@Tag` macro. Do not
  ///   call it directly.
  public static func __fromStaticMember(of type: Any.Type, _ name: _const String) -> Self {
    // Split up the supplied type name into its fully-qualified components. We
    // will use this string array to reconstruct the fully-qualified name of the
    // described static member.
    var fullyQualifiedMemberNameComponents = TypeInfo(describing: type).fullyQualifiedNameComponents

    // Strip off the "Testing" and "Tag" components of the fully-qualified name
    // since they're redundant. Macro expansion will have already checked that
    // the type is nested inside `Tag`.
    fullyQualifiedMemberNameComponents = Array(fullyQualifiedMemberNameComponents.dropFirst(2))

    // Add the specified tag name to the fully-qualified name and reconstruct
    // its string representation.
    fullyQualifiedMemberNameComponents += CollectionOfOne(name)
    let fullyQualifiedMemberName = fullyQualifiedMemberNameComponents.joined(separator: ".")

    return Self(kind: .staticMember(fullyQualifiedMemberName))
  }
}

/// Declare a tag that can be applied to a test function or test suite.
///
/// Use this tag with members of the ``Tag`` type declared in an extension to
/// mark them as usable with tests. For more information on declaring tags, see
/// <doc:AddingTags>.
@attached(accessor) @attached(peer) 
#if compiler(<5.11)
@available(*, deprecated, message: "Attribute 'Tag' requires Swift 6 or later")
#endif
public macro Tag() = #externalMacro(module: "TestingMacros", type: "TagMacro")
