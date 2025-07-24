//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Foundation

extension Event {
  /// A hierarchical console output recorder that renders test results in a tree structure
  /// after all tests have completed, following strict formatting specifications.
  ///
  /// This recorder implements:
  /// - Post-run buffering with complete tree rendering after final event
  /// - Unicode box-drawing characters (│, ├─, ╰─) for tree visualization
  /// - Four distinct line types: Suite Header, Test Case, Issue Sub-Node, Suite Summary
  /// - 3-space indentation per hierarchy level
  /// - Right-aligned duration formatting
  /// - Thread-safe concurrent event handling
  @_spi(Experimental)
  public struct AdvancedConsoleOutputRecorder: Sendable {
    /// Configuration options for the hierarchical console output recorder.
    public struct Options: Sendable {
      public var base: Event.ConsoleOutputRecorder.Options
      public var useHierarchicalOutput: Bool
      public var showSuccessfulTests: Bool
      
      public init() {
        self.base = Event.ConsoleOutputRecorder.Options()
        self.useHierarchicalOutput = true
        self.showSuccessfulTests = true
      }
    }
    
    /// The options for this recorder.
    public let options: Options
    
    public let write: @Sendable (String) -> Void
    
    private struct HierarchyNode: Sendable {
      let id: Test.ID
      let name: String
      let displayName: String?
      let isSuite: Bool
      var status: NodeStatus = .running
      var startTime: Test.Clock.Instant?
      var endTime: Test.Clock.Instant?
      var issues: [IssueInfo] = []
      var children: [String] = [] // Child node IDs
      var parent: String? // Parent node ID
      
      enum NodeStatus: Sendable {
        case running
        case passed
        case failed
        case skipped
        case passedWithKnownIssues(count: Int)
        case passedWithWarnings(count: Int)
      }
      
      struct IssueInfo: Sendable {
        let issue: Issue
        let isKnown: Bool
        let summary: String
      }
    }
    
    private struct HierarchyContext {
      var nodes: [String: HierarchyNode] = [:]
      var rootNodes: [String] = []
      var runStartTime: Test.Clock.Instant?
      var runEndTime: Test.Clock.Instant?
      var isRunCompleted: Bool = false
      var totalPassed: Int = 0
      var totalFailed: Int = 0
      var totalSkipped: Int = 0
      var totalKnownIssues: Int = 0
      var totalWarnings: Int = 0
      
      var symbolCounts: [String: Int] = [
        "pass": 0,
        "fail": 0,
        "passWithKnownIssues": 0,
        "passWithWarnings": 0,
        "skip": 0,
        "difference": 0,
        "warning": 0,
        "details": 0,
        "attachment": 0
      ]
    }
    
    /// Thread-safe access to hierarchy context
    private let _context = Locked(rawValue: HierarchyContext())
    
    /// Initialize the hierarchical console output recorder.
      public init(options: Options = Options(), writingUsing write: @escaping @Sendable (String) -> Void) {
    self.options = options
    self.write = write
    Self.setupSignalHandlers()
  }
  }
}

extension Event.AdvancedConsoleOutputRecorder {
    // --- Live Phase State ---
    private struct LivePhaseState: Sendable {
        var runStartedAt: Test.Clock.Instant? = nil
        var lastProgressUpdate: Test.Clock.Instant? = nil
        var progressBarShown: Bool = false
        var totalTests: Int = 0
        var completedTests: Int = 0
        var passed: Int = 0
        var failed: Int = 0
        var warnings: Int = 0
        var knownIssues: Int = 0
        var skipped: Int = 0
        var erasedProgressBar: Bool = false
        let progressBarThrottle: UInt64 = 100_000_000 // 100ms in nanoseconds
        let progressBarDelay: UInt64 = 1_000_000 // 1ms in nanoseconds 
    }
    
    private static let _livePhaseState = Locked(rawValue: LivePhaseState())
    @MainActor private static var _signalHandler: (any DispatchSourceSignal)?
    @MainActor private static var _hasActiveRecorder: Bool = false

