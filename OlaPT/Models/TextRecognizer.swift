import Foundation
import UIKit
import Vision

/// Распознавание текста на фото прямо на устройстве (Vision). Интернет не нужен, фото никуда не отправляется.
enum TextRecognizer {

    enum Failure: LocalizedError {
        case badImage

        var errorDescription: String? {
            switch self {
            case .badImage: return "Не удалось открыть изображение."
            }
        }
    }

    /// Строки текста сверху вниз.
    static func recognize(_ image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage ?? redraw(image).cgImage else {
            throw Failure.badImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                if let supported = try? request.supportedRecognitionLanguages() {
                    let wanted = ["pt-PT", "pt-BR"].filter { supported.contains($0) }
                    if !wanted.isEmpty {
                        request.recognitionLanguages = wanted
                    }
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Перерисовка изображения без cgImage (например, из CIImage).
    private static func redraw(_ image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(at: .zero) }
    }

    /// Картинка с текстом для автотеста распознавания (запуск с аргументом -uitest-scan-sample).
    static func sampleImage() -> UIImage {
        let text = "Ontem falámos com a minha avó.\nAs casas da aldeia são bonitas.\nBom dia! O autocarro chegou tarde\nporque havia muito trânsito."
        let size = CGSize(width: 1100, height: 520)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 18
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: style
            ]
            (text as NSString).draw(in: CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80),
                                    withAttributes: attrs)
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
