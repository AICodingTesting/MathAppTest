# MathSolverApp

MathSolverApp is a SwiftUI iOS application that captures handwritten or printed math problems, recognizes them with Apple's Vision framework, and solves them locally using a symbolic/numeric engine. The app delivers final answers along with detailed step-by-step reasoning for arithmetic, algebra, calculus, and first-order differential equations—without relying on any network services.

## Features
- Camera capture and photo import using `UIImagePickerController` and `PHPickerViewController`.
- On-device OCR with `VNRecognizeTextRequest` for high-quality math recognition.
- Custom math parser and solver that handles:
  - Arithmetic expressions and symbolic simplification.
  - Linear and nonlinear equations via analytic and Newton-Raphson methods.
  - Single-variable derivatives and integrals.
  - First-order separable differential equations.
- Clean SwiftUI interface with responsive layout and graceful error handling.
- Full compliance with iOS 16 requirements and Swift 5.10+ language features.

## Requirements
- Xcode 16 or later.
- iOS 16 deployment target (runs on iPhone and iPad simulators/devices).
- No external dependencies; all processing is performed locally.

## Getting Started
1. Open `MathSolverApp.xcodeproj` in Xcode 16.
2. Select the **MathSolverApp** scheme and your preferred simulator or device.
3. Build and run (`⌘ + R`).
4. Use the **Scan with Camera** or **Import Photo** actions to provide a math problem.
5. Review the recognized text, final answer, and detailed steps directly in the app.

## Assets

The app icon is provided as a resolution-independent SVG stored inside the asset catalog. Xcode will rasterize it to the
required sizes during the build, keeping the repository free of binary image blobs.

## Privacy
MathSolverApp performs all text recognition and solving locally on-device. The app does not transmit images or computations to any external services.
