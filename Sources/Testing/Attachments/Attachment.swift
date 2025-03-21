//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A type describing values that can be attached to the output of a test run
/// and inspected later by the user.
///
/// Attachments are included in test reports in Xcode or written to disk when
/// tests are run at the command line. To create an attachment, you need a value
/// of some type that conforms to ``Attachable``. Initialize an instance of
/// ``Attachment`` with that value and, optionally, a preferred filename to use
/// when writing to disk.
@_spi(Experimental)
public struct Attachment<AttachableValue>: ~Copyable where AttachableValue: Attachable & ~Copyable {
  /// Storage for ``attachableValue-7dyjv``.
  fileprivate var _attachableValue: AttachableValue

  /// The path to which the this attachment was written, if any.
  ///
  /// If a developer sets the ``Configuration/attachmentsPath`` property of the
  /// current configuration before running tests, or if a developer passes
  /// `--experimental-attachments-path` on the command line, then attachments
  /// will be automatically written to disk when they are attached and the value
  /// of this property will describe the path where they were written.
  ///
  /// If no destination path is set, or if an error occurred while writing this
  /// attachment to disk, the value of this property is `nil`.
  @_spi(ForToolsIntegrationOnly)
  public var fileSystemPath: String?

  /// The default preferred name to use if the developer does not supply one.
  package static var defaultPreferredName: String {
    "untitled"
  }

  /// Storage for ``preferredName``.
  fileprivate var _preferredName: String?

  /// A filename to use when writing this attachment to a test report or to a
  /// file on disk.
  ///
  /// The value of this property is used as a hint to the testing library. The
  /// testing library may substitute a different filename as needed. If the
  /// value of this property has not been explicitly set, the testing library
  /// will attempt to generate its own value.
  public var preferredName: String {
    let suggestedName = if let _preferredName, !_preferredName.isEmpty {
      _preferredName
    } else {
      Self.defaultPreferredName
    }
    return attachableValue.preferredName(for: self, basedOn: suggestedName)
  }

  /// The source location of this instance.
  ///
  /// This property is not part of the public interface of the testing library.
  /// It is initially set when the attachment is created and is updated later
  /// when the attachment is attached to something.
  ///
  /// The value of this property is used when recording issues associated with
  /// the attachment.
  var sourceLocation: SourceLocation
}

extension Attachment: Copyable where AttachableValue: Copyable {}
extension Attachment: Sendable where AttachableValue: Sendable {}

// MARK: - Initializing an attachment

#if !SWT_NO_LAZY_ATTACHMENTS
extension Attachment where AttachableValue: ~Copyable {
  /// Initialize an instance of this type that encloses the given attachable
  /// value.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of the
  ///     test run.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk. If `nil`, the testing library attempts to
  ///     derive a reasonable filename for the attached value.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  public init(_ attachableValue: consuming AttachableValue, named preferredName: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
    self._attachableValue = attachableValue
    self._preferredName = preferredName
    self.sourceLocation = sourceLocation
  }
}

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Attachment where AttachableValue == AnyAttachable {
  /// Create a type-erased attachment from an instance of ``Attachment``.
  ///
  /// - Parameters:
  ///   - attachment: The attachment to type-erase.
  fileprivate init(_ attachment: Attachment<some Attachable & Sendable & Copyable>) {
    self.init(
      _attachableValue: AnyAttachable(attachableValue: attachment.attachableValue),
      fileSystemPath: attachment.fileSystemPath,
      _preferredName: attachment._preferredName,
      sourceLocation: attachment.sourceLocation
    )
  }
}
#endif

