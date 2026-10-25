import Foundation
import Darwin
import ReminderSnapCore

final class ParserTests {
    private func line(_ text: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 0.35, _ height: CGFloat = 0.04) -> OCRLine {
        OCRLine(text: text, boundingBox: CGRect(x: x, y: 1 - y - height / 2, width: width, height: height))
    }
    private func parse(_ lines: [OCRLine], context: ImportContext = ImportContext()) -> [AssignmentCandidate] {
        AssignmentParser().parse(documents: [OCRDocument(sourceName: "test", lines: lines)], context: context)
    }
    func testCroppedTableWithoutLogo() {
        let result = parse([
            line("Worksheet 1", 0.01, 0.45, 0.28, 0.12),
            line("Sep 20, 2026 at 11:59 PM", 0.36, 0.46, 0.63, 0.12)
        ], context: ImportContext(course: "MA-UY 2034"))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.assignmentName, "Worksheet 1")
        XCTAssertEqual(result.first?.courseTag, "#MA2034")
    }
    func testCroppedCardWithLargeRelativeSpacing() {
        let result = parse([
            line("Homework #1", 0.05, 0.15, 0.7, 0.12),
            line("Due on Sep 24, 2026 11:59 PM", 0.05, 0.62, 0.9, 0.12)
        ], context: ImportContext(course: "CS-UY 1134"))
        XCTAssertEqual(result.first?.assignmentName, "Homework #1")
        XCTAssertEqual(result.count, 1)
    }
    func testPlatformDetectedButShiftedColumns() {
        let result = parse([
            line("Gradescope", 0.01, 0.05),
            line("Worksheet 2", 0.02, 0.4, 0.25),
            line("Sep 27, 2026 23:59", 0.35, 0.4, 0.6)
        ], context: ImportContext(course: "MA-UY 2034"))
        XCTAssertEqual(result.count, 1)
    }
    func testSidebarIsNotAnAssignmentTitle() {
        let result = parse([
            line("Gradescope", 0.04, 0.1, 0.1, 0.01),
            line("Name", 0.2, 0.28, 0.1, 0.01),
            line("Linear Algebra", 0.04, 0.35, 0.11, 0.01),
            line("Worksheet 1", 0.2, 0.337, 0.12, 0.01),
            line("• No Submission", 0.36, 0.34, 0.16, 0.01),
            line("Sep 20, 2026 11:59 PM", 0.85, 0.35, 0.14, 0.01)
        ])
        XCTAssertEqual(result.first?.assignmentName, "Worksheet 1")
    }
    func testMissingYearIsNotInvented() {
        let lines = [line("Worksheet 1", 0.01, 0.3), line("Due Sep 20 at 11:59 PM", 0.01, 0.37, 0.9)]
        let missing = parse(lines)
        XCTAssertEqual(missing.count, 1)
        XCTAssertNil(missing.first?.dueDate)
        let supplied = parse(lines, context: ImportContext(course: "MA-UY 2034", year: 2026))
        XCTAssertNotNil(supplied.first?.dueDate)
        XCTAssertTrue(supplied.first?.warnings.contains { $0.contains("Year supplied") } == true)
    }
    func testReleaseAndLateDatesExcluded() {
        let result = parse([
            line("Worksheet 1", 0.01, 0.3),
            line("Due Sep 20, 2026 11:59 PM", 0.01, 0.37, 0.8),
            line("Starts Sep 14, 2026", 0.01, 0.43),
            line("Late Due Date: Sep 22, 2026", 0.01, 0.49, 0.9)
        ])
        XCTAssertEqual(result.count, 1)
    }
    func testWrappedTimeAndInlineTitle() {
        let wrapped = parse([
            line("Homework 3", 0.05, 0.2),
            line("Due Sep 24, 2026", 0.05, 0.3),
            line("11:59 PM", 0.05, 0.36)
        ])
        XCTAssertEqual(wrapped.first?.hasExplicitTime, true)
        let inline = parse([line("Homework 4 due September 25, 2026 at 11:59 PM", 0.01, 0.5, 0.98)])
        XCTAssertEqual(inline.first?.assignmentName, "Homework 4")
        let merged = parse([line("H1_S26 Separable First Order Linear DE Wed, Sep 16, 2026, 11:59 PM EDT", 0.01, 0.5, 0.98)])
        XCTAssertEqual(merged.first?.assignmentName, "H1_S26 Separable First Order Linear DE")
    }
    func testInvalidDatesAndTimesRejected() {
        XCTAssertNil(DeadlineParser.parse("Due February 30, 2026 at 11:59 PM"))
        XCTAssertNil(DeadlineParser.parse("2026-09-24 24:59"))
        XCTAssertNil(DeadlineParser.parse("Sep 24 at 11:59 PM"))
        XCTAssertNotNil(DeadlineParser.parse("Sep 24 at 11:59 PM", fallbackYear: 2026))
    }
    func testDateOnlyAndDayFirstAndNumeric() {
        XCTAssertNil(DeadlineParser.titleBeforeDate("Wed, Sep 16, 2026, 11:59 PM EDT"))
        XCTAssertEqual(DeadlineParser.parse("September 16, 2026")?.hasExplicitTime, false)
        XCTAssertNotNil(DeadlineParser.parse("Friday, 18 September 2026, 11:59 PM"))
        XCTAssertNotNil(DeadlineParser.parse("9/24/2026 23:59"))
    }
    func testDSTAndCompanionBlockDoesNotShiftDeadline() throws {
        for text in ["September 16, 2026 at 11:59 PM EDT", "November 4, 2026 at 11:59 PM EST"] {
            let due = try XCTUnwrap(DeadlineParser.parse(text))
            let candidate = AssignmentCandidate(courseCode: "MA-UY 2034", assignmentName: "Test", dueDate: due.date, hasExplicitTime: true, timeZoneIdentifier: due.timeZoneIdentifier, sourcePlatform: .unknown, sourceImages: [])
            let range = try XCTUnwrap(CompanionBlockSchedule.range(for: candidate))
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            XCTAssertEqual(calendar.component(.hour, from: range.start), 22)
            XCTAssertEqual(calendar.component(.hour, from: range.end), 23)
            XCTAssertEqual(calendar.component(.day, from: range.start), calendar.component(.day, from: due.date))
            XCTAssertEqual(calendar.component(.hour, from: candidate.dueDate!), 23)
        }
    }
}

