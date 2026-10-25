import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import PDFKit
import Vision
import ImageIO
import CoreImage

public enum OCRServiceError: LocalizedError {
    case unreadableImage(String)
    case recognitionFailed(String)
    public var errorDescription: String? {
        switch self {
        case .unreadableImage(let name): return Localizer.text("Could not open: %@", arguments: [name])
        case .recognitionFailed(let message): return Localizer.text("Text recognition failed: %@", arguments: [Localizer.text(message)])
        }
    }
}

public final class OCRService {
    private lazy var imageContext = CIContext(options: [.cacheIntermediates: false])
    private var lastTextAngle: CGFloat = 0
    public init() {}

    public func recognize(url: URL) throws -> OCRDocument {
        guard let first = try recognizeAll(url: url).first else { throw OCRServiceError.unreadableImage(url.lastPathComponent) }
        return first
    }

    public func recognizeAll(url: URL, progress: ((String) -> Void)? = nil) throws -> [OCRDocument] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url), pdf.pageCount > 0 else { throw OCRServiceError.unreadableImage(url.lastPathComponent) }
            guard pdf.pageCount <= 200 else { throw OCRServiceError.recognitionFailed("Please split PDFs larger than 200 pages.") }
            var documents: [OCRDocument] = []
            for index in 0..<pdf.pageCount {
                try Task.checkCancellation()
                progress?("\(url.lastPathComponent) • page \(index + 1)/\(pdf.pageCount)")
                let doc: OCRDocument? = try autoreleasepool {
                    guard let page = pdf.page(at: index) else { return nil }
                    let name = "\(url.lastPathComponent) — page \(index + 1)"
                    if let text = embeddedText(page: page, name: name) { return text }
                    let image = page.thumbnail(of: CGSize(width: 2800, height: 2800), for: .mediaBox)
                    #if os(macOS)
                    var rect = CGRect(origin: .zero, size: image.size)
                    guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { throw OCRServiceError.unreadableImage(name) }
                    #else
                    guard let cg = image.cgImage else { throw OCRServiceError.unreadableImage(name) }
                    #endif
                    return try recognize(image: cg, name: name)
                }
                if let doc { documents.append(doc) }
            }
            return documents
        }
        return try autoreleasepool {
            try Task.checkCancellation()
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 4800,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { throw OCRServiceError.unreadableImage(url.lastPathComponent) }
            return [try recognize(image: image, name: url.lastPathComponent)]
        }
    }

    private func embeddedText(page: PDFPage, name: String) -> OCRDocument? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0,
              let selection = page.selection(for: bounds) else { return nil }
        let lines = selection.selectionsByLine().compactMap { selection -> OCRLine? in
            guard let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            let box = selection.bounds(for: page)
            return OCRLine(text: text, boundingBox: CGRect(
                x: (box.minX - bounds.minX) / bounds.width,
                y: (box.minY - bounds.minY) / bounds.height,
                width: box.width / bounds.width, height: box.height / bounds.height
            ))
        }
        // Some scanned PDFs have only a tiny or broken text layer; OCR those instead.
        guard lines.reduce(0, { $0 + $1.text.filter(\.isLetter).count }) >= 15 else { return nil }
        return OCRDocument(sourceName: name, lines: ordered(lines), readingMethod: "Embedded PDF text • no OCR")
    }

    private func recognize(image original: CGImage, name: String) throws -> OCRDocument {
        var image = original
        var lines = try read(image)
        var method = "Apple Vision • local"
        let angle = lastTextAngle
        let averageConfidence = lines.isEmpty ? 0 : lines.map(\.confidence).reduce(0, +) / Float(lines.count)
        // A bounded geometry pass for photographed screens. Screenshots with
        // horizontal text skip it; a failed or worse correction keeps the original.
        if abs(angle) > 0.012 || averageConfidence < 0.7,
           let corrected = try straightenScreen(image, angle: angle) {
            let retry = try read(corrected)
            if readingQuality(retry, name: name) >= readingQuality(lines, name: name), !retry.isEmpty {
                image = corrected; lines = retry; method += " • screen geometry correction"
            }
        }
        // Isolate the title column without dictionary correction. This recovers
        // wrapped identifiers and avoids letting nearby grades influence names.
        if let header = lines.first(where: { TaskTextPolicy.clean($0.text).lowercased() == "name" && $0.topDownY < 0.5 }),
           let status = lines.first(where: { TaskTextPolicy.clean($0.text).lowercased() == "status" && abs($0.topDownY - header.topDownY) < 0.10 }),
           lines.contains(where: { TaskTextPolicy.clean($0.text).lowercased() == "released" }) {
            let left = max(0, header.boundingBox.minX - 0.04)
            let right = max(left + 0.03, status.centerX - 0.01)
            let region = CGRect(x: left, y: 0, width: right - left, height: max(0.05, header.boundingBox.minY - 0.01))
            let rect = CGRect(x: region.minX * CGFloat(image.width), y: (1 - region.maxY) * CGFloat(image.height), width: region.width * CGFloat(image.width), height: region.height * CGFloat(image.height)).integral
            if let crop = image.cropping(to: rect) {
                let input = CIImage(cgImage: crop).transformed(by: CGAffineTransform(scaleX: 2, y: 2))
                if let enlarged = imageContext.createCGImage(input, from: input.extent) {
                    let fragments = try read(enlarged, languageCorrection: false).map {
                        OCRLine(text: $0.text, boundingBox: CGRect(x: region.minX + $0.boundingBox.minX * region.width,
                            y: region.minY + $0.boundingBox.minY * region.height,
                            width: $0.boundingBox.width * region.width, height: $0.boundingBox.height * region.height), confidence: $0.confidence)
                    }
                    if fragments.contains(where: { TaskTextPolicy.isAssignmentTitle($0.text) }) {
                        lines.removeAll { $0.topDownY > header.topDownY && $0.centerX < right && $0.centerX > left }
                        lines += fragments; method += " • title-column retry"
                    }
                }
            }
            let words = lines.filter { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "homework" && $0.topDownY > header.topDownY }
            for word in words.prefix(8) {
                let h = word.boundingBox.height
                let top = word.topDownY + h * 0.55, bottom = min(1, word.topDownY + h * 2.65)
                guard bottom - top > h, bottom < 0.99 else { continue }
                let fragment = CGRect(x: max(0, word.boundingBox.minX - h * 0.4), y: 1 - bottom,
                    width: min(h * 2.4, right - word.boundingBox.minX + h * 0.4), height: bottom - top)
                let pixels = CGRect(x: fragment.minX * CGFloat(image.width), y: top * CGFloat(image.height),
                    width: fragment.width * CGFloat(image.width), height: fragment.height * CGFloat(image.height)).integral
                guard let crop = image.cropping(to: pixels) else { continue }
                let input = CIImage(cgImage: crop).transformed(by: CGAffineTransform(scaleX: 4, y: 4))
                guard let enlarged = imageContext.createCGImage(input, from: input.extent) else { continue }
                let digits = try read(enlarged, languageCorrection: false, numericFragment: true).filter {
                    $0.text.range(of: #"^\d{1,3}$"#, options: .regularExpression) != nil
                }.map {
                    OCRLine(text: $0.text, boundingBox: CGRect(x: fragment.minX + $0.boundingBox.minX * fragment.width,
                        y: fragment.minY + $0.boundingBox.minY * fragment.height,
                        width: $0.boundingBox.width * fragment.width, height: $0.boundingBox.height * fragment.height), confidence: $0.confidence)
                }
                if !digits.isEmpty {
                    lines.removeAll { $0.text.count <= 3 && fragment.contains(CGPoint(x: $0.centerX, y: $0.boundingBox.midY)) }
                    lines += digits
                }
            }
        }
        let dateCount = lines.filter { DeadlineParser.containsDate($0.text) }.count
        let nameCount = lines.filter {
            $0.text.range(of: #"\b(?:Homework|Worksheet|Problem\s+Set|Essay|Exercise|Reading|Discussion|Experiment|Lab|Project|Quiz|Assessment|H\d+)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        }.count
        // On wide crops Vision can recognize a date column with high confidence
        // while skipping short titles across a large blank gap. Read overlapping
        // columns only when the number of missing non-date lines suggests this.
        if dateCount >= 2 && (lines.count - dateCount < dateCount || nameCount < max(1, dateCount / 3)) {
            var tiled = lines
            let regions: [CGRect] = image.width > image.height ?
                [CGRect(x: 0, y: 0, width: 0.62, height: 1), CGRect(x: 0.38, y: 0, width: 0.62, height: 1)] :
                [CGRect(x: 0, y: 0.38, width: 1, height: 0.62), CGRect(x: 0, y: 0, width: 1, height: 0.62)]
            for region in regions {
                try Task.checkCancellation()
                let pixelRect = CGRect(x: region.minX * CGFloat(image.width), y: (1 - region.maxY) * CGFloat(image.height), width: region.width * CGFloat(image.width), height: region.height * CGFloat(image.height)).integral
                guard let tile = image.cropping(to: pixelRect) else { continue }
                let recognized = try autoreleasepool { try read(tile) }
                tiled += recognized.map {
                    OCRLine(text: $0.text, boundingBox: CGRect(
                        x: region.minX + $0.boundingBox.minX * region.width,
                        y: region.minY + $0.boundingBox.minY * region.height,
                        width: $0.boundingBox.width * region.width,
                        height: $0.boundingBox.height * region.height
                    ), confidence: $0.confidence)
                }
            }
            lines = deduplicated(tiled)
            method += " • layout coverage retry"
        }
        let average = lines.isEmpty ? 0 : lines.map(\.confidence).reduce(0, +) / Float(lines.count)
        // One bounded retry only, for small/weak text; never keep a history of bitmaps.
        if lines.isEmpty || average < 0.7 {
            try Task.checkCancellation()
            if let enhanced = enhance(image) {
                let retry = try read(enhanced)
                let retryAverage = retry.isEmpty ? 0 : retry.map(\.confidence).reduce(0, +) / Float(retry.count)
                if retry.count > lines.count || retryAverage > average {
                    lines = retry; method += " • enhanced retry"
                }
            }
        }
        return OCRDocument(sourceName: name, lines: ordered(lines), readingMethod: method)
    }

    private func read(_ image: CGImage, languageCorrection: Bool = true, numericFragment: Bool = false) throws -> [OCRLine] {
        try Task.checkCancellation()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = languageCorrection
        request.recognitionLanguages = languageCorrection ? ["en-US", "zh-Hans"] : ["en-US"]
        request.automaticallyDetectsLanguage = languageCorrection
        request.minimumTextHeight = Float(max(0.0005, 2.0 / Double(image.height)))
        request.customWords = ["WebAssign", "Gradescope", "Brightspace", "Homework", "Deadline"]
        do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) }
        catch { throw OCRServiceError.recognitionFailed(error.localizedDescription) }
        try Task.checkCancellation()
        let angles = (request.results ?? []).filter { $0.boundingBox.width > 0.08 }.map {
            atan2(($0.topRight.y - $0.topLeft.y) * CGFloat(image.height),
                  ($0.topRight.x - $0.topLeft.x) * CGFloat(image.width))
        }.sorted()
        lastTextAngle = angles.isEmpty ? 0 : angles[angles.count / 2]
        return (request.results ?? []).compactMap { observation in
            let alternatives = observation.topCandidates(numericFragment ? 5 : 1)
            guard let candidate = (numericFragment ? alternatives.first(where: { $0.string.range(of: #"^\d{1,3}$"#, options: .regularExpression) != nil }) : nil) ?? alternatives.first else { return nil }
            return OCRLine(text: candidate.string, boundingBox: observation.boundingBox, confidence: candidate.confidence)
        }
    }

    private func enhance(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        let scale = min(2.0, 4000.0 / Double(max(image.width, image.height)))
        let processed = input.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0, kCIInputContrastKey: 1.15
        ]).transformed(by: CGAffineTransform(scaleX: max(1, scale), y: max(1, scale)))
        // Preserve aspect ratio and normalized OCR coordinates during retries.
        return imageContext.createCGImage(processed, from: processed.extent)
    }

    private func readingQuality(_ lines: [OCRLine], name: String) -> Double {
        let tasks = AssignmentParser().parse(documents: [OCRDocument(sourceName: name, lines: lines)])
        let confidence = lines.isEmpty ? 0 : Double(lines.map(\.confidence).reduce(0, +)) / Double(lines.count)
        return Double(tasks.count) * 20 + Double(lines.filter { TaskTextPolicy.isAssignmentTitle($0.text) }.count) * 0.05 + confidence
    }

    private func straightenScreen(_ image: CGImage, angle: CGFloat) throws -> CGImage? {
        try Task.checkCancellation()
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.8; request.minimumSize = 0.4
        request.minimumAspectRatio = 0.3; request.maximumAspectRatio = 1
        request.maximumObservations = 4; request.quadratureTolerance = 30
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let input = CIImage(cgImage: image)
        if let rectangle = request.results?.filter({ $0.boundingBox.width * $0.boundingBox.height > 0.35 }).max(by: {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }) {
            let horizontalTilt = abs(rectangle.topLeft.y - rectangle.topRight.y) + abs(rectangle.bottomLeft.y - rectangle.bottomRight.y)
            let perspective = abs(rectangle.topLeft.x - rectangle.bottomLeft.x) + abs(rectangle.topRight.x - rectangle.bottomRight.x)
            if horizontalTilt + perspective > 0.035 {
                func point(_ p: CGPoint) -> CIVector { CIVector(x: p.x * CGFloat(image.width), y: p.y * CGFloat(image.height)) }
                let corrected = input.applyingFilter("CIPerspectiveCorrection", parameters: [
                    "inputTopLeft": point(rectangle.topLeft), "inputTopRight": point(rectangle.topRight),
                    "inputBottomLeft": point(rectangle.bottomLeft), "inputBottomRight": point(rectangle.bottomRight)
                ])
                if corrected.extent.width > 200, corrected.extent.height > 100 {
                    return imageContext.createCGImage(corrected, from: corrected.extent)
                }
            }
        }
        guard abs(angle) > 0.012, abs(angle) < 0.25 else { return nil }
        let rotated = input.transformed(by: CGAffineTransform(rotationAngle: -angle))
        let white = CIImage(color: .white).cropped(to: rotated.extent)
        return imageContext.createCGImage(rotated.composited(over: white), from: rotated.extent)
    }

    private func ordered(_ lines: [OCRLine]) -> [OCRLine] {
        // Strict ordering: tolerance-based comparators are not transitive.
        lines.sorted { $0.topDownY == $1.topDownY ? $0.centerX < $1.centerX : $0.topDownY < $1.topDownY }
    }

    private func deduplicated(_ lines: [OCRLine]) -> [OCRLine] {
        var kept: [OCRLine] = []
        for line in lines.sorted(by: { $0.confidence == $1.confidence ? $0.text.count > $1.text.count : $0.confidence > $1.confidence }) {
            let text = line.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let duplicate = kept.contains { other in
                let candidate = other.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let overlap = line.boundingBox.intersection(other.boundingBox)
                let smallArea = min(line.boundingBox.width * line.boundingBox.height, other.boundingBox.width * other.boundingBox.height)
                let largeArea = max(line.boundingBox.width * line.boundingBox.height, other.boundingBox.width * other.boundingBox.height)
                let area = overlap.isNull ? 0 : overlap.width * overlap.height
                let sameObservation = smallArea > 0 && area / smallArea > 0.8 && area / largeArea > 0.55
                return abs(line.topDownY - other.topDownY) < max(line.boundingBox.height, other.boundingBox.height) &&
                    (sameObservation || text == candidate || (!overlap.isNull && (candidate.hasPrefix(text) || text.hasPrefix(candidate))))
            }
            if !duplicate { kept.append(line) }
        }
        return kept
    }
}
