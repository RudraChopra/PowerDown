import Foundation
import AppKit

struct TrainingRow: Identifiable {
    let id = UUID()
    let step: Int
    let elapsedS: Double
    let trainAcc: Double
    let valAcc: Double
    let gradNorm: Double
    let activationSparsity: Double
    let energyJ: Double      // cumulative, idle-subtracted
    let meanPowerW: Double
    let rawPowerW: Double
}

struct RunResult: Identifiable {
    let id = UUID()
    let name: String
    let rows: [TrainingRow]
}

final class AppModel: ObservableObject {
    @Published var runs: [RunResult] = []
    @Published var folderURL: URL?
    @Published var factors = EnergyFactors()

    // Dataset + live test accuracy live here so the Quiz tab tracks whatever the
    // training in Train & Compare is doing, without the two views talking directly.
    @Published var dataset: Dataset?
    @Published var testAccuracy = 0.0

    init() {
        let results = URL(fileURLWithPath: "/Users/yogeshatluru/Downloads/results")
        if FileManager.default.fileExists(atPath: results.path) {
            folderURL = results
            runs = CSVParser.loadFolder(url: results)
        }
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderURL = url
        runs = CSVParser.loadFolder(url: url)
    }
}
