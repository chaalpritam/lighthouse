import Foundation
import Vision
import UIKit
import PhotosUI

@MainActor
final class FieldCaptureService {
    private let capturesDirectory: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    func savePhoto(_ image: UIImage) throws -> String {
        let filename = "capture_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let url = capturesDirectory.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CaptureError.encodeFailed
        }
        try data.write(to: url, options: .atomic)
        return url.path
    }

    func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    enum CaptureError: LocalizedError {
        case encodeFailed
        var errorDescription: String? { "Could not encode photo" }
    }
}
