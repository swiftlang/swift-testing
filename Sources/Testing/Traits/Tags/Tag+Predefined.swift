//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

// MARK: Primary colors

extension Tag {
  /// A tag representing the color red.
  public static var red: Self {
    Tag(kind: .staticMember("red"))
  }

  /// A tag representing the color orange.
  public static var orange: Self {
    Tag(kind: .staticMember("orange"))
  }

  /// A tag representing the color yellow.
  public static var yellow: Self {
    Tag(kind: .staticMember("yellow"))
  }

  /// A tag representing the color green.
  public static var green: Self {
    Tag(kind: .staticMember("green"))
  }

  /// A tag representing the color blue.
  public static var blue: Self {
    Tag(kind: .staticMember("blue"))
  }

  /// A tag representing the color purple.
  public static var purple: Self {
    Tag(kind: .staticMember("purple"))
  }

  /// Whether or not this tag represents a color predefined by the testing
  /// library.
  ///
  /// Predefined color tags are any of these values:
  ///
  /// - ``Tag/red``
  /// - ``Tag/orange``
  /// - ``Tag/yellow``
  /// - ``Tag/green``
  /// - ``Tag/blue``
  /// - ``Tag/purple``
  public var isPredefinedColor: Bool {
    switch self {
    case .red, .orange, .yellow, .green, .blue, .purple:
      return true
    default:
      return false
    }
  }
}

// MARK: - Predefined tag hard-coded colors

extension Tag.Color {
  /// The set of predefined tag colors used by ``ConsoleOutputRecorder``.
  ///
  /// Tags in this set will have colors automatically applied to them in console
  /// output even if a user has not specified a color in e.g. a tag-colors.json
  /// file. New predefined tag colors should be rare as they are inherently
  /// subjective for most tags.
  static var predefined: [Tag: Self] {
    [
      .red: .red, .orange: .orange, .yellow: .yellow,
      .green: .green, .blue: .blue, .purple: .purple,

      // As a fun little reminder of Apple history, we provide predefined tag
      // colors for the original System 7 labels. If a test author explicitly
      // creates one of these tags and adds it to a test, we will use the
      // original label's color for it. These colors are (as determined by
      // manually inspecting Finder's 'pltt' resource #128):
      //
      // Essential = Orange = 65535, 25738, 652
      // Hot = Red = 56680, 2242, 1698
      // In Progress = Magenta = 62167, 2134, 34028
      // Cool = Cyan = 577, 43860, 60159
      // Personal = Blue = 0, 0, 54272
      // Project1 = Green = 0, 25765, 4541
      // Project2 = Brown = 22016, 11421, 1316
      //
      // To convert them to 8-bit RGB values, we divide them by 65535, multiply
      // them by 255, then round to the nearest integer.
      Tag(kind: .staticMember("essential")): .rgb(255, 100, 3),
      Tag(kind: .staticMember("hot")): .rgb(221, 9, 7),
      Tag(kind: .staticMember("inProgress")): .rgb(242, 8, 132),
      Tag(kind: .staticMember("cool")): .rgb(2, 171, 234),
      Tag(kind: .staticMember("personal")): .rgb(0, 0, 211),
      Tag(kind: .staticMember("project1")): .rgb(0, 100, 18),
      Tag(kind: .staticMember("project2")): .rgb(86, 44, 5),
    ]
  }
}
