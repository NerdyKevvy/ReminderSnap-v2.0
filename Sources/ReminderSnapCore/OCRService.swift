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

    private func recognize(image: CGImage, name: String) throws -> OCRDocument {
        var lines = try read(image)
        var method = "Apple Vision • local"
        let dateCount = lines.filter { DeadlineParser.containsDate($0.text) }.count
        // On wide crops Vision can recognize a date column with high confidence
        // while skipping short titles across a large blank gap. Read overlapping
        // columns only when the number of missing non-date lines suggests this.
        if image.width > image.height * 2, dateCount > 0, lines.count - dateCount < dateCount {
            var tiled = lines
            for fraction in [CGFloat(0), CGFloat(0.38)] {
                try Task.checkCancellation()
                let x = (CGFloat(image.width) * fraction).rounded(.down)
                let width = min(CGFloat(image.width) - x, (CGFloat(image.width) * 0.62).rounded(.up))
                guard let tile = image.cropping(to: CGRect(x: x, y: 0, width: width, height: CGFloat(image.height))) else { continue }
                let recognized = try autoreleasepool { try read(tile) }
                tiled += recognized.map {
                    OCRLine(text: $0.text, boundingBox: CGRect(
                        x: (x + $0.boundingBox.minX * width) / CGFloat(image.width),
                        y: $0.boundingBox.minY,
                        width: $0.boundingBox.width * width / CGFloat(image.width),
                        height: $0.boundingBox.height
                    ), confidence: $0.confidence)
                }
            }
            lines = deduplicated(tiled)
            method += " • column retry"
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

    private func read(_ image: CGImage) throws -> [OCRLine] {
        try Task.checkCancellation()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = Float(max(0.0005, 2.0 / Double(image.height)))
        request.customWords = ["WebAssign", "Gradescope", "Brightspace", "Homework", "Deadline"]
        do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) }
        catch { throw OCRServiceError.recognitionFailed(error.localizedDescription) }
        try Task.checkCancellation()
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRLine(text: candidate.string, boundingBox: observation.boundingBox, confidence: candidate.confidence)
        }
    }

    private func enhance(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        let scale = min(2.0, 4000.0 / Double(max(image.width, image.height)))
        let processed = input.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0, kCIInputContrastKey: 1.15
        ]).transformed(by: CGAffineTransform(scaleX: max(1, scale), y: max(1, scale)))
        let padding: CGFloat = 16
        let extent = processed.extent.insetBy(dx: -padding, dy: -padding)
        let background = CIImage(color: CIColor.white).cropped(to: extent)
        return imageContext.createCGImage(processed.composited(over: background), from: extent)
    }

    private func ordered(_ lines: [OCRLine]) -> [OCRLine] {
        // Strict ordering: tolerance-based comparators are not transitive.
        lines.sorted { $0.topDownY == $1.topDownY ? $0.centerX < $1.centerX : $0.topDownY < $1.topDownY }
    }

    private func deduplicated(_ lines: [OCRLine]) -> [OCRLine] {
        var kept: [OCRLine] = []
        for line in lines.sorted(by: { $0.text.count > $1.text.count }) {
            let text = line.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let duplicate = kept.contains { other in
                let candidate = other.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let overlap = line.boundingBox.intersection(other.boundingBox)
                return abs(line.topDownY - other.topDownY) < max(line.boundingBox.height, other.boundingBox.height) &&
                    (text == candidate || (!overlap.isNull && (candidate.hasPrefix(text) || text.hasPrefix(candidate))))
            }
            if !duplicate { kept.append(line) }
        }
        return kept
    }
}
