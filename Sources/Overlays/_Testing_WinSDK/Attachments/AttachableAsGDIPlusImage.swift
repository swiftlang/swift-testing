//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows)
private import _Gdiplus

public protocol AttachableAsGDIPlusImage {
  /// GDI+ objects are [not thread-safe](https://learn.microsoft.com/en-us/windows/win32/procthread/multiple-threads-and-gdi-objects)
  /// by design. The caller is responsible for guarding against concurrent
  /// access to the resulting GDI+ image object.
  /// 
  /// - Warning: Do not call this function directly. Instead, call ``withGDIPlusImage(for:_:)``.
  func _withGDIPlusImage<R>(
    for attachment: borrowing Attachment<some AttachableWrapper<Self>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R
}

extension AttachableAsGDIPlusImage {
  /// GDI+ objects are [not thread-safe](https://learn.microsoft.com/en-us/windows/win32/procthread/multiple-threads-and-gdi-objects)
  /// by design. The caller is responsible for guarding against concurrent
  /// access to the resulting GDI+ image object.
  func withGDIPlusImage<R>(
    for attachment: borrowing Attachment<some AttachableWrapper<Self>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R {
    // Stuff the attachment into a pointer so we can reference it from within
    // the closure we pass to `withGDIPlus(_:)`. (The compiler currently can't
    // reason about the lifetime of a borrowed value passed into a closure.)
    try withUnsafePointer(to: attachment) { attachment in
      try withGDIPlus {
        try self._withGDIPlusImage(for: attachment.pointee, body)
      }
    }
  }
}

public protocol _AttachableByAddressAsGDIPlusImage {
  /// GDI+ objects are [not thread-safe](https://learn.microsoft.com/en-us/windows/win32/procthread/multiple-threads-and-gdi-objects)
  /// by design. The caller is responsible for guarding against concurrent
  /// access to the resulting GDI+ image object.
  /// 
  /// - Warning: Do not call this function directly. Instead, call ``withGDIPlusImage(for:_:)``.
  static func _withGDIPlusImage<R>(
    _ address: UnsafeMutablePointer<Self>,
    for attachment: borrowing Attachment<some AttachableWrapper<UnsafeMutablePointer<Self>>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R
}
#endif
