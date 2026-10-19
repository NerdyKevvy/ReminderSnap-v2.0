import Foundation
import Darwin
import ReminderSnapCore

@main
struct ReminderSnapCLI {
    static func main() throws {
        var paths = Array(CommandLine.arguments.dropFirst())
        if paths == ["--self-test"] {
            try runSelfTests()
            print("All ReminderSnap self-tests passed.")
            return
        }
        let dumpOCR = paths.first == "--dump-ocr" || ProcessInfo.processInfo.environment["REMINDERSNAP_DUMP_OCR"] == "1"
        if paths.first == "--dump-ocr" { paths.removeFirst() }
        guard !paths.isEmpty else {
            FileHandle.standardError.write(Data("Usage: remindersnap-cli screenshot.png [...]\n".utf8))
            Darwin.exit(2)
        }

        let service = OCRService()
        let documents = try paths.flatMap { try service.recognizeAll(url: URL(fileURLWithPath: $0)) }

        if dumpOCR {
            for document in documents {
                print("=== \(document.sourceName) ===")
                for line in document.lines {
                    print(String(format: "y=%.3f x=%.3f  %@", line.topDownY, line.centerX, line.text))
                }
            }
            return
        }

        let results = AssignmentParser().parse(documents: documents)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(results)
        print(String(decoding: data, as: UTF8.self))
    }

    private static func runSelfTests() throws {
        try require(CourseNormalizer.tag(from: "MA-UY 2034") == "#MA2034", "MA course tag")
        try require(CourseNormalizer.tag(from: "CS-UY 1134") == "#CS1134", "CS course tag")

        let timed = DeadlineParser.parse("Wednesday, September 16, 2026 at 11:59 PM EDT")
        try require(timed?.hasExplicitTime == true, "timed deadline")
        try require(timed?.timeZoneIdentifier == "America/New_York", "Eastern time zone")
        if let timed {
            let candidate = AssignmentCandidate(
                courseCode: "MA-UY 2034",
                assignmentName: "Schedule test",
                dueDate: timed.date,
                hasExplicitTime: timed.hasExplicitTime,
                timeZoneIdentifier: timed.timeZoneIdentifier,
                sourcePlatform: .unknown,
                sourceImages: []
            )
            guard let block = CompanionBlockSchedule.range(for: candidate) else {
                throw NSError(domain: "ReminderSnapSelfTest", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Self-test failed: companion block range"
                ])
            }
            var eastern = Calendar(identifier: .gregorian)
            eastern.timeZone = TimeZone(identifier: "America/New_York")!
            let startParts = eastern.dateComponents([.hour, .minute], from: block.start)
            let endParts = eastern.dateComponents([.hour, .minute], from: block.end)
            try require(startParts.hour == 22 && startParts.minute == 0, "companion block starts at 22:00")
            try require(endParts.hour == 23 && endParts.minute == 0, "companion block ends at 23:00")
        }
        try require(DeadlineParser.parse("September 16, 2026")?.hasExplicitTime == false, "all-day deadline")
        try require(
            DeadlineParser.parse("Due on Sep 24, 2026 11:59 PM")?.hasExplicitTime == true,
            "Brightspace deadline"
        )
        try require(
            DeadlineParser.parse("Due Sep 30, 2026 by 11:59pm")?.hasExplicitTime == true,
            "Canvas deadline"
        )
        try require(
            DeadlineParser.parse("Due: Friday, 18 September 2026, 11:59 PM")?.hasExplicitTime == true,
            "day-first Moodle deadline"
        )

