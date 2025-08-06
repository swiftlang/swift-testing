//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import WinSDK

extension GUID {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    withUnsafeBytes(of: lhs) { lhs in
      withUnsafeBytes(of: rhs) { rhs in
        lhs.elementsEqual(rhs)
      }
    }
  }
}