//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Call a throwing function and assume that the error it throws is of the given
/// error type.
///
/// - Parameters:
///   - errorType: The type of error that `body` throws.
///   - bug: A bug tracking updating the underlying interface that does not use
///     typed throws yet.
///   - body: A function to call.
///
/// - Returns: Whatever is returned by `body`.
///
/// - Throws: Whatever is thrown by `body`. If the thrown error is _not_ of type
///   `errorType`, the testing library terminates the current process.
///   Otherwise, it casts the error to `errorType` and rethrows it.
///
/// Use this function when calling some interface in another module that does
/// not yet support typed throws and needs to be updated. Do not use this
/// function with calls whose thrown error type is not documented or is equal to
/// `any Error` or `Never`, as it is redundant in those cases.
#if os(Windows)
@inline(never) // WORKAROUND: rdar://192701000
#endif
nonisolated(nonsending) func withUnsafeTypedThrowsEmulation<R, E>(
  throwing errorType: E.Type,
  becauseOf bug: @autoclosure () -> Bug,
  _ body: nonisolated(nonsending) () async throws -> R
) async throws(E) -> R {
  do {
    return try await body()
  } catch let error as E {
    throw error
  } catch {
    let bug = bug()
    let bugDescription = bug.url ?? bug.id ?? "<unknown>"
#if !hasFeature(Embedded)
    fatalError("Expected error of type '\(TypeInfo(describing: errorType))', but caught an error of type '\(TypeInfo(describingTypeOf: error))' instead. \(fileABugMessage(context: bugDescription))")
#else
    fatalError("Expected error of one type, but caught an error of a different type instead. \(fileABugMessage(context: bugDescription))")
#endif
  }
}