        let lines = [
            OCRLine(text: "CENGAGE | WEBASSIGN", boundingBox: box(x: 0.05, topY: 0.05, width: 0.2)),
            OCRLine(text: "MA-UY 2034: Linear Algebra, Fall 2026", boundingBox: box(x: 0.05, topY: 0.12, width: 0.35)),
            OCRLine(text: "CURRENT ASSIGNMENTS", boundingBox: box(x: 0.05, topY: 0.20, width: 0.2)),
            OCRLine(text: "DUE DATE", boundingBox: box(x: 0.52, topY: 0.20, width: 0.12)),
            OCRLine(text: "SCORE", boundingBox: box(x: 0.80, topY: 0.20, width: 0.1)),
            OCRLine(text: "H1_S26 Separable First Order Linear DE (Homework)", boundingBox: box(x: 0.06, topY: 0.30, width: 0.35)),
            OCRLine(text: "Wednesday, September 16, 2026 at 11:59 PM EDT", boundingBox: box(x: 0.52, topY: 0.30, width: 0.25)),
            OCRLine(text: "- / 41", boundingBox: box(x: 0.80, topY: 0.30, width: 0.08))
        ]
        let results = AssignmentParser().parse(
            documents: [OCRDocument(sourceName: "test.png", lines: lines)]
        )
        try require(results.count == 1, "detailed WebAssign row count")
        try require(results.first?.reminderTitle == "#MA2034 H1_S26 Separable First Order Linear DE (Homework) 41 Questions", "detailed reminder title")

        let brightspaceLines = [
            OCRLine(text: "brightspace.nyu.edu/d2l/lms/dropbox", boundingBox: box(x: 0.12, topY: 0.10, width: 0.40)),
            OCRLine(text: "CS-UY 1134 - Fall 2026", boundingBox: box(x: 0.22, topY: 0.20, width: 0.30)),
            OCRLine(text: "Assignment", boundingBox: box(x: 0.22, topY: 0.38, width: 0.20)),
            OCRLine(text: "Homework #1", boundingBox: box(x: 0.22, topY: 0.50, width: 0.18)),
            OCRLine(text: "Not Complete", boundingBox: box(x: 0.54, topY: 0.50, width: 0.15)),
            OCRLine(text: "Due on Sep 24, 2026 11:59 PM", boundingBox: box(x: 0.22, topY: 0.52, width: 0.28)),
            OCRLine(text: "Starts Sep 14", boundingBox: box(x: 0.22, topY: 0.55, width: 0.14))
        ]
        let brightspace = AssignmentParser().parse(
            documents: [OCRDocument(sourceName: "brightspace.png", lines: brightspaceLines)]
        )
        try require(brightspace.count == 1, "Brightspace row count")
        try require(brightspace.first?.sourcePlatform == .brightspace, "Brightspace detection")
        try require(brightspace.first?.reminderTitle == "#CS1134 Homework #1", "Brightspace title")

        let canvasLines = [
            OCRLine(text: "canvas.instructure.com/courses/123/assignments", boundingBox: box(x: 0.10, topY: 0.10, width: 0.45)),
            OCRLine(text: "CS-UY 1134 Fall 2026", boundingBox: box(x: 0.18, topY: 0.20, width: 0.28)),
            OCRLine(text: "Project 2", boundingBox: box(x: 0.20, topY: 0.42, width: 0.16)),
            OCRLine(text: "Due Sep 30, 2026 by 11:59pm", boundingBox: box(x: 0.20, topY: 0.45, width: 0.30))
        ]
        let canvas = AssignmentParser().parse(
            documents: [OCRDocument(sourceName: "canvas.png", lines: canvasLines)]
        )
        try require(canvas.count == 1, "Canvas row count")
        try require(canvas.first?.sourcePlatform == .canvas, "Canvas detection")

        let moodleLines = [
            OCRLine(text: "moodle.nyu.edu", boundingBox: box(x: 0.10, topY: 0.10, width: 0.30)),
            OCRLine(text: "MA-UY 2034 Fall 2026", boundingBox: box(x: 0.18, topY: 0.20, width: 0.28)),
            OCRLine(text: "Lab Report", boundingBox: box(x: 0.20, topY: 0.42, width: 0.16)),
            OCRLine(text: "Due: Friday, 18 September 2026, 11:59 PM", boundingBox: box(x: 0.20, topY: 0.45, width: 0.38))
        ]
        let moodle = AssignmentParser().parse(
            documents: [OCRDocument(sourceName: "moodle.png", lines: moodleLines)]
        )
        try require(moodle.count == 1, "Moodle row count")
        try require(moodle.first?.sourcePlatform == .moodle, "Moodle detection")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ name: String) throws {
        guard condition() else {
            throw NSError(domain: "ReminderSnapSelfTest", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Self-test failed: \(name)"
            ])
        }
    }

    private static func box(x: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat = 0.02) -> CGRect {
        CGRect(x: x, y: 1 - topY - height / 2, width: width, height: height)
    }
}
