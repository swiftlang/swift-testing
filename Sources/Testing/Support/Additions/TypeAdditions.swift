//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Get the fully-qualified components of a type's name.
///
/// - Parameters:
///   - type: The type whose name components should be returned.
///
/// - Returns: The components of `type`'s fully-qualified name. For example, if
///   `type` is named `Example.MyClass`, the result is `["Example", "MyClass"]`.
func nameComponents(of type: Any.Type) -> [String] {
  _typeName(type, qualified: true)
    .split(separator: ".")
    .map(String.init)
}