/// A type-erased container type that represents any attachable value.
///
/// This type is not generally visible to developers. It is used when posting
/// events of kind ``Event/Kind/valueAttached(_:)``. Test tools authors who use
/// `@_spi(ForToolsIntegrationOnly)` will see instances of this type when
/// handling those events.
//
// @Comment {
//   Swift's type system requires that this type be at least as visible as
//   `Event.Kind.valueAttached(_:)`, otherwise it would be declared private.
// }
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public struct AnyAttachable: AttachableContainer, Copyable, Sendable {
#if !SWT_NO_LAZY_ATTACHMENTS
  public typealias AttachableValue = any Attachable & Sendable /* & Copyable rdar://137614425 */
#else
  public typealias AttachableValue = [UInt8]
#endif

  public var attachableValue: AttachableValue

  init(attachableValue: AttachableValue) {
    self.attachableValue = attachableValue
  }

  public var estimatedAttachmentByteCount: Int? {
    attachableValue.estimatedAttachmentByteCount
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    func open<T>(_ attachableValue: T, for attachment: borrowing Attachment<Self>) throws -> R where T: Attachable & Sendable & Copyable {
      let temporaryAttachment = Attachment<T>(
        _attachableValue: attachableValue,
        fileSystemPath: attachment.fileSystemPath,
        _preferredName: attachment._preferredName,
        sourceLocation: attachment.sourceLocation
      )
      return try temporaryAttachment.withUnsafeBufferPointer(body)
    }
    return try open(attachableValue, for: attachment)
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    func open<T>(_ attachableValue: T, for attachment: borrowing Attachment<Self>) -> String where T: Attachable & Sendable & Copyable {
      let temporaryAttachment = Attachment<T>(
        _attachableValue: attachableValue,
        fileSystemPath: attachment.fileSystemPath,
        _preferredName: attachment._preferredName,
        sourceLocation: attachment.sourceLocation
      )
      return temporaryAttachment.preferredName
    }
    return open(attachableValue, for: attachment)
  }
}

// MARK: - Describing an attachment

extension Attachment where AttachableValue: ~Copyable {
  public var description: String {
    let typeInfo = TypeInfo(describing: AttachableValue.self)
    return #""\#(preferredName)": instance of '\#(typeInfo.unqualifiedName)'"#
  }
}

extension Attachment: CustomStringConvertible {
  public var description: String {
    #""\#(preferredName)": \#(String(describingForTest: attachableValue))"#
  }
}

// MARK: - Getting an attachable value from an attachment

@_spi(Experimental)
extension Attachment where AttachableValue: ~Copyable {
  /// The value of this attachment.
  @_disfavoredOverload public var attachableValue: AttachableValue {
    _read {
      yield _attachableValue
    }
  }
}

@_spi(Experimental)
extension Attachment where AttachableValue: AttachableContainer & ~Copyable {
  /// The value of this attachment.
  ///
  /// When the attachable value's type conforms to ``AttachableContainer``, the
  /// value of this property equals the container's underlying attachable value.
  /// To access the attachable value as an instance of `T` (where `T` conforms
  /// to ``AttachableContainer``), specify the type explicitly:
  ///
  /// ```swift
  /// let attachableValue = attachment.attachableValue as T
  /// ```
  public var attachableValue: AttachableValue.AttachableValue {
    _read {
      yield attachableValue.attachableValue
    }
  }
}

// MARK: - Attaching an attachment to a test (etc.)

#if !SWT_NO_LAZY_ATTACHMENTS
extension Attachment where AttachableValue: Sendable & Copyable {
  /// Attach this instance to the current test.
  ///
  /// - Parameters:
  ///   - sourceLocation: The source location of the call to this function.
  ///
  /// An attachment can only be attached once.
  @_documentation(visibility: private)
  public consuming func attach(sourceLocation: SourceLocation = #_sourceLocation) {
    var attachmentCopy = Attachment<AnyAttachable>(self)
    attachmentCopy.sourceLocation = sourceLocation
    Event.post(.valueAttached(attachmentCopy))
  }
}
#endif

