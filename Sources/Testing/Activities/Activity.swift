//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public struct Activity: Sendable, ~Escapable {
  public var name: String {
    let context = context
    return context.name.rawValue
  }

  public var sourceLocation: SourceLocation {
    let context = context
    return context.sourceLocation
  }

  var context: Context

  struct Context: Sendable {
    var name: Comment
    var sourceLocation: SourceLocation

#if os(anyAppleOS)
    private static let _nextID = Atomic<Int>(0)
#else
    private static let _nextID = Atomic<UInt128>(0)
#endif
    var id = Self._nextID.add(1, ordering: .sequentiallyConsistent).newValue
  }

  @_lifetime(immortal)
  init(_ context: Context) {
    self.context = copy context
  }
}

extension Activity {
  @TaskLocal fileprivate static var currentContext: Context?

  public static var current: Self? {
    _read {
      guard let currentContext else {
        yield nil; return
      }
      yield Activity(currentContext)
    }
  }
}

public func withActivity<R, E>(
  _ name: Comment? = nil,
  sourceLocation: SourceLocation = #Testing::sourceLocation,
  _ body: @Sendable (borrowing Activity) async throws(E) -> R
) async throws(E) -> R {
  var result: Result<R, E>!

  let name = name ?? "Activity at \(sourceLocation)"
  let activity = Activity(.init(name: name, sourceLocation: sourceLocation))
  await Activity.$currentContext.withValue(activity.context) {
    do throws(E) {
      result = try await .success(body(activity))
    } catch {
      result = .failure(error)
    }
  }

  return try result.get()
}
