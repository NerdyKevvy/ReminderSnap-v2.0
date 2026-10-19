import AppKit
import Foundation
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
        if let flag = CommandLine.arguments.firstIndex(of: "--fixtures"), flag + 1 < CommandLine.arguments.count {
            try fixtures(directory: URL(fileURLWithPath: CommandLine.arguments[flag + 1]), temporary: root)
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
