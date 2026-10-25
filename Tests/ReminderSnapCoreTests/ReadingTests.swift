import AppKit
import Foundation
import CoreImage
import ReminderSnapCore

enum ReadingTests {
    static func run() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReminderSnap-reading-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let keep = CommandLine.arguments.contains("--keep-fixtures")
        if keep { print("Temporary test fixtures: \(root.path)"); fflush(stdout) }
        defer { if !keep { try? FileManager.default.removeItem(at: root) } }
        let png = root.appendingPathComponent("cropped.png")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1100, pixelsHigh: 180, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: png)
        let started = Date()
        let docs = try OCRService().recognizeAll(url: png)
        guard docs.first?.fullText.contains("Homework") == true else { throw failure("Cropped PNG did not read Homework") }
        let parsed = AssignmentParser().parse(documents: docs, context: ImportContext(course: "CS-UY 1134"))
        guard parsed.count == 1, parsed.first?.hasExplicitTime == true else { throw failure("Cropped PNG failed end-to-end extraction") }
        // PhotosPicker data is copied without a trusted filename extension.
        let photoCopy = root.appendingPathComponent("photo-picker.image")
        try FileManager.default.copyItem(at: png, to: photoCopy)
        let photoDocuments = try OCRService().recognizeAll(url: photoCopy)
        guard AssignmentParser().parse(documents: photoDocuments, context: ImportContext(course: "CS-UY 1134")).count == 1 else {
            throw failure("Photos-picker extensionless image failed extraction")
        }
        print("Photos-picker image data extraction passed.")
        print(String(format: "Actual cropped PNG OCR + interpretation: %.2fs; %d task.", Date().timeIntervalSince(started), parsed.count))

        let pdf = root.appendingPathComponent("text.pdf")
        var rect = CGRect(x: 0, y: 0, width: 1100, height: 180)
        let pdfContext = CGContext(pdf as CFURL, mediaBox: &rect, nil)!
        pdfContext.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        pdfContext.endPDFPage(); pdfContext.closePDF()
        let pdfStarted = Date()
        let pdfDocs = try OCRService().recognizeAll(url: pdf)
        guard pdfDocs.first?.readingMethod.contains("Embedded PDF") == true else { throw failure("PDF unnecessarily used OCR") }
        guard AssignmentParser().parse(documents: pdfDocs).count == 1 else { throw failure("Embedded PDF extraction") }
        print(String(format: "Embedded PDF reading + interpretation: %.3fs.", Date().timeIntervalSince(pdfStarted)))
        for _ in 0..<5 {
            let warmStart = Date()
            try autoreleasepool {
                let repeated = try OCRService().recognizeAll(url: png)
                guard !repeated.isEmpty else { throw failure("Repeated import") }
            }
            print(String(format: "Warm repeated cropped-image read: %.2fs.", Date().timeIntervalSince(warmStart)))
        }
        print("Actual image/PDF smoke tests and 5 repeated reads passed.")
        try variedTables(temporary: root)
        if let flag = CommandLine.arguments.firstIndex(of: "--fixtures"), flag + 1 < CommandLine.arguments.count {
            try fixtures(directory: URL(fileURLWithPath: CommandLine.arguments[flag + 1]), temporary: root)
        }
    }
    private static func variedTables(temporary: URL) throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1800, pixelsHigh: 800, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill(); NSBezierPath(rect: CGRect(x: 0, y: 0, width: 1800, height: 800)).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 27), .foregroundColor: NSColor.black]
        func text(_ value: String, _ x: CGFloat, _ y: CGFloat) { (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes) }
        text("BIO 202 Fall 2026", 40, 730)
        for (value, x) in [("Name", CGFloat(40)), ("* Status", 620), ("Released", 1000), ("Due (EST)", 1450)] { text(value, x, 650) }
        for index in 0..<4 {
            let y = CGFloat(540 - index * 135)
            text("Problem Set \(index)", 40, y + CGFloat(index % 2) * 5)
            text(index % 2 == 0 ? "20.0 / 20.0t" : "No Submission", 620, y)
            text("Oct 01 at 8:00AM", 1000, y - 8)
            text("Nov 0\(index + 2) at 11:59PM", 1450, y - 8)
        }
        NSGraphicsContext.restoreGraphicsState()
        let original = CIImage(cgImage: bitmap.cgImage!)
        let context = CIContext(options: [.cacheIntermediates: false])
        let rotated = original.transformed(by: CGAffineTransform(rotationAngle: 0.055))
        let perspective = original.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": CIVector(x: 100, y: 810), "inputTopRight": CIVector(x: 1800, y: 720),
            "inputBottomLeft": CIVector(x: 30, y: 100), "inputBottomRight": CIVector(x: 1720, y: 30)
        ])
        for (name, source) in [("irregular-table", original), ("rotated-table", rotated), ("perspective-table", perspective)] {
            let background = CIImage(color: .white).cropped(to: source.extent.insetBy(dx: -25, dy: -25))
            let composed = source.composited(over: background)
            let image = context.createCGImage(composed, from: composed.extent)!
            let path = temporary.appendingPathComponent(name + ".png")
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: path)
            let start = Date()
            let documents = try OCRService().recognizeAll(url: path)
            let tasks = AssignmentParser().parse(documents: documents, context: ImportContext(year: 2026))
            guard tasks.count == 4, Set(tasks.map(\.assignmentName)) == Set((0..<4).map { "Problem Set \($0)" }) else {
                print("\(name) OCR: \(documents.first?.fullText ?? "")")
                throw failure("\(name) lost real assignments or included metadata: \(tasks.map(\.assignmentName))")
            }
            guard tasks.allSatisfy({ $0.courseCode == "BIO 202" && $0.dueDate != nil }) else { throw failure("\(name): course/deadline pairing") }
            print(String(format: "Actual %@ image OCR: 4 titles + correct courses/deadlines; no scores/status tasks; %.2fs.", name, Date().timeIntervalSince(start)))
        }
    }
    private static func fixtures(directory: URL, temporary: URL) throws {
        for (name, expected, crop) in [
            ("webassign", 10, CGRect(x: 0.07, y: 0.48, width: 0.59, height: 0.32)),
            ("gradescope", 1, CGRect(x: 0.19, y: 0.27, width: 0.76, height: 0.13))
        ] {
            let url = directory.appendingPathComponent(name + ".png")
            let fullDocs = try OCRService().recognizeAll(url: url)
            let full = AssignmentParser().parse(documents: fullDocs)
            guard full.count == expected else { throw failure("\(name) full screenshot: \(full.count), expected \(expected)") }
            if name == "gradescope", full.first?.assignmentName != "Worksheet 1" {
                throw failure("Gradescope matched the wrong title: \(full.first?.assignmentName ?? "missing")")
            }
            let image = NSImage(contentsOf: url)!
            var rect = CGRect(origin: .zero, size: image.size)
            let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
            let box = CGRect(x: crop.minX * CGFloat(cg.width), y: crop.minY * CGFloat(cg.height), width: crop.width * CGFloat(cg.width), height: crop.height * CGFloat(cg.height))
            let cropped = cg.cropping(to: box)!
            let png = temporary.appendingPathComponent(name + "-crop.png")
            try NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:])!.write(to: png)
            let cropDocs = try OCRService().recognizeAll(url: png)
            let context = ImportContext(course: "MA-UY 2034", year: 2026, timeZoneIdentifier: "America/New_York")
            let extracted = AssignmentParser().parse(documents: cropDocs, context: context)
            guard extracted.count == expected else {
                print("Crop extracted titles: \(extracted.map(\.assignmentName))"); fflush(stdout)
                throw failure("\(name) cropped screenshot: \(extracted.count), expected \(expected)")
            }
            if name == "gradescope", extracted.first?.assignmentName != "Worksheet 1" {
                throw failure("Gradescope crop matched the wrong title")
            }
            let merged = AssignmentParser().parse(documents: fullDocs + cropDocs, context: context)
            guard merged.count == expected else { throw failure("\(name) overlapping imports were not deduplicated") }
            if name == "gradescope" {
                for candidate in full + extracted {
                    guard let due = candidate.dueDate else { throw failure("Gradescope deadline missing") }
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: "America/New_York")!
                    let date = calendar.dateComponents([.month, .day, .hour, .minute], from: due)
                    guard date.month == 9, date.day == 20, date.hour == 23, date.minute == 59 else {
                        throw failure("Gradescope chose the release/late date instead of the normal deadline")
                    }
                }
            }
            print("Original \(name) full + cropped screenshots: \(expected) correct task(s) each; overlapping imports deduplicated.")
        }
    }
    private static func draw() {
        NSColor.white.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 1100, height: 180)).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 26), .foregroundColor: NSColor.black]
        ("Homework 5" as NSString).draw(at: CGPoint(x: 22, y: 112), withAttributes: attributes)
        ("Due September 24, 2026 at 11:59 PM EDT" as NSString).draw(at: CGPoint(x: 22, y: 56), withAttributes: attributes)
    }
    private static func failure(_ message: String) -> NSError {
        NSError(domain: "ReminderSnapReadingTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
