<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

# Environment variables in Swift Testing

This document lists the environment variables that Swift Testing currently uses.
This list is meant for use by developers working on Swift Testing.

Those environment variables marked with `*` are defined by components outside
Swift Testing. In general, environment variables that Swift Testing defines have
names prefixed with `SWT_`.

> [!WARNING]
> This document is not an API contract. The set of environment variables Swift
> Testing uses may change at any time.

## Console output

| Variable Name | Value Type | Notes |
|-|:-:|-|
| `COLORTERM`\* | `String` | Used to determine if the current terminal supports 24-bit color. Common across UNIX-like platforms. |
| `NO_COLOR`\* | `Any?` | If set to any value, disables color output regardless of terminal capabilities. |
| `SWT_ENABLE_EXPERIMENTAL_CONSOLE_OUTPUT` | `Bool` | Used to enable or disable experimental console output. |
| `SWT_SF_SYMBOLS_ENABLED` | `Bool` | Used to explicitly enable or disable SF&nbsp;Symbols support on macOS. |
| `TERM`\* | `String` | Used to determine if the current terminal supports 4- or 8-bit color. Common across UNIX-like platforms. |

## Error handling

| Variable Name | Value Type | Notes |
|-|:-:|-|
| `SWT_FOUNDATION_ERROR_BACKTRACING_ENABLED` | `Bool` | Used to explicitly enable or disable error backtrace capturing when an instance of `NSError` or `CFError` is created on Apple platforms. |
| `SWT_SWIFT_ERROR_BACKTRACING_ENABLED` | `Bool` | Used to explicitly enable or disable error backtrace capturing when a Swift error is thrown. |

## Exit tests

| Variable Name | Value Type | Notes |
|-|:-:|-|
| `SWT_BACKCHANNEL` | `CInt`/`HANDLE` | A file descriptor (handle on Windows) to which the exit test's 'events are written. |
| `SWT_CAPTURED_VALUES` | `CInt`/`HANDLE` | A file descriptor (handle on Windows) containing captured values passed to the exit test. |
| `SWT_CLOSEFROM` | `CInt` | Used on OpenBSD to emulate `posix_spawn_file_actions_addclosefrom_np()`. |
| `SWT_EXIT_TEST_ID` | `String` (JSON) | Specifies which exit test to run. |
| `XCTestBundlePath`\* | `String` | Used on Apple platforms to determine if Xcode is hosting the test run. |

## Miscellaneous

| Variable Name | Value Type | Notes |
|-|:-:|-|
| `CFFIXED_USER_HOME`\* | `String` | Used on Apple platforms to determine the user's home directory. |
| `HOME`\* | `String` | Used to determine the user's home directory. |
| `SIMULATOR_RUNTIME_BUILD_VERSION`\* | `String` | Used when running in the iOS (etc.) Simulator to determine the simulator's version. |
| `SIMULATOR_RUNTIME_VERSION`\* | `String` | Used when running in the iOS (etc.) Simulator to determine the simulator's version. |
| `SWT_PRETTY_PRINT_JSON` | `Bool` | Used to enable pretty-printed JSON output to the event stream (for debugging purposes). |
| `SWT_USE_LEGACY_TEST_DISCOVERY` | `Bool` | Used to explicitly enable or disable legacy test discovery. |
