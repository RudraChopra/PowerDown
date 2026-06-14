import Foundation

// Finds where a run memorizes and where it groks, and the energy wasted between.
struct GrokAnalysis {
    let memStep: Int?
    let grokStep: Int?
    let totalEnergyJ: Double
    let wasteJ: Double?
    let wastePct: Double?
    let finalValAcc: Double
    var grokked: Bool { grokStep != nil }

    static func analyze(_ run: RunResult,
                        memThreshold: Double = 0.95,
                        grokThreshold: Double = 0.95,
                        sustain: Int = 10) -> GrokAnalysis {
        let rows = run.rows
        let total = rows.last?.energyJ ?? 0
        let memRow = rows.first { $0.trainAcc >= memThreshold }
        let grokRow = firstSustainedGrok(rows, threshold: grokThreshold, sustain: sustain)

        var waste: Double?, pct: Double?
        if let m = memRow?.energyJ, let g = grokRow?.energyJ {
            waste = max(0, g - m)
            if total > 0 { pct = waste! / total * 100 }
        }

        return GrokAnalysis(memStep: memRow?.step, grokStep: grokRow?.step,
                            totalEnergyJ: total, wasteJ: waste, wastePct: pct,
                            finalValAcc: rows.last?.valAcc ?? 0)
    }

    // Grokking is "sustained": val accuracy has to hold above the bar for a while,
    // not just spike for one log line.
    private static func firstSustainedGrok(_ rows: [TrainingRow], threshold: Double, sustain: Int) -> TrainingRow? {
        guard rows.count >= sustain else { return nil }
        for i in 0...(rows.count - sustain)
        where rows[i..<(i + sustain)].allSatisfy({ $0.valAcc >= threshold }) {
            return rows[i]
        }
        return nil
    }
}