    private func updateLiveStats(event: Event, context: Event.Context) {
        Self._livePhaseState.withLock { state in
            switch event.kind {
            case .runStarted:
                state.runStartedAt = event.instant
                state.lastProgressUpdate = nil
                state.progressBarShown = false
                state.completedTests = 0
                state.passed = 0
                state.failed = 0
                state.warnings = 0
                state.knownIssues = 0
                state.skipped = 0
                state.erasedProgressBar = false
                state.totalTests = 0
            case .testStarted:
                if let test = context.test, !test.isSuite {
                    state.totalTests += 1
                }
            case .testEnded:
                if let test = context.test, !test.isSuite {
                    state.completedTests += 1
                }
            case .issueRecorded(let issue):
                if issue.isKnown {
                    state.knownIssues += 1
                } else {
                    switch issue.severity {
                    case .warning:
                        state.warnings += 1
                    case .error:
                        state.failed += 1
                    }
                }
            case .testSkipped:
                if let test = context.test, !test.isSuite {
                    state.skipped += 1
                    state.completedTests += 1
                }
            default:
                break
            }
        }
    }
    
    private func updatePassedCount() {
        Self._livePhaseState.withLock { state in
            state.passed = state.completedTests - state.failed - state.skipped
        }
    }

    private func shouldShowProgressBar(currentInstant: Test.Clock.Instant) -> Bool {
        return Self._livePhaseState.withLock { state in
            guard let started = state.runStartedAt else { return false }
            let elapsed = started.nanoseconds(until: currentInstant)
            return elapsed > state.progressBarDelay
        }
    }

    private func shouldThrottleProgressBar(currentInstant: Test.Clock.Instant) -> Bool {
        return Self._livePhaseState.withLock { state in
            guard let last = state.lastProgressUpdate else { return false }
            let elapsed = last.nanoseconds(until: currentInstant)
            return elapsed < state.progressBarThrottle
        }
    }

    private func printProgressBar(at instant: Test.Clock.Instant) {
        Self._livePhaseState.withLock { state in
            let total = max(state.totalTests, state.completedTests)
            let progress = "PROGRESS [\(state.completedTests)/\(total)] | ✓ Passed: \(state.passed) | ✗ Failed: \(state.failed) | ? Warnings: \(state.warnings) | ~ Known: \(state.knownIssues) | → Skipped: \(state.skipped)"
            // Clear line and write progress (without newline to keep it on same line)
            write("\r\u{001B}[K\(progress)")
            state.progressBarShown = true
            state.lastProgressUpdate = instant
        }
    }

    private func eraseProgressBar() {
        Self._livePhaseState.withLock { state in
            if state.progressBarShown && !state.erasedProgressBar {
                write("\r\u{001B}[K\n")  // Clear the progress bar line and add empty line
                state.progressBarShown = false
                state.erasedProgressBar = true
            }
        }
    }

    private func printLiveFailure(icon: String, testName: String, summary: String, at instant: Test.Clock.Instant) {
        let wasProgressBarShown = Self._livePhaseState.withLock { $0.progressBarShown }
        if wasProgressBarShown {
            write("\r\u{001B}[K")
        }
        write("\(icon) \(testName): \(summary)\n")
        if wasProgressBarShown {
            printProgressBar(at: instant)
        }
    }

    public func handle(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
      updateLiveStats(event: event, context: eventContext)
      
      // Live failure reporting
      if case .issueRecorded(let issue) = event.kind, !issue.isKnown {
          if let test = eventContext.test {
              let icon: String
              switch issue.severity {
              case .warning: icon = "?"
              case .error: icon = "✗"
              }
              let testName = test.id.keyPathRepresentation.joined(separator: ".")
              let summary = formatIssueSummary(issue)
              printLiveFailure(icon: icon, testName: testName, summary: summary, at: event.instant)
          }
      }
      
      let shouldShow = shouldShowProgressBar(currentInstant: event.instant)
      let isThrottled = shouldThrottleProgressBar(currentInstant: event.instant)
      let isRunEnded = if case .runEnded = event.kind { true } else { false }
      
      // Show progress bar on relevant events
      if shouldShow && !isThrottled && !isRunEnded {
          updatePassedCount()
          printProgressBar(at: event.instant)
      }
      
      // On runEnded, erase progress bar before summary
      if isRunEnded {
          eraseProgressBar()
      }
      
      // Continue with normal hierarchical buffering/summary
      if options.useHierarchicalOutput {
        handleHierarchicalEvent(event, in: eventContext)
      } else {
        // Fallback to regular console output  
        let consoleRecorder = Event.ConsoleOutputRecorder(options: options.base, writingUsing: write)
        consoleRecorder.record(event, in: eventContext)
      }
    }
  
