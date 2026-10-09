//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that can perform basic parsing of command-line arguments.
///
/// The testing library uses this type to parse command-line arguments in its
/// entry point function and in its associated executable targets.
///
/// - Important: This type is provided because the testing library cannot link
///   directly to Swift Argument Parser. Other tools and libraries should
///   generally prefer to use Swift Argument Parser and should not use or copy
///   this type or its logic.
@_spi(ForToolsIntegrationOnly)
public struct CommandLineArgumentList: Sendable {
  /// An enumeration describing how to handle a command-line argument.
  public enum Descriptor: Sendable, Equatable, Hashable {
    /// An argument that has no label.
    case anonymous

    /// A subcommand argument (one that does not take a value and does not start
    /// with a dash character).
    ///
    /// - Parameters:
    ///   - commandName: The name of the subcommand.
    ///
    /// The testing library does not enforce that subcommand arguments must come
    /// before other arguments.
    case subcommand(_ commandName: String)

    /// An argument that takes a value.
    ///
    /// - Parameters:
    ///   - label: The option's label, including leading dashes.
    ///
    /// If an option is specified more than once, the testing library builds an
    /// array of values for that option in the order the values are parsed.
    case option(_ label: String)

    /// An argument that does not take a value.
    ///
    /// - Parameters:
    ///   - label: The flag's label, including leading dashes.
    ///
    /// The testing library does not enforce that a flag can only be specified
    /// once.
    case flag(_ label: String)

    /// The argument's label, if any.
    fileprivate var label: String? {
      switch self {
      case .anonymous, .subcommand:
        nil
      case let .option(label), let .flag(label):
        label
      }
    }
  }

  /// Storage for ``anonymousArgumentValues``.
  private var _anonymousArgumentValues: [String] = []

  /// Storage for ``subcommandNames``.
  private var _subcommandNames: [String] = []

  /// Storage for ``option(withLabel:)`` and ``options(withLabel:)``.
  private var _options: [String: [String]] = [:]

  /// Storage for ``hasFlag(withLabel:)``.
  private var _flags: Set<String> = []

  /// Parse a single argument.
  ///
  /// - Parameters:
  ///   - arg: The argument to parse.
  ///   - descriptors: An array of argument descriptors that tell the testing
  ///     library how to handle `arg` and other arguments.
  ///   - describeUnrecognizedArgument: A closure to call if `arg` is not
  ///     recognized.
  ///   - getValue: A closure to call to get the value of the argument if it is
  ///     an option (i.e. takes a value).
  ///
  /// - Returns: A tuple containing the argument descriptor matching `arg` and,
  ///   if `arg` is anonymous or is an option, its value.
  ///
  /// - Throws: Any error that occurs while parsing `arg`.
  private static func _parseArgument(
    _ arg: String,
    describedBy descriptors: [Descriptor],
    describingUnrecognizedArgumentWith describeUnrecognizedArgument: ((String) throws -> Descriptor)?,
    gettingValueWith getValue: () -> String?
  ) throws -> (descriptor: Descriptor, value: String?) {
    var descriptor: Descriptor?
    var value: String?

    // Find a descriptor matching the raw argument string.
    if arg.first == "-" {
      // Looks like an argument label like -f or --foo.
      descriptor = descriptors.first { $0.label == arg }
      if descriptor == nil,
         case let splitByEquals = arg.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false),
         splitByEquals.count > 1 {
        // It appears to be of the form "--foo=bar".
        let label = String(splitByEquals[0])
        let possibleDescriptor: Descriptor = .option(label)
        if descriptors.contains(possibleDescriptor) {
          descriptor = possibleDescriptor
          value = String(splitByEquals[1])
        }
      }
    } else {
      descriptor = descriptors.first { $0 == .subcommand(arg) }
      if descriptor == nil && descriptors.contains(.anonymous) {
        descriptor = .anonymous
      }
    }

    // If we couldn't find a matching descriptor, ask the fallback callback (!)
    // for one before we give up and throw.
    if descriptor == nil {
      descriptor = try describeUnrecognizedArgument?(arg)
    }
    guard let descriptor else {
      throw ParseError.unexpectedArgument(arg)
    }


    // If the argument is an option, it must have a value. If we haven't already
    // split one out of the raw argument string (e.g. "--foo=bar"), get the
    // value from the callback.
    switch descriptor {
    case .anonymous:
      value = arg
    case let .option(label):
      if value == nil {
        value = getValue()
      }
      if value == nil {
        throw ParseError.missingValue(label: label)
      }
    default:
      assert(value == nil, "Set a value when parsing an argument '\(arg)' that shouldn't have one. \(fileABugMessage)")
    }

