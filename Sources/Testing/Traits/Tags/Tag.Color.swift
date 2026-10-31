//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Tag {
  /// An enumeration describing colors that can be applied to tests' tags.
  ///
  /// ## See Also
  ///
  /// - <doc:AddingTags>
  @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
  @available(*, deprecated, renamed: "Color")
  public typealias Color = Testing.Color
}
