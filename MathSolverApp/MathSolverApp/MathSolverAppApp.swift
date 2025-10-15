import SwiftUI

@main
struct MathSolverAppApp: App {
    @StateObject private var solverStore = SolverStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(solverStore)
        }
    }
}
