//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Tag {
  /// An enumeration describing colors that can be applied to tests' tags.
  ///
  /// ## See Also
  ///
  /// - <doc:AddingTags>
  @_spi(ExperimentalEventHandling)
  public struct Color: Sendable {
    /// The red component of the color.
    ///
    /// This property is not part of the public interface of the testing
    /// library as we may wish to support non-RGB color spaces in the future.
    var redComponent: UInt8

    /// The green component of the color.
    ///
    /// This property is not part of the public interface of the testing
    /// library as we may wish to support non-RGB color spaces in the future.
    var greenComponent: UInt8

    /// The blue component of the color.
    ///
    /// This property is not part of the public interface of the testing
    /// library as we may wish to support non-RGB color spaces in the future.
    var blueComponent: UInt8

    /// The color red.
    public static var red: Self { .rgb(255, 0, 0) }

    /// The color orange.
    public static var orange: Self { .rgb(255, 128, 0) }

    /// The color yellow.
    public static var yellow: Self { .rgb(255, 255, 0) }

    /// The color green.
    public static var green: Self { .rgb(0, 255, 0) }

    /// The color blue.
    public static var blue: Self { .rgb(0, 0, 255) }

    /// The color purple.
    public static var purple: Self { .rgb(192, 0, 224) }

    /// Get an instance of this type representing a custom color in the RGB
    /// color space.
    ///
    /// - Parameters:
    ///   - redComponent: The red component of the color.
    ///   - greenComponent: The green component of the color.
    ///   - blueComponent: The blue component of the color.
    ///
    /// - Returns: An instance of this type representing the specified color.
    ///
    /// If a tag with an RGB color is output to a terminal that does not support
    /// 256-color (or better) output, the color will not be displayed.
    public static func rgb(_ redComponent: UInt8, _ greenComponent: UInt8, _ blueComponent: UInt8) -> Self {
      self.init(redComponent: redComponent, greenComponent: greenComponent, blueComponent: blueComponent)
    }
  }
}

// MARK: - Equatable, Hashable

extension Tag.Color: Equatable, Hashable {}

// MARK: - Comparable

extension Tag.Color: Comparable {
  /// The index of this color, relative to other colors.
  ///
  /// The value of this property can be used for sorting color tags distinctly
  /// from other (string-based) tags.
  private var _colorIndex: UInt32 {
    // Sort RGB colors such that bluer values are ordered after redder ones.
    // (We might want to change this logic to sort by computed hue.)
    (UInt32(blueComponent) << 16) | (UInt32(greenComponent) << 8) | UInt32(redComponent)
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
    lhs._colorIndex < rhs._colorIndex
  }
}

// MARK: - Comparable

extension Tag.Color: Decodable {
  public init(from decoder: any Decoder) throws {
    let stringValue = try String(from: decoder)
    switch stringValue {
    case "red":
      self = .red
    case "orange":
      self = .orange
    case "yellow":
      self = .yellow
    case "green":
      self = .green
    case "blue":
      self = .blue
    case "purple":
      self = .purple
    case _ where stringValue.count == 7 && stringValue.first == "#":
      guard let rgbValue = UInt32(stringValue.dropFirst(), radix: 16) else {
        fallthrough
      }
      self = .rgb(
        UInt8((rgbValue & 0x00FF0000) >> 16),
        UInt8((rgbValue & 0x0000FF00) >> 8),
        UInt8((rgbValue & 0x000000FF) >> 0)
      )
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Unsupported tag color constant \"\(stringValue)\"."
        )
      )
    }
  }
}

// MARK: - Predefined color tags

extension Tag {
  /// A tag representing the color red.
  @Tag public static var red: Self

  /// A tag representing the color orange.
  @Tag public static var orange: Self

  /// A tag representing the color yellow.
  @Tag public static var yellow: Self

  /// A tag representing the color green.
  @Tag public static var green: Self

  /// A tag representing the color blue.
  @Tag public static var blue: Self

  /// A tag representing the color purple.
  @Tag public static var purple: Self

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

