//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type used to describe other Swift types used by the testing library's
/// macros.
///
/// - Warning: This type alias is used to implement the `@Test`, `@Suite`, and
///   `@Tag` macros. Do not use it directly.
#if !hasFeature(Embedded)
public typealias __TypeInfo<S> = S.Type where S: ~Copyable & ~Escapable
#else
public typealias __TypeInfo<S> = (S.Type, fullyQualifiedName: StaticString /* FIXME: _const String */) where S: ~Copyable & ~Escapable
#endif
