//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if swift(>=5.11)
import SwiftSyntax
#else
public import SwiftSyntax
#endif

extension VersionTupleSyntax {
  /// A type describing the major, minor, and patch components of a version
  /// tuple.
  struct Components: Comparable, CustomStringConvertible {
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

  /// The major, minor, and patch components of this version tuple.
  var components: Components {
#if swift(<6.0)
    let stringComponents = trimmedDescription.split(separator: "." as Character)
    guard let major = stringComponents.first.flatMap({ UInt64($0) }) else {
      return Components(major: 0)
    }
    var minor: UInt64?
    var patch: UInt64?
    if stringComponents.count > 1 {
      minor = UInt64(stringComponents[1])
      if stringComponents.count > 2 {
        patch = UInt64(stringComponents[2])
      }
    }
#else
    let major = UInt64(major.text) ?? 0
    let minor = minor.map(\.text).flatMap(UInt64.init)
    let patch = patch.map(\.text).flatMap(UInt64.init)
#endif

    return Components(major: major, minor: minor, patch: patch)
  }
}
