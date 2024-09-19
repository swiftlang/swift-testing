//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(XCTest) && canImport(CoreGraphics)
public import XCTest
@_spi(Experimental) public import _Testing_CoreGraphics

// Ensure conformances to AttachableAsCGImage are linked in at runtime.
#if canImport(AppKit)
@_spi(Experimental) private import _Testing_AppKit
#endif
#if canImport(UIKit)
@_spi(Experimental) private import _Testing_UIKit
#endif

private import ObjectiveC

@_spi(Experimental)
extension XCUIScreenshot: AttachableAsCGImage {
  /// The underlying image (either `NSImage` or `UIImage`.)
  private nonisolated var _image: (any AttachableAsCGImage)? {
    let selector = Selector("image" as String)
    return class_getMethodImplementation(Self.self, selector)
      .map { unsafeBitCast($0, to: (@convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>).self) }
      .flatMap { $0(self, selector).takeUnretainedValue() as? any AttachableAsCGImage }
  }

  public nonisolated var attachableCGImage: CGImage {
    get throws {
      // This property bypasses the main-actor isolation of `XCUIScreenshot`.
      // Instances of this class are immutable, as are instances of `UIImage`,
      // and on macOS it is exceedingly unlikely that the contained instance of
      // `NSImage` will be mutated after the screenshot is captured.
      guard let _image else {
        throw ImageAttachmentError.couldNotCreateCGImage
      }
      return try _image.attachableCGImage
    }
  }

  public nonisolated var _attachmentOrientation: UInt32 {
    _image?._attachmentOrientation ?? CGImagePropertyOrientation.up.rawValue
  }

  public nonisolated var _attachmentScaleFactor: CGFloat {
    _image?._attachmentScaleFactor ?? 1.0
  }
}
#endif
