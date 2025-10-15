import Foundation
import SwiftUI

@MainActor
final class SolverStore: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var solvingState: SolvingState = .idle
    @Published var solution: SolutionResult?
    @Published var errorMessage: String?

    private let solver = MathSolver()

    func solve(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            solvingState = .idle
            solution = nil
            recognizedText = ""
            return
        }
        solvingState = .processing
        recognizedText = trimmed
        do {
            let result = try await solver.solve(input: trimmed)
            self.solution = result
            self.errorMessage = nil
            self.solvingState = .completed
        } catch {
            self.solution = nil
            self.solvingState = .failed
            self.errorMessage = error.localizedDescription
        }
    }

    func reset() {
        recognizedText = ""
        solution = nil
        solvingState = .idle
        errorMessage = nil
    }
}

enum SolvingState {
    case idle
    case processing
    case completed
    case failed
}
