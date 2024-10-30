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
@_spi(ForSwiftTestingOnly) private import Testing
public import Foundation

extension Bundle {
#if SWT_TARGET_OS_APPLE && !SWT_NO_DYNAMIC_LINKING && !SWT_NO_FILE_IO
  /// A string that appears within all auto-generated types conforming to the
  /// `__TestContainer` protocol.
  private static let _testContainerTypeNameMagic = "__🟠$test_container__"

  /// Storage for ``testTarget``.
  ///
  /// On Apple platforms, the bundle containing test content is a loadable
  /// XCTest bundle. By the time this property is read, the bundle should have
  /// already been loaded.
  private static let _testTarget: Bundle? = {
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
    enumerateTypes(withNamesContaining: _testContainerTypeNameMagic) { thisImageAddress, _, stop in
      imageAddress = thisImageAddress
      stop = true
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
      try? url.resourceValues(forKeys: [.parentDirectoryURLKey]).parentDirectory
    }.dropFirst()

    // Find the directory most likely to contain our test content and return it.
    return containingDirectoryURLs.lazy
      .filter { $0.pathExtension.caseInsensitiveCompare("xctest") == .orderedSame }
      .compactMap(Bundle.init(url:))
      .first { _ in true }
  }()
#endif

  /// A bundle representing the currently-running test target.
  ///
  /// On Apple platforms, this bundle represents the test bundle built by Xcode
  /// or Swift Package Manager. On other platforms, it is equal to the main
  /// bundle and represents the test executable built by Swift Package Manager.
  ///
  /// If more than one test bundle has been loaded into the current process, the
  /// value of this property represents the first test bundle found by the
  /// testing library at runtime.
  @_spi(Experimental)
  public static var testTarget: Bundle {
#if SWT_TARGET_OS_APPLE && !SWT_NO_DYNAMIC_LINKING && !SWT_NO_FILE_IO
    _testTarget ?? main
#else
    // On other platforms, the main executable contains test content.
    main
#endif
  }
}
#endif
