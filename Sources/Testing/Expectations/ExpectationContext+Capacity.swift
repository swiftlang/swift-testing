//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// The default number of subexpressions to preallocate space for when
/// performing a call to `#expect()`.
///
/// This constant is defined in a separate file so it can be used by both the
/// library and macro targets.
let defaultExpectationContextExpressionCapacity = 16
