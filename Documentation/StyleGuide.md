# Code and documentation style guide

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Write code and documentation that matches the style and voice in the rest of the
testing library.

## Overview

The testing library has a specific style used in its code and documentation.
When preparing code or documentation for submission to the testing library,
developers should take care to match this style and ensure that developers using
it have a consistent experience.

### Code

#### Indentation and spacing

When writing code for the testing library, use two spaces for indentation. Wrap
comments (especially long block comments) at 80 columns. Code does not need to
be wrapped at 80 columns, however it is recommended that long argument lists be
broken up across multiple lines if doing so improves readability.

#### Symbol names and API design

New API should follow the rules documented in Swift's
[API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

Swift symbols that, for technical reasons, must be `public` but which are not
meant to be part of the testing library's public interface should be given two
leading underscores. For example:

```swift
public func __check()
```

Symbols marked `private` should be given a leading underscore to emphasize that
they are private. Symbols marked `fileprivate`, `internal`, etc. should not have
a leading underscore (except for those `public` symbols mentioned above.)

Exported C and C++ symbols that are exported should be given the prefix `swt_`
and should otherwise be named using the same lowerCamelCase naming rules as in
Swift. Use the `SWT_EXTERN` macro to ensure that symbols are consistently
visible in C, C++, and Swift. For example:

```c
SWT_EXTERN bool swt_isDebugModeEnabled(void);

SWT_EXTERN void swt_setDebugModeEnabled(bool isEnabled);
```

C and C++ types should be given the prefix `SWT` and should otherwise be named
using the same UpperCamelCase naming rules as in Swift. For example:

```c
typedef intmax_t SWTBigInteger;

typedef struct SWTContainer {
  ...
} SWTContainer;
```

#### Documenting symbols

Most symbols, including symbols marked `private`, should be given markup-style
documentation. Symbols that fulfill protocol requirements do not need to be
given additional documentation (the documentation in the protocol declaration is
generally sufficient.)

### Documentation

Documentation for the testing library should follow the
[Swift Book style guide](https://github.com/apple/swift-book/blob/main/Style.md)
and [Apple Style Guide](https://support.apple.com/guide/applestyleguide/) as
contextually appropriate.

#### Example applications, projects, and packages

In general, when an application, project, or package is needed for example code,
use "FoodTruck", an imaginary application that is based around the concept of a
mobile restaurant that sells various foods. When referencing foods in example
code, prefer foods that are recognizable to an international audience, or use a
set of different foods from multiple cultures.

Example code must be syntactically correct, but does not need to actually
compile, run, and perform meaningful work.

#### Language

Documentation should be written in U.S. English for an international audience.
Avoid culturally specific references unless they are specifically relevant to
the documentation.

- Note: Culturally insensitive and inappropriate language will not be tolerated.
  Refer to the [Swift Code of Conduct](https://swift.org/code-of-conduct) for
  more information.

#### Voice

Documentation should be written in a professional voice. The author and the
reader are not expected to know each other personally, so avoid overly familiar
terms or colloquialisms such as "let's."

When writing specific instructions that a reader must follow exactly in order to
accomplish a task, use the second person ("you", "your", etc.) Otherwise, avoid
using the second person.

#### Technical details

Documentation is encoded as UTF-8 using Markdown where possible.

Documentation should be wrapped at 80 columns, including code samples in
documentation where possible, so the reader does not need to scroll
horizontally. If documentation includes a long link, it does not need to be
split up over multiple lines, and a URL shortener should _not_ be used.
