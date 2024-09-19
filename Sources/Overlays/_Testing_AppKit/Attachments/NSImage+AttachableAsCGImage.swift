//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(AppKit)
public import AppKit
@_spi(Experimental) public import _Testing_CoreGraphics

@_spi(Experimental)
extension NSImage: AttachableAsCGImage {
  public var attachableCGImage: CGImage {
    get throws {
      let ctm = AffineTransform(scale: _attachmentScaleFactor) as NSAffineTransform
      guard let result = cgImage(forProposedRect: nil, context: nil, hints: [.ctm: ctm]) else {
        throw ImageAttachmentError.couldNotCreateCGImage
      }
      return result
    }
  }

  public var _attachmentScaleFactor: CGFloat {
    let maxRepWidth = representations.lazy
      .map { CGFloat($0.pixelsWide) / $0.size.width }
      .filter { $0 > 0.0 }
      .max()
    return maxRepWidth ?? 1.0
  }

  /// Make a "safe" copy of this image by converting it to an instance of
  /// `CGImage` and wrapping that instance in a new instance of `NSImage`.
  ///
  /// - Returns: A copy of `self`, or `nil` if a copy could not be made.
  private func _makeSafeCopy() -> Self? {
    guard let tiffRepresentation else {
      return nil // give up, just make a normal copy
    }
    return Self(data: tiffRepresentation)
  }

  /// Get the base address of the loaded image containing `class`.
  ///
  /// - Parameters:
  ///   - class: The class to look for.
  ///
  /// - Returns: The base address of the image containing `class`, or `nil` if
  ///   no image was found (for instance, if the class is generic or dynamically
  ///   generated.)
  ///
  /// "Image" in this context refers to a binary/executable image.
  private static func _baseAddressOfImage(containing `class`: AnyClass) -> UnsafeRawPointer? {
    let classAsAddress = Unmanaged.passUnretained(`class` as AnyObject).toOpaque()

    var info = Dl_info()
    guard 0 != dladdr(classAsAddress, &info) else {
      return nil
    }
    return .init(info.dli_fbase)
  }

  /// The base address of the image containing AppKit's symbols, if known.
  private static nonisolated(unsafe) let _appKitBaseAddress: UnsafeRawPointer? = _baseAddressOfImage(containing: NSImageRep.self)

  /// Check whether or not an `NSImageRep` instance should be safe to use across
  /// isolation domains.
  ///
  /// - Parameters:
  ///   - imageRep: The object to check.
  ///
  /// - Returns: Whether or not `imageRep` is (more or less) safe to use
  ///   concurrently. If that information could not be determined, returns
  ///   `false` out of caution.
  private static func _imageRepIsGenerallyRecognizedAsSafe<T>(_ imageRep: T) -> Bool where T: NSImageRep {
    // NSCustomImageRep includes an arbitrary rendering block that may not be
    // concurrency-safe in Swift.
    if imageRep is NSCustomImageRep {
      return false
    }

    // Treat all other classes declared in AppKit as safe. We can't reason
    // about classes declared in other modules, so treat them all as if they
    // are unsafe.
    return Self._baseAddressOfImage(containing: T.self) == Self._appKitBaseAddress
  }

  /// Make a copy of this image.
  ///
  /// - Returns: A copy of `self`.
  ///
  /// If this image is not known to be safe to use across isolation domains (due
  /// to its class or one of its representations), this function makes a "safe"
  /// copy of this image by converting it to an instance of `CGImage` and
  /// wrapping that instance in a new instance of `NSImage`.
  public func _makeCopyForAttachment() -> Self {
    // Member of some subclass? Better make a "safe" copy.
    if !self.isMember(of: NSImage.self), let safeCopy = _makeSafeCopy() {
      return safeCopy
    }

    let allImageRepsAreSafe = representations.allSatisfy(Self._imageRepIsGenerallyRecognizedAsSafe)
    if !allImageRepsAreSafe, let safeCopy = _makeSafeCopy() {
      // The image contains one or more representations that we don't think are
      // safe, so make a "safe" copy.
      return safeCopy
    }

    // This image appears to be safe to copy directly. (This call should never
    // fail since we already know `self` is a direct instance of `NSImage`.)
    return self.copy() as! Self
  }
}
#endif
