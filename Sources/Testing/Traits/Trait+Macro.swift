//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) private import _TestDiscovery

@_spi(Experimental)
@freestanding(declaration)
public macro global<each T>(
  _ traits: repeat each T
) = #externalMacro(module: "TestingMacros", type: "GlobalTraitMacro") where repeat each T: GlobalTrait

private struct _GlobalTraitList: DiscoverableAsTestContent {
  static var testContentKind: _TestDiscovery.TestContentKind {
    "gtrt"
  }

  var traits = [any GlobalTrait]()
}

extension _GlobalTraitList {
  init<each T>(_ traits: repeat each T) where repeat each T: GlobalTrait {
    for trait in repeat each traits {
      self.traits.append(trait)
    }
  }
}

extension [GlobalTrait] {
  static var all: Self {
    var result: Self = _GlobalTraitList.allTestContentRecords().lazy
      .compactMap { $0.load() }
      .flatMap(\.traits)

#if compiler(<6.3)
    if result.isEmpty {
      result = _GlobalTraitList.allTypeMetadataBasedTestContentRecords().lazy
        .compactMap { $0.load() }
        .flatMap(\.traits)
    }
#endif

    return result
  }
}

@_spi(Experimental)
@safe public func __store<each T>(
  _ traits: repeat each T,
  into outValue: UnsafeMutableRawPointer,
  asTypeAt typeAddress: UnsafeRawPointer
) -> CBool where repeat each T: GlobalTrait {
#if !hasFeature(Embedded)
  guard typeAddress.load(as: Any.Type.self) == _GlobalTraitList.self else {
    return false
  }
#endif
  outValue.initializeMemory(as: _GlobalTraitList.self, to: .init(repeat each traits))
  return true
}