  private func handleHierarchicalEvent(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    switch event.kind {
    case .runStarted:
      handleRunStarted(event)
      
    case .testStarted:
      guard let test = eventContext.test else { return }
      handleTestStarted(test, at: event.instant)
      
    case .testEnded:
      guard let test = eventContext.test else { return }
      handleTestEnded(test, at: event.instant)
      
    case .issueRecorded(let issue):
      handleIssueRecorded(issue, at: event.instant, in: eventContext)
      
    case .testSkipped(let skipInfo):
      guard let test = eventContext.test else { return }
      handleTestSkipped(test, skipInfo: skipInfo, at: event.instant)
      
    case .runEnded:
      handleRunEnded(event)
      
    default:
      break
    }
  }
  
  private func handleRunStarted(_ event: borrowing Event) {
    _context.withLock { context in
      context.runStartTime = event.instant
      context.isRunCompleted = false
    }
    
    write("\n")
    
    let symbol = Event.Symbol.default.stringValue(options: options.base)
    write("\(symbol) Running tests...")
    
    write("\n")
  }
  
  private func handleTestStarted(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      var pathComponents = test.id.keyPathRepresentation
      let isSuite = test.isSuite
      
      if !isSuite && pathComponents.count > 3 {
        let lastComponent = pathComponents.last!
        if lastComponent.contains(".swift:") {
          pathComponents = Array(pathComponents.dropLast())
        }
      }
      
      let nodeId = pathComponents.joined(separator: ".")
      

      
      let node = HierarchyNode(
        id: test.id,
        name: test.name,
        displayName: test.displayName,
        isSuite: isSuite,
        status: .running,
        startTime: instant,
        endTime: nil,
        issues: [],
        children: [],
        parent: nil
      )
      
      context.nodes[nodeId] = node
      
      for i in 1..<pathComponents.count {
        let intermediatePath = pathComponents.prefix(i).joined(separator: ".")
        if context.nodes[intermediatePath] == nil {
          let intermediateNode = HierarchyNode(
            id: test.id,
            name: pathComponents[i-1],
            displayName: nil,
            isSuite: true,
            status: .running,
            startTime: instant,
            endTime: nil,
            issues: [],
            children: [],
            parent: nil
          )
          context.nodes[intermediatePath] = intermediateNode
        }
      }
      
      if pathComponents.count > 1 {
        let parentPath = pathComponents.dropLast().joined(separator: ".")
        context.nodes[nodeId]?.parent = parentPath
        
        if var parentNode = context.nodes[parentPath] {
          if !parentNode.children.contains(nodeId) {
            parentNode.children.append(nodeId)
            context.nodes[parentPath] = parentNode
          }
        }
      }
      
      let rootPath = pathComponents.first!
      if !context.rootNodes.contains(rootPath) {
        context.rootNodes.append(rootPath)
      }
    }
  }
  
  private func handleTestEnded(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      var pathComponents = test.id.keyPathRepresentation
      let isSuite = test.isSuite
      
      if !isSuite && pathComponents.count > 3 {
        let lastComponent = pathComponents.last!
        if lastComponent.contains(".swift:") {
          pathComponents = Array(pathComponents.dropLast())
        }
      }
      
      let nodeId = pathComponents.joined(separator: ".")
      guard var node = context.nodes[nodeId] else { return }
      
      node.endTime = instant
      
      if !node.isSuite {
        // Determine final status based on issues
        let failureIssues = node.issues.filter { !$0.isKnown && isFailureIssue($0.issue) }
        let knownIssues = node.issues.filter { $0.isKnown }
        let warningIssues = node.issues.filter { !$0.isKnown && !isFailureIssue($0.issue) }
        
        if !failureIssues.isEmpty {
          node.status = .failed
          context.totalFailed += 1
          context.symbolCounts["fail", default: 0] += 1
        } else if !knownIssues.isEmpty {
          node.status = .passedWithKnownIssues(count: knownIssues.count)
          context.totalPassed += 1
          context.totalKnownIssues += knownIssues.count
          context.symbolCounts["passWithKnownIssues", default: 0] += 1
        } else if !warningIssues.isEmpty {
          node.status = .passedWithWarnings(count: warningIssues.count)
          context.totalPassed += 1
          context.totalWarnings += warningIssues.count
          context.symbolCounts["passWithWarnings", default: 0] += 1
        } else {
          node.status = .passed
          context.totalPassed += 1
          context.symbolCounts["pass", default: 0] += 1
        }
      }
      
      context.nodes[nodeId] = node
    }
  }
  
  private func handleIssueRecorded(_ issue: Issue, at instant: Test.Clock.Instant, in eventContext: borrowing Event.Context) {
    guard let test = eventContext.test else { return }
    
    var pathComponents = test.id.keyPathRepresentation
    let isSuite = test.isSuite
    
    if !isSuite && pathComponents.count > 3 {
      let lastComponent = pathComponents.last!
      if lastComponent.contains(".swift:") {
        pathComponents = Array(pathComponents.dropLast())
      }
    }
    
    let nodeId = pathComponents.joined(separator: ".")
    let isKnown = issue.isKnown
    let summary = formatIssueSummary(issue)
    
    let issueInfo = HierarchyNode.IssueInfo(
      issue: issue,
      isKnown: isKnown,
      summary: summary
    )
    
    _context.withLock { context in
      guard var node = context.nodes[nodeId] else { return }
      
      node.issues.append(issueInfo)
      context.nodes[nodeId] = node
      
      switch issue.kind {
      case .expectationFailed(_):
        context.symbolCounts["difference", default: 0] += 1
      case .errorCaught(_):
        context.symbolCounts["fail", default: 0] += 1
      case .unconditional:
        context.symbolCounts["warning", default: 0] += 1
      case .timeLimitExceeded(_):
        context.symbolCounts["fail", default: 0] += 1
      case .apiMisused:
        context.symbolCounts["warning", default: 0] += 1
      case .knownIssueNotRecorded:
        context.symbolCounts["warning", default: 0] += 1
      case .system:
        context.symbolCounts["fail", default: 0] += 1
      case .valueAttachmentFailed(_):
        context.symbolCounts["attachment", default: 0] += 1
      case .confirmationMiscounted(_, _):
        context.symbolCounts["difference", default: 0] += 1
      }
    }
  }
  
  private func handleTestSkipped(_ test: Test, skipInfo: SkipInfo, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      let nodeId = test.id.keyPathRepresentation.joined(separator: ".")
      guard var node = context.nodes[nodeId] else { return }
      
      node.status = .skipped
      node.endTime = instant
      context.totalSkipped += 1
      context.symbolCounts["skip", default: 0] += 1
      context.nodes[nodeId] = node
    }
  }
  
  private func handleRunEnded(_ event: borrowing Event) {
    _context.withLock { context in
      context.runEndTime = event.instant
      context.isRunCompleted = true
    }
    
    renderCompleteHierarchy()
    Self.cleanupSignalHandlers()
  }
  
  private func renderCompleteHierarchy() {
    let hierarchyOutput = _context.withLock { context in
      var output = ""
      
      output += "\r\u{001B}[K"
      
      if context.rootNodes.isEmpty {
        let allTestNodes = context.nodes.values.filter { !$0.isSuite }.sorted { $0.name < $1.name }
        for node in allTestNodes {
          let statusIcon = getStatusIcon(for: node.status)
          let testName = node.displayName ?? node.name
          let duration = formatDuration(from: node.startTime, to: node.endTime)
          
          output += "\(statusIcon) \(testName)"
          if !duration.isEmpty {
            output += " \(duration)"
          }
          output += "\n"
        }
      } else {
        for (index, rootNodeId) in context.rootNodes.enumerated() {
          let isLastRoot = index == context.rootNodes.count - 1
          let isFirstRoot = index == 0
          output += renderNode(rootNodeId, context: context, prefix: "", isLast: isLastRoot, depth: 0, isFirst: isFirstRoot)
        }
      }
      
      output += renderFinalSummary(context: context)
      
      return output
    }
    
    write(hierarchyOutput)
  }
  
  /// Render a single node and its children recursively
  private func renderNode(_ nodeId: String, context: HierarchyContext, prefix: String, isLast: Bool, depth: Int, isFirst: Bool = false) -> String {
    guard let node = context.nodes[nodeId] else { return "" }
    
    var output = ""
    let indent = String(repeating: " ", count: depth * 3)
    
    if node.isSuite {
      let treePrefix: String
      if isLast {
        treePrefix = "╰─ "
      } else if isFirst && depth == 0 {
        treePrefix = "┌─ "
      } else {
        treePrefix = "├─ "
      }
      
      let suiteName = node.displayName ?? node.name
      output += "\(indent)\(treePrefix)\(suiteName)\n"
      
      let childPrefix = indent + (isLast ? "   " : "│  ")
      for (childIndex, childId) in node.children.enumerated() {
        let isLastChild = childIndex == node.children.count - 1
        output += renderNode(childId, context: context, prefix: childPrefix, isLast: isLastChild, depth: depth + 1, isFirst: false)
      }
      
      
      if !isLast {
        output += "\n"
      }
      
    } else {
      let shouldShow = !isPassedStatus(node.status) || options.showSuccessfulTests
      
      if shouldShow {
        let treePrefix: String
        if isLast {
          treePrefix = "╰─ "
        } else if isFirst && depth == 0 {
          treePrefix = "┌─ "
        } else {
          treePrefix = "├─ "
        }
        
        let statusIcon = getStatusIcon(for: node.status)
        let testName = node.displayName ?? node.name
        let duration = formatDuration(from: node.startTime, to: node.endTime)
        
        let leftPart = "\(indent)\(treePrefix)\(statusIcon) \(testName)"
        
        if !duration.isEmpty {
          let targetWidth = 150
          let rightPart = "(\(duration))"
          let totalLeftLength = leftPart.count
          let totalRightLength = rightPart.count
          
          if totalLeftLength + totalRightLength < targetWidth {
            let paddingLength = targetWidth - totalLeftLength - totalRightLength
            output += "\(leftPart)\(String(repeating: " ", count: paddingLength))\(rightPart)"
          } else {
            output += "\(leftPart) \(rightPart)"
          }
        } else {
          output += leftPart
        }
        output += "\n"
        
        if !node.issues.isEmpty {
          let issuePrefix = indent + (isLast ? "   " : "│  ")
          for (issueIndex, issue) in node.issues.enumerated() {
            let isLastIssue = issueIndex == node.issues.count - 1
            let issueTreePrefix: String
            if isLastIssue {
              issueTreePrefix = "╰─ "
            } else {
              issueTreePrefix = "├─ "
            }
            let issueIcon = getIssueIcon(for: issue)
            output += "\(issuePrefix)\(issueTreePrefix)\(issueIcon) \(issue.summary)\n"
            
            if let sourceLocation = issue.issue.sourceLocation {
              let locationPrefix = issuePrefix + "   " 
              output += "\(locationPrefix)At \(sourceLocation.fileName):\(sourceLocation.line):\(sourceLocation.column)\n"
            }
          }
        }
      }
    }
    
    return output
  }
  
  private func calculateSuiteStatistics(_ suite: HierarchyNode, context: HierarchyContext) -> (passed: Int, failed: Int, skipped: Int, knownIssues: Int, warnings: Int) {
    var stats = (passed: 0, failed: 0, skipped: 0, knownIssues: 0, warnings: 0)
    
    for childId in suite.children {
      guard let child = context.nodes[childId] else { continue }
      
      if child.isSuite {
        let childStats = calculateSuiteStatistics(child, context: context)
        stats.passed += childStats.passed
        stats.failed += childStats.failed
        stats.skipped += childStats.skipped
        stats.knownIssues += childStats.knownIssues
        stats.warnings += childStats.warnings
      } else {
        switch child.status {
        case .passed:
          stats.passed += 1
        case .failed:
          stats.failed += 1
        case .skipped:
          stats.skipped += 1
        case .passedWithKnownIssues(let count):
          stats.passed += 1
          stats.knownIssues += count
        case .passedWithWarnings(let count):
          stats.passed += 1
          stats.warnings += count
        case .running:
          break
        }
      }
    }
    
    return stats
  }
  
  private func formatSuiteStatsSummary(_ stats: (passed: Int, failed: Int, skipped: Int, knownIssues: Int, warnings: Int)) -> String {
    var parts: [String] = []
    
    if stats.failed > 0 {
      parts.append("\(stats.failed) failed")
    }
    if stats.passed > 0 {
      parts.append("\(stats.passed) passed")
    }
    if stats.skipped > 0 {
      parts.append("\(stats.skipped) skipped")
    }
    
    if parts.isEmpty {
      return "No tests"
    }
    
    return parts.joined(separator: ", ")
  }
  
  private func getStatusIconForSuiteStats(_ stats: (passed: Int, failed: Int, skipped: Int, knownIssues: Int, warnings: Int)) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    
    if stats.failed > 0 {
      return getColoredSymbol(.fail, color: useColors ? "\u{001B}[91m" : "", useColors: useColors)
    } else if stats.passed > 0 {
      return getColoredSymbol(.pass(knownIssueCount: 0), color: useColors ? "\u{001B}[92m" : "", useColors: useColors)
    } else {
      return getColoredSymbol(.skip, color: useColors ? "\u{001B}[95m" : "", useColors: useColors)
    }
  }
  
  private func getStatusIcon(for status: HierarchyNode.NodeStatus) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    
    switch status {
    case .passed:
      return getColoredSymbol(.pass(knownIssueCount: 0), color: useColors ? "\u{001B}[92m" : "", useColors: useColors)
    case .failed:
      return getColoredSymbol(.fail, color: useColors ? "\u{001B}[91m" : "", useColors: useColors)
    case .skipped:
      return getColoredSymbol(.skip, color: useColors ? "\u{001B}[95m" : "", useColors: useColors)
    case .passedWithKnownIssues(_):
      return getColoredSymbol(.pass(knownIssueCount: 1), color: useColors ? "\u{001B}[90m" : "", useColors: useColors)
    case .passedWithWarnings(_):
      return getColoredSymbol(.pass(knownIssueCount: 0), color: useColors ? "\u{001B}[93m" : "", useColors: useColors)
    case .running:
      return getColoredSymbol(.default, color: useColors ? "\u{001B}[96m" : "", useColors: useColors)
    }
  }
  
  private func getIssueIcon(for issue: HierarchyNode.IssueInfo) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    
    if issue.isKnown {
      return getColoredSymbol(.pass(knownIssueCount: 1), color: useColors ? "\u{001B}[90m" : "", useColors: useColors)
    }
    
    switch issue.issue.kind {
    case .expectationFailed(_):
      return getColoredSymbol(.difference, color: useColors ? "\u{001B}[33m" : "", useColors: useColors)
    case .errorCaught(_):
      return getColoredSymbol(.fail, color: useColors ? "\u{001B}[91m" : "", useColors: useColors)
    case .unconditional:
      return getColoredSymbol(.warning, color: useColors ? "\u{001B}[93m" : "", useColors: useColors)
    case .timeLimitExceeded(_):
      return getColoredSymbol(.fail, color: useColors ? "\u{001B}[91m" : "", useColors: useColors)
    case .apiMisused:
      return getColoredSymbol(.warning, color: useColors ? "\u{001B}[93m" : "", useColors: useColors)
    case .knownIssueNotRecorded:
      return getColoredSymbol(.warning, color: useColors ? "\u{001B}[93m" : "", useColors: useColors)
    case .system:
      return getColoredSymbol(.fail, color: useColors ? "\u{001B}[91m" : "", useColors: useColors)
    case .valueAttachmentFailed(_):
      return getColoredSymbol(.attachment, color: useColors ? "\u{001B}[34m" : "", useColors: useColors)
    case .confirmationMiscounted(_, _):
      return getColoredSymbol(.difference, color: useColors ? "\u{001B}[33m" : "", useColors: useColors)
    }
  }
  
  private func getColoredSymbol(_ symbol: Event.Symbol, color: String, useColors: Bool) -> String {
    return symbol.stringValue(options: options.base)
  }
  
  private func formatIssueSummary(_ issue: Issue) -> String {
    switch issue.kind {
    case .expectationFailed(let expectation):
      return "Expectation failed: \(expectation.evaluatedExpression.expandedDescription())"
    case .errorCaught(let error):
      return "Error: \(error)"
    case .unconditional:
      return issue.comments.first?.rawValue ?? "Unconditional issue"
    case .timeLimitExceeded(let timeLimitComponents):
      return "Time limit exceeded (\(TimeValue(timeLimitComponents)))"
    case .apiMisused:
      return "API misused: \(issue.comments.first?.rawValue ?? "")"
    case .knownIssueNotRecorded:
      return "Known issue not recorded"
    case .system:
      return "System error: \(issue.comments.first?.rawValue ?? "")"
    case .valueAttachmentFailed(let error):
      return "Attachment failed: \(error)"
    case .confirmationMiscounted(let actual, let expected):
      return "Confirmation count mismatch: expected \(expected), got \(actual)"
    }
  }
  
  private func isFailureIssue(_ issue: Issue) -> Bool {
    switch issue.kind {
    case .expectationFailed(_), .errorCaught(_), .timeLimitExceeded(_), .system, .confirmationMiscounted(_, _):
      return true
    case .unconditional, .apiMisused, .knownIssueNotRecorded, .valueAttachmentFailed(_):
      return false
    }
  }
  
  private func formatDuration(from startTime: Test.Clock.Instant?, to endTime: Test.Clock.Instant?) -> String {
    guard let startTime = startTime, let endTime = endTime else { return "" }
    
    let originalFormat = startTime.descriptionOfDuration(to: endTime)
    
    if originalFormat.hasPrefix("(") && originalFormat.hasSuffix(" seconds)") {
      let timeString = String(originalFormat.dropFirst().dropLast(9)) // Remove "(" and " seconds)"
      if let timeValue = Double(timeString) {
        return String(format: "%.2fs", timeValue)
      }
    }
    
    let durationNanoseconds = startTime.nanoseconds(until: endTime)
    let seconds = Double(durationNanoseconds) / 1_000_000_000.0
    return String(format: "%.2fs", seconds)
  }
  
  private func renderFinalSummary(context: HierarchyContext) -> String {
    var output = ""
    
    let duration = formatDuration(from: context.runStartTime, to: context.runEndTime)
    
    output += "\n"
    
    let totalTests = context.totalPassed + context.totalFailed + context.totalSkipped
    let totalSuites = context.nodes.values.filter { $0.isSuite }.count
    
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    let redColor = useColors ? "\u{001B}[91m" : ""
    let greenColor = useColors ? "\u{001B}[92m" : ""
    let yellowColor = useColors ? "\u{001B}[93m" : ""
    let grayColor = useColors ? "\u{001B}[90m" : ""
    let resetColor = useColors ? "\u{001B}[0m" : ""
    
    let issuesDescription: String
    if context.totalKnownIssues > 0 || context.totalWarnings > 0 {
      var parts: [String] = []
      if context.totalKnownIssues > 0 {
        let knownText = "\(context.totalKnownIssues) \(grayColor)known \(context.totalKnownIssues == 1 ? "issue" : "issues")\(resetColor)"
        parts.append(knownText)
      }
      if context.totalWarnings > 0 {
        let warningText = "\(context.totalWarnings) \(yellowColor)\(context.totalWarnings == 1 ? "warning" : "warnings")\(resetColor)"
        parts.append(warningText)
      }
      issuesDescription = " with " + parts.joined(separator: " and ")
    } else {
      issuesDescription = ""
    }
    
    if context.totalFailed > 0 {
      let symbol = Event.Symbol.fail.stringValue(options: options.base)
      output += "\(symbol) Test run with \(totalTests.counting("test")) in \(totalSuites.counting("suite")) \(redColor)failed\(resetColor) after \(duration)\(issuesDescription).\n"
    } else {
      let symbol = Event.Symbol.pass(knownIssueCount: context.totalKnownIssues).stringValue(options: options.base)
      output += "\(symbol) Test run with \(totalTests.counting("test")) in \(totalSuites.counting("suite")) \(greenColor)passed\(resetColor) after \(duration)\(issuesDescription).\n"
    }
    
    // Add hierarchy summary with symbol showcase
    output += renderHierarchySummary(context: context)
    
    return output
  }
  
  private func renderHierarchySummary(context: HierarchyContext) -> String {
    var summaryParts: [String] = []
    
    // Collect all symbol counts in the specified order
    if context.symbolCounts["pass", default: 0] > 0 {
      let symbol = Event.Symbol.pass(knownIssueCount: 0).stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["pass", default: 0])")
    }
    
    if context.symbolCounts["fail", default: 0] > 0 {
      let symbol = Event.Symbol.fail.stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["fail", default: 0])")
    }
    
    if context.symbolCounts["passWithKnownIssues", default: 0] > 0 {
      let symbol = Event.Symbol.pass(knownIssueCount: 1).stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["passWithKnownIssues", default: 0])")
    }
    
    if context.symbolCounts["passWithWarnings", default: 0] > 0 {
      let symbol = Event.Symbol.passWithWarnings.stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["passWithWarnings", default: 0])")
    }
    
    if context.symbolCounts["skip", default: 0] > 0 {
      let symbol = Event.Symbol.skip.stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["skip", default: 0])")
    }
    
    if context.symbolCounts["warning", default: 0] > 0 {
      let symbol = Event.Symbol.warning.stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["warning", default: 0])")
    }
    
    if context.symbolCounts["difference", default: 0] > 0 {
      let symbol = Event.Symbol.difference.stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["difference", default: 0])")
    }
    
    if context.symbolCounts["details", default: 0] > 0 {
      let symbol = Event.Symbol.details.stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["details", default: 0])")
    }
    
    if context.symbolCounts["attachment", default: 0] > 0 {
      let symbol = Event.Symbol.attachment.stringValue(options: options.base)
      summaryParts.append("\(symbol) \(context.symbolCounts["attachment", default: 0])")
    }
    
    if !summaryParts.isEmpty {
      return summaryParts.joined(separator: " ") + "\n"
    }
    
    return ""
  }
  
  private func getTestCount(from eventContext: borrowing Event.Context) -> Int {

    return 0
  }
  
  private func isPassedStatus(_ status: HierarchyNode.NodeStatus) -> Bool {
    switch status {
    case .passed:
      return true
    default:
      return false
    }
  }
  
  // MARK: - Signal Handling
  
  private static func setupSignalHandlers() {
    Task { @MainActor in
      // Only set up the signal handler once
      guard Self._signalHandler == nil else { return }
      
      Self._hasActiveRecorder = true
      
      #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
      let signalType = SIGINFO
      #else
      let signalType = SIGUSR1
      #endif
      
      signal(signalType, SIG_IGN) // Ignore default handler
      
      let signalSource = DispatchSource.makeSignalSource(signal: signalType, queue: .main)
      signalSource.setEventHandler {
        Self.printGlobalOnDemandStatus()
      }
      signalSource.resume()
      Self._signalHandler = signalSource
    }
  }
  
  @MainActor private static func printGlobalOnDemandStatus() {
    guard _hasActiveRecorder else {
      try? FileHandle.stderr.write("\nNo active test recorder found.\n")
      return
    }
    
    let (total, completed, passed, failed, warnings, known, skipped) = _livePhaseState.withLock { state in
      (max(state.totalTests, state.completedTests), state.completedTests, state.passed, 
       state.failed, state.warnings, state.knownIssues, state.skipped)
    }
    
    let statusMsg = "STATUS: [\(completed)/\(total)] | ✓ \(passed) | ✗ \(failed) | ? \(warnings) | ~ \(known) | → \(skipped)"
    
    try? FileHandle.stderr.write("\n\(statusMsg)\n")
  }
  
  private static func cleanupSignalHandlers() {
    Task { @MainActor in
      Self._hasActiveRecorder = false
    }
  }
}

// MARK: - Extensions

extension Int {
  /// Get a human-readable description of this instance as a count of some item.
  ///
  /// - Parameters:
  ///   - item: The item being counted.
  ///
  /// - Returns: A human-readable description such as "1 test" or "2 tests".
  fileprivate func counting(_ item: String) -> String {
    switch self {
    case 1:
      return "\(self) \(item)"
    default:
      return "\(self) \(item)s"
    }
  }
} 