extension Attachment where AttachableValue: ~Copyable {
  /// Attach this instance to the current test.
  ///
  /// - Parameters:
  ///   - sourceLocation: The source location of the call to this function.
  ///
  /// When attaching a value of a type that does not conform to both
  /// [`Sendable`](https://developer.apple.com/documentation/swift/sendable) and
  /// [`Copyable`](https://developer.apple.com/documentation/swift/copyable),
  /// the testing library encodes it as data immediately. If the value cannot be
  /// encoded and an error is thrown, that error is recorded as an issue in the
  /// current test and the attachment is not written to the test report or to
  /// disk.
  ///
  /// An attachment can only be attached once.
  public consuming func attach(sourceLocation: SourceLocation = #_sourceLocation) {
    do {
      let attachmentCopy = try withUnsafeBufferPointer { buffer in
        let attachableContainer = AnyAttachable(attachableValue: Array(buffer))
        return Attachment<AnyAttachable>(
          _attachableValue: attachableContainer,
          fileSystemPath: fileSystemPath,
          _preferredName: preferredName, // invokes preferredName(for:basedOn:)
          sourceLocation: sourceLocation
        )
      }
      Event.post(.valueAttached(attachmentCopy))
    } catch {
      let sourceContext = SourceContext(backtrace: .current(), sourceLocation: sourceLocation)
      Issue(kind: .valueAttachmentFailed(error), comments: [], sourceContext: sourceContext).record()
    }
  }
}

// MARK: - Getting the serialized form of an attachable value (generically)

extension Attachment where AttachableValue: ~Copyable {
  /// Call a function and pass a buffer representing the value of this
  /// instance's ``attachableValue-2tnj5`` property to it.
  ///
  /// - Parameters:
  ///   - body: A function to call. A temporary buffer containing a data
  ///     representation of this instance is passed to it.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`, or any error that prevented the
  ///   creation of the buffer.
  ///
  /// The testing library uses this function when writing an attachment to a
  /// test report or to a file on disk. This function calls the
  /// ``Attachable/withUnsafeBufferPointer(for:_:)`` function on this
  /// attachment's ``attachableValue-2tnj5`` property.
  @inlinable public borrowing func withUnsafeBufferPointer<R>(_ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try attachableValue.withUnsafeBufferPointer(for: self, body)
  }
}

#if !SWT_NO_FILE_IO
// MARK: - Writing

extension Attachment where AttachableValue: ~Copyable {
  /// Write the attachment's contents to a file in the specified directory.
  ///
  /// - Parameters:
  ///   - directoryPath: The directory that should contain the attachment when
  ///     written.
  ///
  /// - Throws: Any error preventing writing the attachment.
  ///
  /// - Returns: The path to the file that was written.
  ///
  /// The attachment is written to a file _within_ `directoryPath`, whose name
  /// is derived from the value of the ``Attachment/preferredName`` property.
  ///
  /// If you pass `--experimental-attachments-path` to `swift test`, the testing
  /// library automatically uses this function to persist attachments to the
  /// directory you specify.
  ///
  /// This function does not get or set the value of the attachment's
  /// ``fileSystemPath`` property. The caller is responsible for setting the
  /// value of this property if needed.
  ///
  /// This function is provided as a convenience to allow tools authors to write
  /// attachments to persistent storage the same way that Swift Package Manager
  /// does. You are not required to use this function.
  @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
  public borrowing func write(toFileInDirectoryAtPath directoryPath: String) throws -> String {
    try write(
      toFileInDirectoryAtPath: directoryPath,
      appending: String(UInt64.random(in: 0 ..< .max), radix: 36)
    )
  }

