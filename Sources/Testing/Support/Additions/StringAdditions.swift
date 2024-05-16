//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_BUILDING_WITH_CMAKE
@_implementationOnly import _TestingInternals
#else
private import _TestingInternals
#endif

extension String {
  init?(validatingUTF8CString cString: UnsafePointer<CChar>) {
#if compiler(>=5.11)
    self.init(validatingCString: cString)
#else
    self.init(validatingUTF8: cString)
#endif
  }
}
