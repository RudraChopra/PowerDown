import Foundation

// Columns: step, elapsed_s, train_acc, val_acc, grad_norm, activation_sparsity,
// energy_j, mean_power_w, raw_power_w
enum CSVParser {
    static func parseRows(url: URL) -> [TrainingRow]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var rows: [TrainingRow] = []
        let lines = content.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else { return nil }

        for line in lines.dropFirst() {  // skip header
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 9,
                  let step = Int(f[0].trimmingCharacters(in: .whitespaces)),
                  let elapsed = Double(f[1]),
                  let trainAcc = Double(f[2]),
                  let valAcc = Double(f[3]),
                  let grad = Double(f[4]),
                  let sparsity = Double(f[5]),
                  let energy = Double(f[6]),
                  let meanP = Double(f[7]),
                  let rawP = Double(f[8])
            else { continue }

            rows.append(TrainingRow(step: step, elapsedS: elapsed, trainAcc: trainAcc,
                                    valAcc: valAcc, gradNorm: grad, activationSparsity: sparsity,
                                    energyJ: energy, meanPowerW: meanP, rawPowerW: rawP))
        }
        return rows.isEmpty ? nil : rows
    }

    static func parseRun(url: URL, name: String? = nil) -> RunResult? {
        guard let rows = parseRows(url: url) else { return nil }
        let display = name ?? url.deletingPathExtension().lastPathComponent
        return RunResult(name: display, rows: rows)
    }

    // Walks a folder tree and loads every CSV, labelling each "<parent>/<file>".
    static func loadFolder(url: URL) -> [RunResult] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) else { return [] }
        var results: [RunResult] = []
        for case let file as URL in enumerator where file.pathExtension.lowercased() == "csv" {
            let parent = file.deletingLastPathComponent().lastPathComponent
            let base = file.deletingPathExtension().lastPathComponent
            let label = (parent == url.lastPathComponent) ? base : "\(parent)/\(base)"
            if let run = parseRun(url: file, name: label) {
                results.append(run)
            }
        }
        return results.sorted { $0.name < $1.name }
    }
}