  /// Write the attachment's contents to a file in the specified directory.
  ///
  /// - Parameters:
  ///   - directoryPath: The directory to which the attachment should be
  ///     written.
  ///   - usingPreferredName: Whether or not to use the attachment's preferred
  ///     name. If `false`, ``defaultPreferredName`` is used instead.
  ///   - suffix: A suffix to attach to the file name (instead of randomly
  ///     generating one.) This value may be evaluated multiple times.
  ///
  /// - Throws: Any error preventing writing the attachment.
  ///
  /// - Returns: The path to the file that was written.
  ///
  /// The attachment is written to a file _within_ `directoryPath`, whose name
  /// is derived from the value of the ``Attachment/preferredName`` property and
  /// the value of `suffix`.
  ///
  /// If the argument `suffix` always produces the same string, the result of
  /// this function is undefined.
  borrowing func write(toFileInDirectoryAtPath directoryPath: String, usingPreferredName: Bool = true, appending suffix: @autoclosure () -> String) throws -> String {
    let result: String

    let preferredName = usingPreferredName ? preferredName : Self.defaultPreferredName

    var file: FileHandle?
    do {
      // First, attempt to create the file with the exact preferred name. If a
      // file exists at this path (note "x" in the mode string), an error will
      // be thrown and we'll try again by adding a suffix.
      let preferredPath = appendPathComponent(preferredName, to: directoryPath)
      file = try FileHandle(atPath: preferredPath, mode: "wxb")
      result = preferredPath
    } catch {
      // Split the extension(s) off the preferred name. The first component in
      // the resulting array is our base name.
      var preferredNameComponents = preferredName.split(separator: ".")
      let firstPreferredNameComponent = preferredNameComponents[0]

      while true {
        preferredNameComponents[0] = "\(firstPreferredNameComponent)-\(suffix())"
        let preferredName = preferredNameComponents.joined(separator: ".")
        let preferredPath = appendPathComponent(preferredName, to: directoryPath)

        // Propagate any error *except* EEXIST, which would indicate that the
        // name was already in use (so we should try again with a new suffix.)
        do {
          file = try FileHandle(atPath: preferredPath, mode: "wxb")
          result = preferredPath
          break
        } catch let error as CError where error.rawValue == swt_EEXIST() {
          // Try again with a new suffix.
          continue
        } catch where usingPreferredName {
          // Try again with the default name before giving up.
          return try write(toFileInDirectoryAtPath: directoryPath, usingPreferredName: false, appending: suffix())
        }
      }
    }

    // There should be no code path that leads to this call where the attachable
    // value is nil.
    try withUnsafeBufferPointer { buffer in
      try file!.write(buffer)
    }

    return result
  }
}

extension Configuration {
  /// Handle the given "value attached" event.
  ///
  /// - Parameters:
  ///   - event: The event to handle. This event must be of kind
  ///     ``Event/Kind/valueAttached(_:)``. If the associated attachment's
  ///     ``Attachment/fileSystemPath`` property is not `nil`, this function
  ///     does nothing.
  ///   - context: The context associated with the event.
  ///
  /// - Returns: Whether or not to continue handling the event.
  ///
  /// This function is called automatically by ``handleEvent(_:in:)``. You do
  /// not need to call it elsewhere. It automatically persists the attachment
  /// associated with `event` and modifies `event` to include the path where the
  /// attachment was stored.
  func handleValueAttachedEvent(_ event: inout Event, in eventContext: borrowing Event.Context) -> Bool {
    guard let attachmentsPath else {
      // If there is no path to which attachments should be written, there's
      // nothing to do here. The event handler may still want to handle it.
      return true
    }

    guard case let .valueAttached(attachment) = event.kind else {
      preconditionFailure("Passed the wrong kind of event to \(#function) (expected valueAttached, got \(event.kind)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }
    if attachment.fileSystemPath != nil {
      // Somebody already persisted this attachment. This isn't necessarily a
      // logic error in the testing library, but it probably means we shouldn't
      // persist it again. Suppress the event.
      return false
    }

    do {
      // Write the attachment.
      var attachment = attachment
      attachment.fileSystemPath = try attachment.write(toFileInDirectoryAtPath: attachmentsPath)

      // Update the event before returning and continuing to handle it.
      event.kind = .valueAttached(attachment)
      return true
    } catch {
      // Record the error as an issue and suppress the event.
      let sourceContext = SourceContext(backtrace: .current(), sourceLocation: attachment.sourceLocation)
      Issue(kind: .valueAttachmentFailed(error), comments: [], sourceContext: sourceContext).record(configuration: self)
      return false
    }
  }
}
#endif
