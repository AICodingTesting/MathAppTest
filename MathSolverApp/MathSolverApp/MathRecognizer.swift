import Foundation
import Vision
import UIKit

struct MathRecognitionError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class MathRecognizer {
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw MathRecognitionError(message: "Unable to read image data.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(throwing: MathRecognitionError(message: "No readable text detected."))
                    return
                }

                let lines = observations.compactMap { observation -> String? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return candidate.string
                }

                let combined = lines.joined(separator: "\n")
                continuation.resume(returning: combined)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.02

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
