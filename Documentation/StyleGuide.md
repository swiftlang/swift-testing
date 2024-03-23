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

When writing an abstract for a symbol, start the abstract with either a noun or
a verb ending in "s" depending on what kind of symbol it is:
|   Noun               |   Verb ending in *s*      |
|----------------------|---------------------------|
| Associated type      | Enumerations |
| Class                | Function and function macro |
| Constant             | Initializer |
| Enumerated types     | Macro |
| Property             | Method |
| Protocol             | Subscript |
| Structure            |  |
| Type alias           |  |
| Variable             |  |

For instance, when writing the abstract for a class `Order`, you could write:
<blockquote>
An object that stores the details for a specific order from a vendor.
</blockquote>

Or when writing the abstract for an enumeration `Flavor`, you could write:
<blockquote>
Describes the flavors of an an ingredient.
</blockquote>

To organize symbols under types, place them in topic groups organized by usage.
Begin topic group headings insides types with a nound or noun phrase.

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

Example code must be syntactically correct and the author should confirm it can
compile and run within an appropriate context. It can rely on external
dependencies that you exclude as long as those dependencies are easy for
the reader to understand, and create or replace.

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
accomplish a task, use the second person ("you", "your", etc.).

#### Articles

When writing articles or curating content, keep the structure simple and
relatively flat. Place articles in topic groups alongside the symbols.

Some basic rules to follow when creating an article are:
- Begin an article title with a _gerund_ (a verb ending in "ing").
- After the title, include a single sentence that begins with a verb and quickly
describes what the article covers.
- Include an overview to serve as an introduction to the article. If required,
include any setup or configuration tasks as a part of your overview.
- Start section headings with an imperative verb.
- Always follow a section heading with some text to setup the code or problem
you want to solve.
- Match the names of articles and the files that contain them using kebab-case.

#### API collections

To organize related subsets of symbols, articles, and other content, use an API
collection.

Some basic rules to follow when creating an API collections are:
- Begin the collection title with a noun that describes what the items in the
collection have in common.
- After the title, include a single sentence that describes the items in the
collection.
- Optionally, include an overview to the collection.
- Organize the symbols under topic group headings. Begin a topic group heading
with a gerund.
- Match the names of a collections and the files that contain them using kebab-case.

#### Technical details

Documentation is encoded as UTF-8 using Markdown where possible.

Documentation should be wrapped at 80 columns, including code samples in
documentation where possible, so the reader does not need to scroll
horizontally. If documentation includes a long link, it does not need to be
split up over multiple lines, and a URL shortener should _not_ be used.
