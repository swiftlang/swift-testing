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
struct GDIPlusError: Error, RawRepresentable {
  var rawValue: CInt
}

func withGDIPlus<R>(_ body: () throws -> R) throws -> R {
  var error = CInt(0)
  guard let token = swt_gdiplus_startup(&error) else {
    throw GDIPlusError(rawValue: error)
  }
  defer {
    swt_gdiplus_shutdown(token)
  }

  return try body()
}
#endif
