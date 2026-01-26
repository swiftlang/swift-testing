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
#if compiler(>=6.3) && !SWT_NO_INTEROP
  /// The installed fallback event handler.
  private static let _fallbackEventHandler: SWTFallbackEventHandler? = {
    _swift_testing_getFallbackEventHandler()
  }()

  /// Encode an event and pass it to the installed fallback event handler.
  private static let _encodeAndInvoke: Event.Handler? = { [fallbackEventHandler = _fallbackEventHandler] in
    guard let fallbackEventHandler else {
      return nil
    }
    return ABI.CurrentVersion.eventHandler(encodeAsJSONLines: false) { recordJSON in
      recordJSON.withUnsafeBytes { recordJSON in
        fallbackEventHandler(
          String(describing: ABI.CurrentVersion.versionNumber),
          recordJSON.baseAddress!,
          recordJSON.count,
          nil
        )
      }
    }
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
#if compiler(>=6.3) && !SWT_NO_INTEROP
    // Encode the event as JSON and pass it to the handler.
    if let encodeAndInvoke = Self._encodeAndInvoke {
      encodeAndInvoke(self, context)
      return true
    }
#endif
    return false
  }
}
