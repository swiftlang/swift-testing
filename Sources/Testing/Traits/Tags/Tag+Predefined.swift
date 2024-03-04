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

// MARK: - System 7 labels

@_spi(Experimental)
extension Tag {
  /// A predefined tag.
  ///
  /// The name of this tag is taken from the default set of labels in Macintosh
  /// System&nbsp;7.
  public static var essential: Self {
    Tag(kind: .staticMember("essential"))
  }

  /// A predefined tag.
  ///
  /// The name of this tag is taken from the default set of labels in Macintosh
  /// System&nbsp;7.
  public static var hot: Self {
    Tag(kind: .staticMember("hot"))
  }

  /// A predefined tag.
  ///
  /// The name of this tag is taken from the default set of labels in Macintosh
  /// System&nbsp;7.
  public static var inProgress: Self {
    Tag(kind: .staticMember("inProgress"))
  }

  /// A predefined tag.
  ///
  /// The name of this tag is taken from the default set of labels in Macintosh
  /// System&nbsp;7.
  public static var cool: Self {
    Tag(kind: .staticMember("cool"))
  }

  /// A predefined tag.
  ///
  /// The name of this tag is taken from the default set of labels in Macintosh
  /// System&nbsp;7.
  public static var personal: Self {
    Tag(kind: .staticMember("personal"))
  }

  /// A predefined tag.
  ///
  /// The name of this tag is taken from the default set of labels in Macintosh
  /// System&nbsp;7.
  public static var project1: Self {
    Tag(kind: .staticMember("project1"))
  }

  /// A predefined tag.
  ///
  /// The name of this tag is taken from the default set of labels in Macintosh
  /// System&nbsp;7.
  public static var project2: Self {
    Tag(kind: .staticMember("project2"))
  }
}

// MARK: - Predefined tag hard-coded colors

extension Tag.Color {
  /// The set of predefined tag colors used by ``ConsoleOutputRecorder``.
  static var predefined: [Tag: Self] {
    [
      .red: .red, .orange: .orange, .yellow: .yellow,
      .green: .green, .blue: .blue, .purple: .purple,

      // The original System 7 label colors are:
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
      .essential: .rgb(255, 100, 3),
      .hot: .rgb(221, 9, 7),
      .inProgress: .rgb(242, 8, 132),
      .cool: .rgb(2, 171, 234),
      .personal: .rgb(0, 0, 211),
      .project1: .rgb(0, 100, 18),
      .project2: .rgb(86, 44, 5),
    ]
  }
}
