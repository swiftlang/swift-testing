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
public import WinSDK
private import _Testing_Internals

public final class _AttachableHBITMAPWrapper {
  private let _bitmap: HBITMAP
  private let _palette: HPALETTE?

  init(bitmap: consuming HBITMAP, palette: consuming HPALETTE) {
    _bitmap = bitmap
    _palette = palette
  }

  deinit {
    DeleteObject(_bitmap)
    if let _palette {
      DeleteObject(_palette)
    }
  }
}

extension _AttachableHBITMAPWrapper: AttachableAsGDIPlusImage {
  public func _withGDIPlusImage<R>(
    for attachment: Attachable<some AttachableWrapper<Self>>,
    _ body: (UnsafeMutableRawPointer) throws -> R
  ) throws -> R {
    let image = swt_gdiplus_createImageFromHBITMAP(_bitmap, _palette)
    defer {
      swt_gdiplus_destroyImage(image)
    }
    return try withExtendedLifetime(self) {
      try body(image)
    }
  }
}

extension Attachment where AttachableValue == _AttachableImageWrapper<_AttachableHBITMAPWrapper> {
  public init(
    _ bitmap: consuming HBITMAP,
    with palette: consuming HPALETTE? = nil,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let bitmapWrapper = _AttachableHBITMAPWrapper(bitmap: bitmap, palette: palette)
    self.init(bitmapWrapper, named: preferredName, as: imageFormat, sourceLocation: sourceLocation)
  }

  public static func record(
    _ bitmap: consuming HBITMAP,
    with palette: consuming HPALETTE? = nil,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let bitmapWrapper = _AttachableHBITMAPWrapper(bitmap: bitmap, palette: palette)
    Self.record(bitmapWrapper, named: preferredName, as: imageFormat, sourceLocation: sourceLocation)
  }
}
#endif
