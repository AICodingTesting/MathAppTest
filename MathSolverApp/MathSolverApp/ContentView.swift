import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: SolverStore
    @State private var presentPhotoPicker = false
    @State private var presentCamera = false
    @State private var selectedImage: UIImage?
    @State private var isRecognizing = false
    @State private var showErrorAlert = false

    private let recognizer = MathRecognizer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    captureSection
                    recognizedTextSection
                    solutionSection
                }
                .padding(24)
            }
            .navigationTitle("Math Solver")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset", action: store.reset)
                        .disabled(store.solvingState == .processing && isRecognizing)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .sheet(isPresented: $presentPhotoPicker) {
            PhotoPickerView(image: $selectedImage)
        }
        .sheet(isPresented: $presentCamera) {
            CameraCaptureView(image: $selectedImage)
        }
        .task(id: selectedImage) {
            guard let image = selectedImage else { return }
            await processImage(image)
        }
        .alert("Error", isPresented: $showErrorAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(store.errorMessage ?? "An unknown error occurred.")
        })
    }

    private var captureSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .overlay(alignment: .bottomTrailing) {
                        Button(action: { selectedImage = nil }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(12)
                    }
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(height: 220)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Capture or import a math problem")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
            }

            HStack(spacing: 16) {
                Button(action: { presentCamera = true }) {
                    Label("Scan with Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: { presentPhotoPicker = true }) {
                    Label("Import Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var recognizedTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerLabel("Recognized Math")

            if isRecognizing {
                ProgressView("Reading math from image…")
                    .progressViewStyle(.circular)
            } else if !store.recognizedText.isEmpty {
                Text(store.recognizedText)
                    .font(.system(.title3, design: .rounded))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                placeholderLabel("No text detected yet.")
            }
        }
    }

    private var solutionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerLabel("Solution")

            switch store.solvingState {
            case .idle:
                placeholderLabel("Import math to see the solution.")
            case .processing:
                ProgressView("Solving…")
                    .progressViewStyle(.circular)
            case .completed:
                if let solution = store.solution {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Final Answer")
                                .font(.headline)
                            Text(solution.finalAnswer)
                                .font(.system(.title2, design: .rounded).bold())
                                .foregroundStyle(.primary)
                        }

                        if !solution.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Step-by-step")
                                    .font(.headline)
                                ForEach(solution.steps) { step in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.title)
                                            .font(.subheadline.bold())
                                        Text(step.description)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    placeholderLabel("No solution available.")
                }
            case .failed:
                if let error = store.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("We couldn't solve this math.")
                            .font(.headline)
                        Text(error)
                            .font(.body)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                } else {
                    placeholderLabel("An unknown error occurred.")
                }
            }
        }
    }

    private func headerLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.title2, design: .rounded).weight(.semibold))
    }

    private func placeholderLabel(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func processImage(_ image: UIImage) async {
        isRecognizing = true
        do {
            let text = try await recognizer.recognizeText(from: image)
            await store.solve(text: text)
        } catch {
            store.errorMessage = error.localizedDescription
            store.solvingState = .failed
            showErrorAlert = true
        }
        isRecognizing = false
    }
}

#Preview {
    ContentView()
        .environmentObject(SolverStore())
}
