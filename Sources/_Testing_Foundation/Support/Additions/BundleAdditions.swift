//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
@_spi(Experimental) import Testing
public import Foundation

#if SWT_TARGET_OS_APPLE && !SWT_NO_DYNAMIC_LINKING
private import _TestingInternals
#endif

extension Bundle {
#if SWT_TARGET_OS_APPLE && !SWT_NO_DYNAMIC_LINKING
  /// A string that appears within all auto-generated types conforming to the
  /// `__TestContainer` protocol.
  private static let _testContainerTypeNameMagic = "__🟠$test_container__"

  /// Storage for ``testContent``.
  ///
  /// On Apple platforms, the bundle containing test content is a loadable
  /// XCTest bundle. By the time this property is read, the bundle should have
  /// already been loaded.
  ///
  /// If more than one XCTest bundle has been loaded, we will assume that the
  /// first one we see is the correct one. We rely on the testing library to
  /// report images for us here.
  private static let _testContent: Bundle? = {
    // If the calling environment sets "XCTestBundlePath" (as Xcode does), then
    // we can rely on that variable rather than walking loaded images looking
    // for test content.
    if let envBundlePath = Environment.variable(named: "XCTestBundlePath"),
       let bundle = Bundle(path: envBundlePath) {
      return bundle
    }

    // Find the first image loaded into the current process that contains any
    // test content.
    var imageAddress: UnsafeRawPointer?
    swt_enumerateTypes(withNamesContaining: _testContainerTypeNameMagic, &imageAddress) { imageAddress, _, stop, context in
      let result = context?.assumingMemoryBound(to: UnsafeRawPointer?.self)
      if imageAddress != nil {
        result?.pointee = imageAddress
        stop.pointee = true
      }
    }

    // Get the path to the image we found.
    var info = Dl_info()
    guard let imageAddress, 0 != dladdr(imageAddress, &info), let imageName = info.dli_fname else {
      return nil
    }

    // Construct a lazy sequence of URLs corresponding to the directories that
    // contain the loaded image.
    let imageURL = URL(fileURLWithFileSystemRepresentation: imageName, isDirectory: false, relativeTo: nil)
    let containingDirectoryURLs = sequence(first: imageURL) { url in
      let result = url.deletingLastPathComponent()
      if result == url || result.path == "/" {
        return nil
      }
      return result
    }.dropFirst()

    // Find the directory most likely to contain our test content and return it.
    return containingDirectoryURLs.lazy
      .filter { $0.pathExtension.caseInsensitiveCompare("xctest") == .orderedSame }
      .compactMap(Bundle.init(url:))
      .first { _ in true }
  }()
#endif

  @_spi(Experimental)
  public static var testContent: Bundle {
#if SWT_TARGET_OS_APPLE && !SWT_NO_DYNAMIC_LINKING
    _testContent ?? main
#else
    // On other platforms, the main executable contains test content.
    main
#endif
  }
}
#endif
