//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if compiler(>=5.11)
import SwiftSyntax
#else
public import SwiftSyntax
#endif

extension VersionTupleSyntax {
  /// A type describing the major, minor, and patch components of a version
  /// tuple.
  struct ComponentValues: Comparable, CustomStringConvertible {
    /// The major component.
    var major: UInt64

    /// The minor component.
    var minor: UInt64?

    /// The patch component.
    var patch: UInt64?

    static func <(lhs: Self, rhs: Self) -> Bool {
      if lhs.major < rhs.major {
        return true
      } else if lhs.major == rhs.major {
        if lhs.minor ?? 0 < rhs.minor ?? 0 {
          return true
        } else if lhs.minor ?? 0 == rhs.minor ?? 0 {
          return lhs.patch ?? 0 < rhs.patch ?? 0
        }
      }
      return false
    }

    var description: String {
      if let minor {
        if let patch {
          return "\(major).\(minor).\(patch)"
        }
        return "\(major).\(minor)"
      }
      return "\(major)"
    }
  }

  /// The numeric values of the major, minor, and patch components.
  var componentValues: ComponentValues {
    let components = components
    let startIndex = components.startIndex

    let major = UInt64(major.text) ?? 0
    let minor: UInt64? = if components.count > 0 {
      UInt64(components[startIndex].number.text)
    } else {
      nil
    }
    let patch: UInt64? = if components.count > 1 {
      UInt64(components[components.index(after: startIndex)].number.text)
    } else {
      nil
    }

    return ComponentValues(major: major, minor: minor, patch: patch)
  }
}
