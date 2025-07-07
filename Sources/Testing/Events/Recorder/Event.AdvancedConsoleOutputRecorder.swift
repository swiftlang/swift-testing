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
  /// An advanced console output recorder that provides enhanced features like
  /// live progress reporting, hierarchical suite display, and improved formatting.
  ///
  /// This recorder builds upon the existing `ConsoleOutputRecorder` but adds:
  /// - Buffered hierarchical output maintaining tree structure during parallel execution
  /// - Issues displayed as sub-nodes under their parent tests
  /// - Proper Unicode box-drawing characters for tree visualization
  /// - Suite summaries "out-dented" to align with parent levels
  /// - Right-aligned timing information
  @_spi(Experimental)
  public struct AdvancedConsoleOutputRecorder: Sendable {
    /// Configuration options for the advanced console output recorder.
    public struct Options: Sendable {
      public var base: Event.ConsoleOutputRecorder.Options
      
      public var useHierarchicalOutput: Bool
      
      public init() {
        self.base = Event.ConsoleOutputRecorder.Options()
        self.useHierarchicalOutput = true
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
      var children: [HierarchyNode] = []
      
      struct IssueInfo: Sendable {
        let issue: Issue
        let isKnown: Bool
        let summary: String
      }
      
      enum NodeStatus: Sendable {
        case running
        case passed
        case failed
        case skipped
        case passedWithKnownIssues(count: Int)
        case passedWithWarnings(count: Int)
      }
    }
    
    private struct HierarchyContext: Sendable {
      var rootNodes: [HierarchyNode] = []
      
      var nodesByID: [Test.ID: Int] = [:] 
      
      var allNodes: [HierarchyNode] = []
      
      var completedSuites: [Test.ID] = []
      
      /// Track which suites have had all their children complete
      var suiteChildrenStatus: [Test.ID: (total: Int, completed: Int)] = [:]
      
      /// Buffer for collecting suite output before rendering
      var suiteBuffers: [Test.ID: String] = [:]
      
      /// Track test execution order for proper rendering
      var executionOrder: [Test.ID] = []
      
      /// Overall test statistics
      var overallStats = (passed: 0, failed: 0, skipped: 0, knownIssues: 0, warnings: 0, attachments: 0)
      
      /// Track test run timing
      var runStartTime: Test.Clock.Instant?
      var runEndTime: Test.Clock.Instant?
      
      /// Test target/module name for root node
      var testTargetName: String?
      var testTargetRootNode: HierarchyNode?
      
      /// Completed tests that are ready for rendering
      var completedTests: [Test.ID] = []
      
      /// Track suite completion to render hierarchically
      var suiteCompletionStatus: [Test.ID: (expected: Int, completed: Int)] = [:]
    }
    
    /// The hierarchical context, protected by a lock for thread safety.
    private let _context = Locked(rawValue: HierarchyContext())
    
    /// Initialize the advanced console output recorder.
    public init(options: Options = Options(), writingUsing write: @escaping @Sendable (String) -> Void) {
      self.options = options
      self.write = write
    }
  }
}

extension Event.AdvancedConsoleOutputRecorder {
  /// Handle an event and produce hierarchical output.
  public func handle(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    if options.useHierarchicalOutput {
      handleWithHierarchy(event, in: eventContext)
    } else {
      // Fallback to regular console output
      let consoleRecorder = Event.ConsoleOutputRecorder(options: options.base, writingUsing: write)
      consoleRecorder.record(event, in: eventContext)
    }
  }
  
