//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A namespace for ABI symbols.
@_spi(ForToolsIntegrationOnly)
public enum ABI: Sendable {}

// MARK: -

@_spi(ForToolsIntegrationOnly)
extension ABI {
  /// A namespace for ABI version 0 symbols.
  public enum v0: Sendable {}

  /// A namespace for ABI version 1 symbols.
  @_spi(Experimental)
  public enum v1: Sendable {}
}

/// A namespace for ABI version 0 symbols.
@_spi(ForToolsIntegrationOnly)
@available(*, deprecated, renamed: "ABI.v0")
public typealias ABIv0 = ABI.v0
