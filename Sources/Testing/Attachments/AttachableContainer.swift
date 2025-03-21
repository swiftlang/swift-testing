//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing a type that can be attached to a test report or
/// written to disk when a test is run and which contains another value that it
/// stands in for.
///
/// To attach an attachable value to a test report or test run output, use it to
/// initialize a new instance of ``Attachment``, then call
/// ``Attachment/attach(sourceLocation:)``. An attachment can only be attached
/// once.
///
/// A type can conform to this protocol if it represents another type that
/// cannot directly conform to ``Attachable``, such as a non-final class or a
/// type declared in a third-party module.
@_spi(Experimental)
public protocol AttachableContainer<AttachableValue>: Attachable, ~Copyable {
#if hasFeature(SuppressedAssociatedTypes)
  /// The type of the attachable value represented by this type.
  associatedtype AttachableValue: ~Copyable
#else
  /// The type of the attachable value represented by this type.
  associatedtype AttachableValue
#endif

  /// The attachable value represented by this instance.
  var attachableValue: AttachableValue { get }
}