// Portable harness: works with Command Line Tools as well as full Xcode.
private var failures = 0
private func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: String = #fileID, line: Int = #line) {
    if actual != expected { failures += 1; print("FAIL \(file):\(line): \(actual) != \(expected)") }
}
private func XCTAssertTrue(_ value: Bool, file: String = #fileID, line: Int = #line) {
    if !value { failures += 1; print("FAIL \(file):\(line)") }
}
private func XCTAssertNil<T>(_ value: T?, file: String = #fileID, line: Int = #line) {
    if value != nil { failures += 1; print("FAIL \(file):\(line): expected nil") }
}
private func XCTAssertNotNil<T>(_ value: T?, file: String = #fileID, line: Int = #line) {
    if value == nil { failures += 1; print("FAIL \(file):\(line): unexpected nil") }
}
private func XCTUnwrap<T>(_ value: T?) throws -> T {
    guard let value else { throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected nil"]) }
    return value
}

@main enum TestRunner {
    static func main() async {
        do { try await run() }
        catch {
            print("FAIL: \(error.localizedDescription)")
            Darwin.exit(1)
        }
    }
    private static func run() async throws {
        let tests = ParserTests()
        tests.testCroppedTableWithoutLogo()
        tests.testCroppedCardWithLargeRelativeSpacing()
        tests.testPlatformDetectedButShiftedColumns()
        tests.testSidebarIsNotAnAssignmentTitle()
        tests.testMissingYearIsNotInvented()
        tests.testReleaseAndLateDatesExcluded()
        tests.testWrappedTimeAndInlineTitle()
        tests.testInvalidDatesAndTimesRejected()
        tests.testDateOnlyAndDayFirstAndNumeric()
        try tests.testDSTAndCompanionBlockDoesNotShiftDeadline()
        print("10 parser/date regression scenarios completed; \(failures) failures.")
        if failures > 0 { Darwin.exit(1) }
        try await Version16Tests.run()
        try await Version161Tests.run()
        try await SetupExperienceTests.run()
        try Planner21Tests.run()
        try ImportReliabilityTests.run()
        if CommandLine.arguments.contains("--reading") { try ReadingTests.run() }
    }
}