    return (descriptor, value)
  }

  /// Initialize an instance of this type by parsing the given sequence of
  /// command-line arguments.
  ///
  /// - Parameters:
  ///   - arguments: A sequence of command-line arguments. The first element of
  ///     the sequence is assumed to be the program name and is discarded
  ///     automatically.
  ///   - descriptors: An array of argument descriptors that tell the testing
  ///     library how to handle the strings in `arguments`.
  ///   - describeUnrecognizedArgument: A closure to call if an unrecognized
  ///     argument is found in `arguments`. This function can customize how the
  ///     testing library handles that argument, or throw an error if it is not
  ///     supported. If `nil`, unrecognized arguments cause this initializer to
  ///     throw an error.
  ///
  /// - Throws: Any error that occurs while parsing `arguments`.
  init(
    parsing arguments: some Sequence<String>,
    describedBy descriptors: [Descriptor],
    describingUnrecognizedArgumentWith describeUnrecognizedArgument: ((String) throws -> Descriptor)? = nil
  ) throws {
    var i = arguments.makeIterator()
    _ = i.next() // drop argv[0]
    while let arg = i.next() {
      let (descriptor, value) = try Self._parseArgument(
        arg,
        describedBy: descriptors,
        describingUnrecognizedArgumentWith: describeUnrecognizedArgument,
        gettingValueWith: { i.next() }
      )
      switch descriptor {
      case .anonymous:
        _anonymousArgumentValues.append(value!)
      case let .subcommand(subcommandName):
        _subcommandNames.append(subcommandName)
      case let .option(label):
        _options[label, default: []].append(value!)
      case let .flag(label):
        _flags.insert(label)
      }
    }
  }
}

// MARK: - Getting parsed arguments

extension CommandLineArgumentList {
  /// All anonymous argument values found during argument parsing.
  ///
  /// For example, given the following command line parsed with appropriate
  /// descriptors:
  ///
  /// ```sh
  /// ./mytool --foo bar abc 123
  /// ```
  ///
  /// The value of this property would be `["abc", "123"]`.
  public var anonymousArgumentValues: [String] {
    _anonymousArgumentValues
  }

  /// All subcommand names found during argument parsing, in the order they were
  /// found.
  ///
  /// For example, given the following command line parsed with appropriate
  /// descriptors (in particular, with the descriptor `.subcommand("abc")`:
  ///
  /// ```sh
  /// ./mytool --foo bar abc 123
  /// ```
  ///
  /// The value of this property would be `["abc"]`.
  public var subcommandNames: [String] {
    _subcommandNames
  }

  /// Get the first value found during argument parsing for the option with the
  /// given label.
  ///
  /// - Parameters:
  ///   - label: The option's label, including leading dashes.
  ///
  /// - Returns: The first value found for the given option, or `nil` if none
  ///   was found during parsing.
  ///
  /// For example, given the following command line parsed with appropriate
  /// descriptors:
  ///
  /// ```sh
  /// ./mytool --foo bar --foo baz --quux 123
  /// ```
  ///
  /// For the label `"foo"`, the result is `"bar"`.
  public func option(withLabel label: String) -> String? {
    _options[label]?.first
  }

  /// Get all values found during argument parsing for the option with the
  /// given label, in the order they were found.
  ///
  /// - Parameters:
  ///   - label: The option's label, including leading dashes.
  ///
  /// - Returns: An array of values found for the given option, or the empty
  ///   array if none was found during parsing.
  ///
  /// For example, given the following command line parsed with appropriate
  /// descriptors:
  ///
  /// ```sh
  /// ./mytool --foo bar --foo baz --quux 123
  /// ```
  ///
  /// For the label `"foo"`, the result is `["bar", "baz"]`.
  public func options(withLabel label: String) -> [String] {
    _options[label, default: []]
  }

  /// Check whether the given flag was found during argument parsing.
  ///
  /// - Parameters:
  ///   - label: The flag's label, including leading dashes.
  ///
  /// - Returns: Whether or not the given flag was found during parsing.
  ///
  /// For example, given the following command line:
  ///
  /// ```sh
  /// ./mytool --make-grommet --eat-pizza
  /// ```
  ///
  /// For the label `"--make-grommet"`, the result is `true`, and for the label
  /// `"--unwrap-present"`, the result is `false`.
  public func hasFlag(withLabel label: String) -> Bool {
    _flags.contains(label)
  }
}

// MARK: -

extension CommandLineArgumentList {
  /// Errors thrown by ``CommandLineArgumentList`` when parsing fails.
  enum ParseError: Error, Equatable {
    /// The testing library encountered an unexpected argument.
    ///
    /// - Parameters:
    ///   - arg: The unexpected argument.
    case unexpectedArgument(_ arg: String)

    /// The testing library encountered an option with no value specified.
    ///
    /// - Parameters:
    ///   - label: The option's label.
    case missingValue(label: String)
  }
}

extension CommandLineArgumentList.ParseError: CustomStringConvertible {
  var description: String {
    switch self {
    case let .unexpectedArgument(arg):
      #"Unexpected argument "\#(arg)"."#
    case let .missingValue(label):
      #"Missing value for argument "\#(label)"."#
    }
  }
}
