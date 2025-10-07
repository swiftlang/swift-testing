//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if canImport(os.log)
private import os.log
#endif

@Suite(.serialized) struct `Test.Log Tests` {
  @Test func `Test.Log.Message.sourceLocation property`() {
    var message: Test.Log.Message = "abc123"
    message.sourceLocation = #_sourceLocation
    #expect(message.sourceLocation?.fileID == #fileID)
    #expect(message.sourceLocation?.filePath == #filePath)
    #expect(message.sourceContext.backtrace == nil)
  }

  @Test func `Test.Log.Message.description property`() {
    let message: Test.Log.Message = "abc123"
    #expect(String(describing: message) == "abc123")
  }

  @Test func `Test.Log.Message string interpolation`() {
    let message: Test.Log.Message = "abc\(123)"
    #expect(String(describing: message) == "abc123")
  }

  @Test func `Log a message (default severity)`() async {
    await confirmation("Issue recorded", expectedCount: 0) { issueRecorded in
      await confirmation("Message logged") { messageLogged in
        var configuration = Configuration()
        configuration.eventHandler = { event, eventContext in
          switch event.kind {
          case let .messageLogged(message):
            messageLogged()
            #expect(eventContext.test != nil)
            #expect(message.stringValue == "A message was logged.")
          case .issueRecorded:
            issueRecorded()
          default:
            break
          }
        }

        await Test {
          Test.Log.record("A message was logged.")
        }.run(configuration: configuration)
      }
    }
  }

  @Test func `Log message from external logging system (default severity)`() async {
    await confirmation("Issue recorded", expectedCount: 0) { issueRecorded in
      await confirmation("Message logged") { messageLogged in
        var configuration = Configuration()
        configuration.eventHandler = { event, eventContext in
          switch event.kind {
          case let .messageLogged(message):
            messageLogged()
            #expect(eventContext.test != nil)
            #expect(message.stringValue == "A message was logged.")
            #expect(message.sourceLocation == nil)
            #expect(message.sourceContext.backtrace != nil)
          case .issueRecorded:
            issueRecorded()
          default:
            break
          }
        }

        await Test {
          #fileID.withCString { fileID in
            #filePath.withCString { filePath in
              swift_testing_messageLogged("A message was logged.", 0, nil)
            }
          }
        }.run(configuration: configuration)
      }
    }
  }

  @Test func `Log message from external logging system (warning severity)`() async {
    await confirmation("Issue recorded") { issueRecorded in
      await confirmation("Message logged", expectedCount: 0) { messageLogged in
        var configuration = Configuration()
        configuration.eventHandler = { event, eventContext in
          switch event.kind {
          case .messageLogged:
            messageLogged()
          case let .issueRecorded(issue):
            issueRecorded()
            #expect(eventContext.test != nil)
            #expect(issue.severity == .warning)
          default:
            break
          }
        }

        await Test {
          #fileID.withCString { fileID in
            #filePath.withCString { filePath in
              swift_testing_messageLogged("A message was logged.", 1, nil)
            }
          }
        }.run(configuration: configuration)
      }
    }
  }

  @Test func `Log message from external logging system (error severity)`() async {
    await confirmation("Issue recorded") { issueRecorded in
      await confirmation("Message logged", expectedCount: 0) { messageLogged in
        var configuration = Configuration()
        configuration.eventHandler = { event, eventContext in
          switch event.kind {
          case .messageLogged:
            messageLogged()
          case let .issueRecorded(issue):
            issueRecorded()
            #expect(eventContext.test != nil)
            #expect(issue.severity == .error)
          default:
            break
          }
        }

        await Test {
          #fileID.withCString { fileID in
            #filePath.withCString { filePath in
              swift_testing_messageLogged("A message was logged.", 2, nil)
            }
          }
        }.run(configuration: configuration)
      }
    }
  }

#if canImport(os.log)
  @available(macOS 13.0, *)
  @Test func `os.Logger (info severity)`() async {
    await confirmation("Issue recorded", expectedCount: 0) { issueRecorded in
      await confirmation("Message logged") { messageLogged in
        var configuration = Configuration()
        configuration.eventHandler = { event, eventContext in
          switch event.kind {
          case let .messageLogged(message):
            messageLogged()
            #expect(eventContext.test != nil)
            #expect(message.stringValue == "A message was logged.")
            #expect(message.sourceLocation == nil)
            #expect(message.sourceContext.backtrace != nil)
          case .issueRecorded:
            issueRecorded()
          default:
            break
          }
        }

        await Test {
          let logger = os.Logger()
          logger.info("A message was logged.")
        }.run(configuration: configuration)
      }
    }
  }

  @available(macOS 13.0, *)
  @Test func `os.Logger (error severity)`() async {
    await confirmation("Issue recorded") { issueRecorded in
      await confirmation("Message logged", expectedCount: 0) { messageLogged in
        var configuration = Configuration()
        configuration.eventHandler = { event, eventContext in
          switch event.kind {
          case .messageLogged:
            messageLogged()
          case let .issueRecorded(issue):
            issueRecorded()
            #expect(eventContext.test != nil)
            #expect(issue.comments.first?.rawValue == "A message was logged.")
            #expect(issue.sourceLocation == nil)
            #expect(issue.sourceContext.backtrace != nil)
          default:
            break
          }
        }

        await Test {
          let logger = os.Logger()
          logger.error("A message was logged.")
        }.run(configuration: configuration)
      }
    }
  }
#endif
}