  private func handleWithHierarchy(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    switch event.kind {
    case .runStarted:
      _context.withLock { context in
        context.runStartTime = event.instant
      }
      let testCount = getTestCount(from: eventContext)
      #if os(macOS)
      let runningSymbol = "􀊕" // play.circle
      #else
      let runningSymbol = "▶"
      #endif
      let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth > 1
      let tealColor = useColors ? "\u{001B}[38;2;0;128;128m" : ""
      let resetColor = useColors ? "\u{001B}[0m" : ""
      
      let message = if testCount > 0 {
        "Running \(testCount) tests..."
      } else {
        "Running tests..."
      }
      write("\(tealColor)\(runningSymbol)\(resetColor) \(message)\n")
      
    case .testStarted:
      guard let test = eventContext.test else { return }
      handleTestStarted(test, at: event.instant)
      
    case .testEnded:
      guard let test = eventContext.test else { return }
      handleTestEnded(test, at: event.instant)
      
    case let .issueRecorded(issue):
      guard let test = eventContext.test else { return }
      handleIssueRecorded(issue, for: test)
      
    case .runEnded:
      _context.withLock { context in
        context.runEndTime = event.instant
        
        if let testTargetRootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
          context.allNodes[testTargetRootIndex].endTime = event.instant
        }
      }
      
      renderCompleteHierarchy()
      renderFinalSummary()
      // No "Test run ended" message needed
      
    case .testSkipped:
      if let test = eventContext.test {
        handleTestSkipped(test, at: event.instant)
      }
      
    case .testCaseStarted, .testCaseEnded, .expectationChecked, .iterationStarted, .iterationEnded:
      break
      
    default:
      handleOtherEvent(event, in: eventContext)
    }
  }
  
  private func getTestCount(from eventContext: borrowing Event.Context) -> Int {
  
    return 0
  }
  
  private func handleTestStarted(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      if context.testTargetRootNode == nil {
        let testTargetName = extractTestTargetName(from: test.id)
        context.testTargetName = testTargetName
        
        let rootNode = HierarchyNode(
          id: Test.ID(type: String.self),
          name: testTargetName,
          displayName: testTargetName,
          isSuite: true,
          startTime: instant
        )
        
        context.allNodes.append(rootNode)
        let rootIndex = context.allNodes.count - 1
        context.testTargetRootNode = context.allNodes[rootIndex]
        context.rootNodes.append(context.allNodes[rootIndex])
      }
      
      let node = HierarchyNode(
        id: test.id,
        name: test.name,
        displayName: test.displayName,
        isSuite: test.isSuite,
        startTime: instant
      )
      
      context.allNodes.append(node)
      let currentIndex = context.allNodes.count - 1
      context.nodesByID[test.id] = currentIndex
      context.executionOrder.append(test.id)
      
      // Add to parent's children or as child of test target root
      if let parentID = test.id.parent {
        var actualParentID = parentID
        if !test.isSuite {
          var currentID = parentID
          while let parent = currentID.parent {
            if context.nodesByID[parent] != nil {
              actualParentID = parent
              break
            }
            currentID = parent
          }
        }
        
        if let parentIndex = context.nodesByID[actualParentID] {
          // Add this node as a child of the parent (modify the parent directly in the array)
          context.allNodes[parentIndex].children.append(context.allNodes[currentIndex])
        } else {
          if isTopLevelSuite(test, targetName: context.testTargetName ?? "") {
            if let rootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
              context.allNodes[rootIndex].children.append(context.allNodes[currentIndex])
              context.rootNodes[rootIndex] = context.allNodes[rootIndex]
            }
          }
        }
      } else {
        if let rootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
          context.allNodes[rootIndex].children.append(context.allNodes[currentIndex])
          context.rootNodes[rootIndex] = context.allNodes[rootIndex]
        }
      }
    }
  }
  
  private func extractTestTargetName(from testID: Test.ID) -> String {
    let components = testID.description.components(separatedBy: ".")
    return components.first ?? "TestTarget"
  }
  
  private func isTopLevelSuite(_ test: Test, targetName: String) -> Bool {
    
    if !test.isSuite {
      return false
    }
    
    let testIDString = test.id.description
    let components = testIDString.components(separatedBy: ".")
    
    if components.count >= 2 && components[0] == targetName {
      return true
    }
    
    return false
  }
  
  private func handleTestEnded(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      guard let nodeIndex = context.nodesByID[test.id] else { return }
      guard nodeIndex < context.allNodes.count else { return } // Safety check
      
      context.allNodes[nodeIndex].endTime = instant
      
      let node = context.allNodes[nodeIndex]
      let knownIssueCount = node.issues.filter { $0.isKnown }.count
      let warningCount = node.issues.filter { $0.issue.severity == .warning }.count
      let failureCount = node.issues.filter { !$0.isKnown && $0.issue.severity == .error }.count
      let attachmentCount = node.issues.filter { issueInfo in
        if case .valueAttachmentFailed = issueInfo.issue.kind {
          return true
        }
        return false
      }.count
      
      if failureCount > 0 {
        context.allNodes[nodeIndex].status = .failed
      } else if knownIssueCount > 0 {
        context.allNodes[nodeIndex].status = .passedWithKnownIssues(count: knownIssueCount)
      } else if warningCount > 0 {
        context.allNodes[nodeIndex].status = .passedWithWarnings(count: warningCount)
      } else {
        context.allNodes[nodeIndex].status = .passed
      }
      
      if !test.isSuite {
        switch context.allNodes[nodeIndex].status {
        case .passed:
          context.overallStats.passed += 1
        case .failed:
          context.overallStats.failed += 1
        case .skipped:
          context.overallStats.skipped += 1
        case .passedWithKnownIssues(let count):
          context.overallStats.passed += 1
          context.overallStats.knownIssues += count
        case .passedWithWarnings(let count):
          context.overallStats.passed += 1
          context.overallStats.warnings += count
        case .running:
          break
        }
        context.overallStats.attachments += attachmentCount
      }
      
      // Mark test as completed 
      context.completedTests.append(test.id)
      
      // Handle suite completion tracking - don't render individual tests here
      // Wait for all tests to complete so we can show final status icons
      if test.isSuite {
        // Suite completed - update the test target root end time if needed
        if let testTargetRootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
          context.allNodes[testTargetRootIndex].endTime = instant
        }
      }
      
      // Only render at the very end when run ends to show final status
    }
  }
  
  private func handleIssueRecorded(_ issue: Issue, for test: Test) {
    _context.withLock { context in
      guard let nodeIndex = context.nodesByID[test.id] else { return }
      guard nodeIndex < context.allNodes.count else { return } // Safety check
      
      let issueInfo = HierarchyNode.IssueInfo(
        issue: issue,
        isKnown: issue.isKnown,
        summary: formatIssueSummary(issue)
      )
      
      context.allNodes[nodeIndex].issues.append(issueInfo)
    }
  }
  
  private func handleTestSkipped(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      let node = HierarchyNode(
        id: test.id,
        name: test.name,
        displayName: test.displayName,
        isSuite: test.isSuite,
        startTime: instant,
        endTime: instant
      )
      
      context.allNodes.append(node)
      let currentIndex = context.allNodes.count - 1
      context.nodesByID[test.id] = currentIndex
      context.allNodes[currentIndex].status = .skipped
      
      if !test.isSuite {
        context.overallStats.skipped += 1
      }
      
      if let parentID = test.id.parent {
        var actualParentID = parentID
        if !test.isSuite {
          var currentID = parentID
          while let parent = currentID.parent {
            if context.nodesByID[parent] != nil {
              actualParentID = parent
              break
            }
            currentID = parent
          }
        }
        
        if let parentIndex = context.nodesByID[actualParentID] {
          context.allNodes[parentIndex].children.append(context.allNodes[currentIndex])
        } else {
          context.rootNodes.append(context.allNodes[currentIndex])
        }
      } else {
        context.rootNodes.append(context.allNodes[currentIndex])
      }
    }
  }
  
  private func handleOtherEvent(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    let consoleRecorder = Event.ConsoleOutputRecorder(options: options.base, writingUsing: write)
    consoleRecorder.record(event, in: eventContext)
  }
  
  private func formatRightAlignedTiming(_ timing: String, contentPrefix: String) -> String {
    guard !timing.isEmpty else { return "" }
    
    let columnWidth = 80 
    
    let cleanPrefix = contentPrefix.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    
    let prefixLength = cleanPrefix.count
    let timingLength = timing.count
    let availableSpace = columnWidth - prefixLength - timingLength
    
    if availableSpace <= 1 {
      return " \(timing)"
    }
    
    return String(repeating: " ", count: availableSpace) + timing
  }
  
  private func renderNodeTree(_ node: HierarchyNode, depth: Int, isLast: Bool, parentPrefix: String, nodeStatusLookup: [Test.ID: HierarchyNode]) -> String {
    var output = ""
    
    let baseIndent = String(repeating: " ", count: (depth - 1) * 3)
    let treePrefix = depth == 0 ? "" : (isLast ? "╰─ " : "├─ ")
    let currentPrefix = baseIndent + treePrefix
    
    // For tests (not suites), render with proper timing and issues
    if !node.isSuite {
      let currentNode = nodeStatusLookup[node.id] ?? node
      let symbolWithColor = getSymbolWithColorForNode(currentNode)
      let name = currentNode.displayName ?? currentNode.name
      let timing = formatTiming(currentNode)
      let rightAlignedTiming = formatRightAlignedTiming(timing, contentPrefix: "\(currentPrefix)\(symbolWithColor)\(name)")
      
      output += "\(currentPrefix)\(symbolWithColor)\(name)\(rightAlignedTiming)\n"
      
      if !currentNode.issues.isEmpty {
        let issueIndent = String(repeating: " ", count: depth * 3)
        for (index, issue) in currentNode.issues.enumerated() {
          let isLastIssue = index == currentNode.issues.count - 1
          let issueTreePrefix = isLastIssue ? "╰─ " : "├─ "
          let issueSymbol = getSymbolWithColorForIssue(issue)
          output += "\(issueIndent)\(issueTreePrefix)\(issueSymbol)\(issue.summary)\n"
        }
      }
    } else {
      let suiteName = node.displayName ?? node.name
      let cleanSuiteName = suiteName.hasSuffix("/") ? suiteName : "\(suiteName)/"
      
      output += "\(currentPrefix)\(cleanSuiteName)\n"
      
      for (index, child) in node.children.enumerated() {
        let isLastChild = index == node.children.count - 1
        output += renderNodeTree(child, depth: depth + 1, isLast: isLastChild, parentPrefix: "", nodeStatusLookup: nodeStatusLookup)
      }
      
      let stats = calculateSuiteStatistics(node)
      if stats.passed > 0 || stats.failed > 0 || stats.skipped > 0 || stats.knownIssues > 0 || stats.warnings > 0 {
        let summaryIndent = String(repeating: " ", count: (depth - 1) * 3)
        let summaryPrefix = summaryIndent + "╰─ "
        let summary = generateSuiteSummary(node, stats: stats)
        output += "\(summaryPrefix)\(summary.icon)\(summary.text)\n"
      }
    }
    
    return output
  }
  
  private func calculateTreePrefix(depth: Int, isLast: Bool, parentPrefix: String) -> String {
    if depth == 0 {
      return ""
    }
    
    let connector = isLast ? "╰─" : "├─"
    return "\(parentPrefix)\(connector) "
  }
  
  private func renderIssue(_ issue: HierarchyNode.IssueInfo, prefix: String) -> String {
    let symbolWithColor = getSymbolWithColorForIssue(issue)
    return "\(prefix)\(symbolWithColor) \(issue.summary)\n"
  }
  
  private func getSymbolWithColorForNode(_ node: HierarchyNode) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth > 1
    
    let (symbol, colorCode) = getSymbolAndColorForNodeStatus(node.status)
    
    if useColors && !colorCode.isEmpty {
      let resetCode = "\u{001B}[0m"
      return "\(colorCode)\(symbol)\(resetCode)"
    } else {
      return symbol
    }
  }
  
  private func getSymbolWithColorForIssue(_ issue: HierarchyNode.IssueInfo) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth > 1
    
    let (symbol, colorCode) = getSymbolAndColorForIssue(issue)
    
    if useColors && !colorCode.isEmpty {
      let resetCode = "\u{001B}[0m"
      return "\(colorCode)\(symbol)\(resetCode)"
    } else {
      return symbol
    }
  }
  
  private func getSymbolAndColorForNodeStatus(_ status: HierarchyNode.NodeStatus) -> (symbol: String, colorCode: String) {
    #if os(macOS)
    switch status {
    case .running:
      return ("􀊕 ", "\u{001B}[38;2;0;128;128m") // play.circle (teal)
    case .passed:
      return ("􀁢 ", "\u{001B}[38;2;0;128;0m") // checkmark.circle (green)
    case .failed:
      return ("􀁠 ", "\u{001B}[38;2;255;0;0m") // x.circle (red)
    case .skipped:
      return ("􀊄 ", "\u{001B}[38;2;128;0;128m") // forward.circle (purple)
    case .passedWithKnownIssues(_):
      return ("􀁠 ", "\u{001B}[38;2;128;128;128m") // x.circle (gray)
    case .passedWithWarnings(_):
      return ("􀁞 ", "\u{001B}[38;2;255;255;0m") // questionmark.circle (yellow)
    }
    #else
    switch status {
    case .running:
      return ("▶ ", "\u{001B}[38;2;0;128;128m") // teal
    case .passed:
      return ("✓ ", "\u{001B}[38;2;0;128;0m") // green
    case .failed:
      return ("✗ ", "\u{001B}[38;2;255;0;0m") // red
    case .skipped:
      return ("⏭ ", "\u{001B}[38;2;128;0;128m") // purple
    case .passedWithKnownIssues(_):
      return ("x ", "\u{001B}[38;2;128;128;128m") // gray
    case .passedWithWarnings(_):
      return ("⚠ ", "\u{001B}[38;2;255;255;0m") // yellow
    }
    #endif
  }
  
  private func getSymbolAndColorForIssue(_ issue: HierarchyNode.IssueInfo) -> (symbol: String, colorCode: String) {
    #if os(macOS)
    if issue.isKnown {
      return ("􀁠 ", "\u{001B}[38;2;128;128;128m") // x.circle (gray) for known issues
    } else {
      switch issue.issue.severity {
      case .warning:
        return ("􀇾 ", "\u{001B}[38;2;255;165;0m") // exclamationmark.circle (orange)
      case .error:
        return ("􀁠 ", "\u{001B}[38;2;255;0;0m") // x.circle (red)
      }
    }
    #else
    if issue.isKnown {
      return ("! ", "\u{001B}[38;2;128;128;128m") // gray
    } else {
      switch issue.issue.severity {
      case .warning:
        return ("⚠ ", "\u{001B}[38;2;255;165;0m") // orange
      case .error:
        return ("✗ ", "\u{001B}[38;2;255;0;0m") // red
      }
    }
    #endif
  }
  
  private func formatTiming(_ node: HierarchyNode) -> String {
    guard let startTime = node.startTime, let endTime = node.endTime else {
      return ""
    }
    
    guard startTime <= endTime else {
      return " (0.000s)"
    }
    
    let duration = startTime.descriptionOfDuration(to: endTime)
    return " (\(duration))"
  }
  
  private func formatIssueSummary(_ issue: Issue) -> String {
    let summary: String
    
    if case let .expectationFailed(expectation) = issue.kind {
      let description = expectation.evaluatedExpression.expandedDescription()
      if description.count > 80 {
        summary = "Expectation failed: \(String(description.prefix(77)))..."
      } else {
        summary = "Expectation failed: \(description)"
      }
    } else if case let .errorCaught(error) = issue.kind {
      summary = "Error: \(String(describing: error))"
    } else if case .unconditional = issue.kind {
      summary = "Issue recorded"
    } else if case let .timeLimitExceeded(timeLimitComponents) = issue.kind {
      summary = "Time limit exceeded: \(TimeValue(timeLimitComponents))"
    } else if case .apiMisused = issue.kind {
      summary = "API misuse"
    } else if case .knownIssueNotRecorded = issue.kind {
      summary = "Known issue not recorded"
    } else if case .system = issue.kind {
      summary = "System error"
    } else if case let .valueAttachmentFailed(error) = issue.kind {
      summary = "Attachment error: \(String(describing: error))"
    } else if case let .confirmationMiscounted(actual, expected) = issue.kind {
      summary = "Confirmation miscounted: \(actual) actual, \(expected) expected"
    } else {
      summary = issue.comments.first?.rawValue ?? "Issue recorded"
    }
    
    return summary
  }
  
  private func calculateSuiteStatistics(_ suite: HierarchyNode) -> (passed: Int, failed: Int, skipped: Int, knownIssues: Int, warnings: Int) {
    var passed = 0, failed = 0, skipped = 0, knownIssues = 0, warnings = 0
    
    func countNode(_ node: HierarchyNode) {
      if !node.isSuite {
        switch node.status {
        case .passed:
          passed += 1
        case .failed:
          failed += 1
        case .skipped:
          skipped += 1
        case .passedWithKnownIssues(let count):
          passed += 1
          knownIssues += count
        case .passedWithWarnings(let count):
          passed += 1
          warnings += count
        case .running:
          break
        }
      }
      
      for child in node.children {
        countNode(child)
      }
    }
    
    countNode(suite)
    return (passed, failed, skipped, knownIssues, warnings)
  }
  
  private func generateSuiteSummary(_ suite: HierarchyNode, stats: (passed: Int, failed: Int, skipped: Int, knownIssues: Int, warnings: Int)) -> (icon: String, text: String) {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth > 1
    
    // Determine overall status icon based on most severe outcome: Fail > Warning > Skip > Pass
    let (symbol, colorCode): (String, String)
    
    #if os(macOS)
    if stats.failed > 0 {
      (symbol, colorCode) = ("􀁠 ", "\u{001B}[38;2;255;0;0m") // x.circle (red)
    } else if stats.warnings > 0 {
      (symbol, colorCode) = ("􀇾 ", "\u{001B}[38;2;255;255;0m") // exclamationmark.circle (yellow)
    } else if stats.skipped > 0 {
      (symbol, colorCode) = ("􀺅 ", "\u{001B}[38;2;128;0;128m") // forward.end (purple)
    } else {
      (symbol, colorCode) = ("􀁢 ", "\u{001B}[38;2;0;128;0m") // checkmark.circle (green)
    }
    #else
    if stats.failed > 0 {
      (symbol, colorCode) = ("✗ ", "\u{001B}[38;2;255;0;0m") // red
    } else if stats.warnings > 0 {
      (symbol, colorCode) = ("⚠ ", "\u{001B}[38;2;255;255;0m") // yellow
    } else if stats.skipped > 0 {
      (symbol, colorCode) = ("⏭ ", "\u{001B}[38;2;128;0;128m") // purple
    } else {
      (symbol, colorCode) = ("✓ ", "\u{001B}[38;2;0;128;0m") // green
    }
    #endif
    
    let symbolWithColor: String
    if useColors && !colorCode.isEmpty {
      let resetCode = "\u{001B}[0m"
      symbolWithColor = "\(colorCode)\(symbol)\(resetCode)"
    } else {
      symbolWithColor = symbol
    }
    
    // Generate summary text in format: "X failed, Y passed in Z.ZZs"
    var parts: [String] = []
    
    // Order matters: failed first, then passed, then skipped
    if stats.failed > 0 {
      parts.append("\(stats.failed) failed")
    }
    if stats.passed > 0 {
      parts.append("\(stats.passed) passed")
    }
    if stats.skipped > 0 {
      parts.append("\(stats.skipped) skipped")
    }
    
    let summaryText = parts.joined(separator: ", ")
    let duration = formatTiming(suite).trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
    let fullText = summaryText.isEmpty ? "in \(duration)" : "\(summaryText) in \(duration)"
    
    return (icon: symbolWithColor, text: fullText)
  }
  
  private func renderFinalSummary() {
    _context.withLock { context in
      let stats = context.overallStats
      
      // Calculate real test run duration with safety checks
      let duration: String
      if let startTime = context.runStartTime, let endTime = context.runEndTime {
        // Safety check to prevent timing calculation issues
        if startTime <= endTime {
          let durationString = startTime.descriptionOfDuration(to: endTime)
          duration = durationString
        } else {
          duration = "0.000 seconds"
        }
      } else {
        duration = "unknown duration"
      }
      
      var output = "\nTests completed in \(duration)  ["
      
      // Add color-coded symbols and counts using conditional compilation
      let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth > 1
      
      var summaryParts: [String] = []
      
      if stats.passed > 0 {
        #if os(macOS)
        let (symbol, colorCode) = ("􀁢", "\u{001B}[38;2;0;128;0m")
        #else
        let (symbol, colorCode) = ("✓", "\u{001B}[38;2;0;128;0m")
        #endif
        let symbolWithColor = useColors ? "\(colorCode)\(symbol)\u{001B}[0m" : symbol
        summaryParts.append("\(symbolWithColor) \(stats.passed)")
      }
      
      if stats.failed > 0 {
        #if os(macOS)
        let (symbol, colorCode) = ("􀁠", "\u{001B}[38;2;255;0;0m")
        #else
        let (symbol, colorCode) = ("✗", "\u{001B}[38;2;255;0;0m")
        #endif
        let symbolWithColor = useColors ? "\(colorCode)\(symbol)\u{001B}[0m" : symbol
        summaryParts.append("\(symbolWithColor) \(stats.failed)")
      }
      
      if stats.warnings > 0 {
        #if os(macOS)
        let (symbol, colorCode) = ("􀇾", "\u{001B}[38;2;255;255;0m")
        #else
        let (symbol, colorCode) = ("⚠", "\u{001B}[38;2;255;255;0m")
        #endif
        let symbolWithColor = useColors ? "\(colorCode)\(symbol)\u{001B}[0m" : symbol
        summaryParts.append("\(symbolWithColor) \(stats.warnings)")
      }
      
      if stats.skipped > 0 {
        #if os(macOS)
        let (symbol, colorCode) = ("􀺅", "\u{001B}[38;2;128;0;128m")
        #else
        let (symbol, colorCode) = ("⏭", "\u{001B}[38;2;128;0;128m")
        #endif
        let symbolWithColor = useColors ? "\(colorCode)\(symbol)\u{001B}[0m" : symbol
        summaryParts.append("\(symbolWithColor) \(stats.skipped)")
      }
      
      if stats.knownIssues > 0 {
        #if os(macOS)
        let (symbol, colorCode) = ("􀁠", "\u{001B}[38;2;128;128;128m")
        #else
        let (symbol, colorCode) = ("!", "\u{001B}[38;2;128;128;128m")
        #endif
        let symbolWithColor = useColors ? "\(colorCode)\(symbol)\u{001B}[0m" : symbol
        summaryParts.append("\(symbolWithColor) \(stats.knownIssues)")
      }
      
      if stats.attachments > 0 {
        #if os(macOS)
        let (symbol, colorCode) = ("􀈷", "\u{001B}[38;2;128;128;128m")
        #else
        let (symbol, colorCode) = ("📎", "\u{001B}[38;2;128;128;128m")
        #endif
        let symbolWithColor = useColors ? "\(colorCode)\(symbol)\u{001B}[0m" : symbol
        summaryParts.append("\(symbolWithColor) \(stats.attachments)")
      }
      
      output += summaryParts.joined(separator: ", ")
      output += "]\n"
      
      // Add failure explanation if there were failures
      if stats.failed > 0 {
        output += "\nFailure explanation - see details below\n"
      }
      
      write(output)
    }
  }
  
  private func renderCompleteHierarchy() {
    _context.withLock { context in
      guard let testTargetName = context.testTargetName else { return }
      
      var nodeStatusLookup: [Test.ID: HierarchyNode] = [:]
      for node in context.allNodes {
        nodeStatusLookup[node.id] = node
      }
      
      let hierarchicalOutput = buildHierarchyFromNodes(context.allNodes, testTargetName: testTargetName, nodeStatusLookup: nodeStatusLookup)
      write(hierarchicalOutput)
    }
  }
  
  private func buildHierarchyFromNodes(_ allNodes: [HierarchyNode], testTargetName: String, nodeStatusLookup: [Test.ID: HierarchyNode]) -> String {
    var output = ""
    
    output += "\(testTargetName):\n"
    
    var topLevelSuites: [HierarchyNode] = []
    var orphanedTests: [HierarchyNode] = []
    
    for node in allNodes {
      if node.name == testTargetName {
        continue
      }
      
      // Check if this is a top-level suite or test
      if node.isSuite {
        let nodeIDString = node.id.description
        let components = nodeIDString.components(separatedBy: ".")
        
        // If the suite appears to be a direct child of the test target
        if components.count >= 2 && components[0] == testTargetName {
          topLevelSuites.append(node)
        }
      } else {
        if node.id.parent == nil {
          orphanedTests.append(node)
        }
      }
    }
    
    if topLevelSuites.isEmpty {
      var suiteGroups: [String: [HierarchyNode]] = [:]
      
      for node in allNodes {
        if node.name == testTargetName { continue }
        
        if let parentID = node.id.parent {
          let parentKey = parentID.description
          if suiteGroups[parentKey] == nil {
            suiteGroups[parentKey] = []
          }
          suiteGroups[parentKey]?.append(node)
        } else {
          let currentNode = nodeStatusLookup[node.id] ?? node
          let timing = formatTiming(currentNode)
          let symbolWithColor = getSymbolWithColorForNode(currentNode)
          let rightAlignedTiming = formatRightAlignedTiming(timing, contentPrefix: "├─ \(symbolWithColor)\(currentNode.displayName ?? currentNode.name)")
          output += "├─ \(symbolWithColor)\(currentNode.displayName ?? currentNode.name)\(rightAlignedTiming)\n"
        }
      }
      
      let sortedSuiteKeys = Array(suiteGroups.keys).sorted()
      for (index, suiteKey) in sortedSuiteKeys.enumerated() {
        let isLast = index == sortedSuiteKeys.count - 1
        let connector = isLast ? "╰─ " : "├─ "
        
        if let suiteTests = suiteGroups[suiteKey] {
          let suiteComponents = suiteKey.components(separatedBy: ".")
          let suiteName = suiteComponents.last ?? suiteKey
          output += "\(connector)\(suiteName)/\n"
          
          for (testIndex, test) in suiteTests.enumerated() {
            let isLastTest = testIndex == suiteTests.count - 1
            let testConnector = isLastTest ? "╰─ " : "├─ "
            let testIndent = "   "
            let currentTest = nodeStatusLookup[test.id] ?? test
            let symbolWithColor = getSymbolWithColorForNode(currentTest)
            let timing = formatTiming(currentTest)
            let rightAlignedTiming = formatRightAlignedTiming(timing, contentPrefix: "\(testIndent)\(testConnector)\(symbolWithColor)\(currentTest.displayName ?? currentTest.name)")
            output += "\(testIndent)\(testConnector)\(symbolWithColor)\(currentTest.displayName ?? currentTest.name)\(rightAlignedTiming)\n"
          }
        }
      }
    } else {
      for (index, suite) in topLevelSuites.enumerated() {
        let isLast = index == topLevelSuites.count - 1
        output += renderNodeTree(suite, depth: 1, isLast: isLast, parentPrefix: "", nodeStatusLookup: nodeStatusLookup)
      }
    }
    
    for orphan in orphanedTests {
      let currentOrphan = nodeStatusLookup[orphan.id] ?? orphan
      let symbolWithColor = getSymbolWithColorForNode(currentOrphan)
      let timing = formatTiming(currentOrphan)
      let rightAlignedTiming = formatRightAlignedTiming(timing, contentPrefix: "├─ \(symbolWithColor)\(currentOrphan.displayName ?? currentOrphan.name)")
      output += "├─ \(symbolWithColor)\(currentOrphan.displayName ?? currentOrphan.name)\(rightAlignedTiming)\n"
    }
    
    return output
  }
} 