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
@_spi(Experimental) public import Testing

// FIXME: swiftc gets confused about the _Gdiplus module using types from WinSDK; needs to be part of WinSDK directly
public import WinSDK
private import _Gdiplus

@_spi(Experimental)
public final class _AttachableHBITMAPWrapper {
  private let _bitmap: HBITMAP
  private let _palette: HPALETTE?

  fileprivate init(bitmap: consuming HBITMAP, palette: consuming HPALETTE? = nil) {
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

@_spi(Experimental)
extension _AttachableHBITMAPWrapper: AttachableAsGDIPlusImage {
  public func _withGDIPlusImage<R>(
    for attachment: borrowing Attachment<some AttachableWrapper<_AttachableHBITMAPWrapper>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R {
    guard let image = swt_winsdk_GdiplusBitmapCreate(_bitmap, _palette) else {
      print("swt_winsdk_GdiplusBitmapCreate: \(Gdiplus.GenericError)")
      throw GDIPlusError(rawValue: Gdiplus.GenericError)
    }
    defer {
      swt_winsdk_GdiplusImageDelete(image)
    }
    return try withExtendedLifetime(self) {
      try body(image)
    }
  }
}

@_spi(Experimental)
extension Attachment where AttachableValue == _AttachableImageWrapper<_AttachableHBITMAPWrapper> {
  public init(
    _ bitmap: consuming UnsafeMutableRawPointer,
    with palette: consuming UnsafeMutableRawPointer? = nil,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let bitmap = bitmap.assumingMemoryBound(to: HBITMAP__.self)
    let palette = palette.map { $0.assumingMemoryBound(to: HPALETTE__.self) }
    let bitmapWrapper = _AttachableHBITMAPWrapper(bitmap: bitmap, palette: palette)
    self.init(bitmapWrapper, named: preferredName, as: imageFormat, sourceLocation: sourceLocation)
  }

  public static func record(
    _ bitmap: consuming UnsafeMutableRawPointer,
    with palette: consuming UnsafeMutableRawPointer? = nil,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let bitmap = bitmap.assumingMemoryBound(to: HBITMAP__.self)
    let palette = palette.map { $0.assumingMemoryBound(to: HPALETTE__.self) }
    let bitmapWrapper = _AttachableHBITMAPWrapper(bitmap: bitmap, palette: palette)
    Self.record(bitmapWrapper, named: preferredName, as: imageFormat, sourceLocation: sourceLocation)
  }
}
#endif
