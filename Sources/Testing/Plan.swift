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
public struct Plan: Sendable {
  /// Traits to apply to all tests when they are run.
  public var traits: [any Trait] = []
}

// MARK: - Result building

@_spi(Experimental)
extension Plan {
  @_documentation(visibility: private)
  @resultBuilder
  public struct Builder {
    public static func buildPartialBlock(first: Global) -> Plan {
      buildPartialBlock(accumulated: Plan(), next: first)
    }

    public static func buildPartialBlock(accumulated: Plan, next: Global) -> Plan {
      var result = accumulated
      switch next.kind {
      case let .trait(trait):
        result.traits.append(trait)
      }
      return result
    }
  }

  public init(@Builder _ planBuilder: @escaping @Sendable () -> Self) {
    self = planBuilder()
  }
}

@_spi(Experimental)
public struct Global: Sendable {
  fileprivate enum Kind: Sendable {
    case trait(any SuiteTrait)
  }

  fileprivate var kind: Kind

  public init(_ trait: some SuiteTrait) {
    kind = .trait(trait)
  }
}

// MARK: - Macro

@_spi(Experimental)
@freestanding(declaration, names: named(__testingPlan)) public macro Plan(
  @Plan.Builder _ planBuilder: @escaping @Sendable () -> Plan
) = #externalMacro(module: "TestingMacros", type: "PlanMacro")

extension Plan {
  fileprivate struct Generator: DiscoverableAsTestContent {
    static var testContentKind: _TestDiscovery.TestContentKind {
      "plan"
    }

    var buildPlan: @Sendable () async -> Plan
  }

  static var shared: Self {
    get async {
      var result: [Generator] = Generator.allTestContentRecords().lazy
        .compactMap { $0.load() }

#if compiler(<6.3)
      if result.isEmpty {
        result = Generator.allTypeMetadataBasedTestContentRecords().lazy
          .compactMap { $0.load() }
      }
#endif

      return await result.first?.buildPlan() ?? Plan()
    }
  }

  @safe public static func __store(
    _ plan: @escaping @Sendable () async -> Plan,
    into outValue: UnsafeMutableRawPointer,
    asTypeAt typeAddress: UnsafeRawPointer
  ) -> CBool {
#if !hasFeature(Embedded)
    guard typeAddress.load(as: Any.Type.self) == Generator.self else {
      return false
    }
#endif
    outValue.initializeMemory(as: Generator.self, to: .init(buildPlan: plan))
    return true
  }
}
