//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A protocol describing a type that contains tests.
///
/// - Warning: This protocol is used to implement the `@Test` macro. Do not use
///   it directly.
@_alwaysEmitConformanceMetadata
public protocol __TestContainer {
  /// The set of tests contained by this type.
  static var __tests: [Test] { get async }
}

extension Test {
  /// A string that appears within all auto-generated types conforming to the
  /// `__TestContainer` protocol.
  private static let _testContainerTypeNameMagic = "__🟠$test_container__"

  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified.
  static var all: some Sequence<Self> {
    get async {
      await withTaskGroup(of: [Self].self) { taskGroup in
        enumerateTypes(withNamesContaining: _testContainerTypeNameMagic) { _, type, _ in
          if let type = type as? any __TestContainer.Type {
            taskGroup.addTask {
              await type.__tests
            }
          }
        }

        return await taskGroup.reduce(into: [], +=)
      }
    }
  }

#if SWT_TARGET_OS_APPLE && !SWT_NO_DYNAMIC_LINKING && !SWT_NO_FILE_IO
  @_spi(ForSwiftTestingOnly)
  public static var testBundlePath: String? {
    // If the calling environment sets "XCTestBundlePath" (as Xcode does), then
    // we can rely on that variable rather than walking loaded images looking
    // for test content.
    if let envBundlePath = Environment.variable(named: "XCTestBundlePath") {
      var s = stat()
      if 0 == stat(envBundlePath, &s) && swt_S_ISDIR(s.st_mode) {
        return envBundlePath
      }
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

    return String(validatingCString: imageName)
  }
#endif
}

// MARK: -

/// The type of callback called by ``enumerateTypes(withNamesContaining:_:)``.
///
/// - Parameters:
///   - imageAddress: A pointer to the start of the image. This value is _not_
///     equal to the value returned from `dlopen()`. On platforms that do not
///     support dynamic loading (and so do not have loadable images), this
///     argument is unspecified.
///   - type: A Swift type.
///   - stop: An `inout` boolean variable indicating whether type enumeration
///     should stop after the function returns. Set `stop` to `true` to stop
///     type enumeration.
typealias TypeEnumerator = (_ imageAddress: UnsafeRawPointer?, _ type: Any.Type, _ stop: inout Bool) -> Void

/// Enumerate all types known to Swift found in the current process whose names
/// contain a given substring.
///
/// - Parameters:
///   - nameSubstring: A string which the names of matching classes all contain.
///   - body: A function to invoke, once per matching type.
func enumerateTypes(withNamesContaining nameSubstring: String, _ typeEnumerator: TypeEnumerator) {
  withoutActuallyEscaping(typeEnumerator) { typeEnumerator in
    withUnsafePointer(to: typeEnumerator) { context in
      swt_enumerateTypes(withNamesContaining: nameSubstring, .init(mutating: context)) { imageAddress, type, stop, context in
        let typeEnumerator = context!.load(as: TypeEnumerator.self)
        let type = unsafeBitCast(type, to: Any.Type.self)
        var stop2 = false
        typeEnumerator(imageAddress, type, &stop2)
        stop.pointee = stop2
      }
    }
  }
}
