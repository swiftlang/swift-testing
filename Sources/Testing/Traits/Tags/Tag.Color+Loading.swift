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

#if !SWT_NO_FILE_IO
#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst)) || os(Linux) || os(FreeBSD)
/// The path to the current user's home directory, if known.
private var _homeDirectoryPath: Path? {
#if SWT_TARGET_OS_APPLE
  if let fixedHomeVariable = Environment.variable(named: "CFFIXED_USER_HOME") {
    return Path(fixedHomeVariable)
  }
#endif
  return if let homeVariable = Environment.variable(named: "HOME") {
    Path(homeVariable)
  } else if let pwd = getpwuid(geteuid()), let path = pwd.pointee.pw_dir {
    Path(unsafeCString: path)
  } else {
    nil
  }
}
#endif

#if os(Windows)
/// The path to the current user's App Data directory, if known.
private var _appDataDirectoryPath: Path? {
  var appDataDirectoryPath: PWSTR? = nil
  var FOLDERID_LocalAppData = FOLDERID_LocalAppData
  if S_OK == SHGetKnownFolderPath(&FOLDERID_LocalAppData, 0, nil, &appDataDirectoryPath), let appDataDirectoryPath {
    defer {
      CoTaskMemFree(appDataDirectoryPath)
    }
    if let path = String.decodeCString(appDataDirectoryPath, as: UTF16.self)?.result {
      return Path(path)
    }
  }
  return nil
}
#endif

/// The path to the user-specific `".swift-testing"` directory.
///
/// On Apple platforms and on Linux, this path is equivalent to
/// `"~/.swift-testing"`. On Windows, it is equivalent to
/// `"%HOMEPATH%\AppData\Local\.swift-testing"`.
///
/// The value of this property is `nil` if the platform does not support the
/// concept of a home directory, or if the home directory could not be
/// determined.
var swiftTestingDirectoryPath: Path? {
  // The (default) name of the .swift-testing directory.
  let swiftTestingDirectoryName = ".swift-testing"

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst)) || os(Linux) || os(FreeBSD)
  if let homeDirectoryPath = _homeDirectoryPath {
    return homeDirectoryPath.appending(Path.Component(swiftTestingDirectoryName))
  }
#elseif SWT_TARGET_OS_APPLE || os(Android)
  // Other Apple/Darwin platforms do not support the concept of a home
  // directory. One exists for the current user, but it's not something that
  // actually contains user-configurable data like a .swift-testing directory.
  // Android also does not support per-user home directories (does it?)
#elseif os(Windows)
  if let appDataDirectoryPath = _appDataDirectoryPath {
    return appDataDirectoryPath.appending(Path.Component(swiftTestingDirectoryName))
  }
#elseif os(WASI)
  // WASI does not support the concept of a home directory.
#else
#warning("Platform-specific implementation missing: .swift-testing directory location unavailable")
#endif
  return nil
}

/// Read tag colors out of the file `"tag-colors.json"` in a given directory.
///
/// - Parameters:
///   - swiftTestingDirectoryPath: The `".swift-testing"` directory from which
///     tag color data should be read.
///
/// - Returns: A dictionary keyed by tag whose values are the colors to use for
///   those tags.
///
/// - Throws: Any error that occurred while reading or decoding the JSON file.
///
/// This function attempts to read the contents of the file `"tag-colors.json"`
/// in the directory specified by `swiftTestingDirectoryPath`. The file is
/// assumed to contain a JSON object (a dictionary) where the keys are tags'
/// string values and the values represent tag colors. For a list of the
/// supported formats for tag colors in this dictionary, see <doc:AddingTags>.
func loadTagColors(fromFileInDirectoryAt swiftTestingDirectoryPath: Path? = swiftTestingDirectoryPath) throws -> [Tag: Tag.Color] {
  guard let swiftTestingDirectoryPath else {
    // If the platform does not support user-specific configuration, skip custom
    // tag colors.
    return [:]
  }

  // Find the path to the tag-colors.json file and try to load its contents.
  let tagColorsPath = swiftTestingDirectoryPath.appending("tag-colors.json")
  let fileHandle = try FileHandle(forReadingAt: tagColorsPath)
  let tagColorsData = try fileHandle.readToEnd()

  // By default, a dictionary with non-string keys is encoded to and decoded
  // from JSON as an array, so we decode the dictionary as if its keys are plain
  // strings, then map them to tags.
  //
  // nil is a valid decoded color value (representing "no color") that we can
  // use for merging tag color data from multiple sources, but it is not valid
  // as an actual tag color, so we have a step here that filters it.
  return try tagColorsData.withUnsafeBytes { tagColorsData in
    try JSON.decode([Tag: Tag.Color?].self, from: tagColorsData)
      .compactMapValues { $0 }
  }
}

@available(*, deprecated, message: "Use loadTagColors(fromFileInDirectoryAt:) instead.")
func loadTagColors(fromFileInDirectoryAtPath swiftTestingDirectoryPath: String?) throws -> [Tag: Tag.Color] {
  try loadTagColors(fromFileInDirectoryAt: swiftTestingDirectoryPath.map(Path.init(_:)))
}
#endif
