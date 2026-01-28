//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

extension Event {
#if !SWT_NO_INTEROP
  private static let _fallbackEventHandler: SWTFallbackEventHandler? = {
    _swift_testing_getFallbackEventHandler()
  }()
#endif

  /// Post this event to the currently-installed fallback event handler.
  ///
  /// - Parameters:
  ///   - context: The context associated with this event.
  ///
  /// - Returns: Whether or not the fallback event handler was invoked. If the
  ///   currently-installed handler belongs to the testing library, returns
  ///   `false`.
  borrowing func postToFallbackHandler(in context: borrowing Context) -> Bool {
#if !SWT_NO_INTEROP
    guard let fallbackEventHandler = Self._fallbackEventHandler else {
      return false
    }

    // Encode the event as JSON and pass it to the handler.
    let encodeAndInvoke = ABI.CurrentVersion.eventHandler(encodeAsJSONLines: false) { recordJSON in
      fallbackEventHandler(
        String(describing: ABI.CurrentVersion.versionNumber),
        recordJSON.baseAddress!,
        recordJSON.count,
        nil
      )
    }
    encodeAndInvoke(self, context)
    return true
#else
    return false
#endif
  }
}
