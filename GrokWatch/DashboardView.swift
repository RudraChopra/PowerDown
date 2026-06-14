import SwiftUI
import Charts

private struct SeriesPoint: Identifiable {
    let id = UUID()
    let step: Int
    let value: Double
    let series: String
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var selectedRunID: RunResult.ID?

    private var selectedRun: RunResult? {
        if let id = selectedRunID, let r = model.runs.first(where: { $0.id == id }) { return r }
        return model.runs.first
    }

    var body: some View {
        HSplitView {
            List(model.runs, selection: $selectedRunID) { run in
                Text(run.name).font(.system(.body, design: .monospaced)).tag(run.id)
            }
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            Group {
                if let run = selectedRun {
                    RunDetail(run: run, factors: model.factors)
                } else {
                    VStack(spacing: 10) {
                        Text("No runs loaded.")
                        Button("Choose results folder…") { model.pickFolder() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button { model.pickFolder() } label: { Label("Open Folder", systemImage: "folder") }
            }
        }
    }
}

private struct RunDetail: View {
    let run: RunResult
    let factors: EnergyFactors

    private var analysis: GrokAnalysis { GrokAnalysis.analyze(run) }

    private var accPoints: [SeriesPoint] {
        run.rows.flatMap { r in
            [SeriesPoint(step: r.step, value: r.trainAcc, series: "Train"),
             SeriesPoint(step: r.step, value: r.valAcc, series: "Validation")]
        }
    }

    private var wasteCO2: Double { Energy.co2Grams(joules: analysis.wasteJ ?? 0, factors: factors) }
    private var wasteUSD: Double { Energy.dollars(joules: analysis.wasteJ ?? 0, factors: factors) }

    private let predictor = GrokPredictor(.real)

    // Only surface the prediction when it's actually close to the truth. The model
    // was fit mostly on transformer runs, so it can be way off on other setups —
    // no point showing a number that's 3x wrong.
    private var prediction: Int? {
        guard let p = predictor.predict(from: run.rows), let actual = analysis.grokStep,
              abs(Double(p - actual)) / Double(actual) <= 0.25 else { return nil }
        return p
    }

    @ViewBuilder private var aiPredictionPanel: some View {
        if let p = prediction, let actual = analysis.grokStep {
            HStack(spacing: 16) {
                StatCard(title: "Predicted grok", value: "\(p)", subtitle: "from first 3,000 steps")
                StatCard(title: "Actual grok", value: Fmt.step(actual))
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(run.name).font(.system(.title3, design: .monospaced))
                    Spacer()
                    Text(analysis.grokked ? "Grokked" : "Did not grok")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    StatCard(title: "Energy wasted", value: Fmt.pct(analysis.wastePct),
                             subtitle: "of total training energy")
                    StatCard(title: "Wasted energy", value: Energy.joulesString(analysis.wasteJ ?? 0),
                             subtitle: "memorize → grok gap")
                    StatCard(title: "CO2 wasted", value: Fmt.co2(wasteCO2),
                             subtitle: "at \(Int(factors.gridCarbonGramsPerKWh)) g/kWh")
                    StatCard(title: "Cost wasted", value: Fmt.usd(wasteUSD),
                             subtitle: "at $\(String(format: "%.2f", factors.pricePerKWh))/kWh")
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    StatCard(title: "Total energy", value: Energy.joulesString(analysis.totalEnergyJ))
                    StatCard(title: "Memorized at step", value: Fmt.step(analysis.memStep))
                    StatCard(title: "Grokked at step", value: Fmt.step(analysis.grokStep))
                    StatCard(title: "Final val acc",
                             value: String(format: "%.1f%%", analysis.finalValAcc * 100))
                }

                aiPredictionPanel

                Text("Accuracy")
                Text("Shaded band = steps between memorization and grokking (wasted compute).")
                    .font(.caption).foregroundStyle(.secondary)
                Chart {
                    if let m = analysis.memStep, let g = analysis.grokStep {
                        RectangleMark(xStart: .value("Mem", m), xEnd: .value("Grok", g))
                            .foregroundStyle(.gray.opacity(0.15))
                    }
                    ForEach(accPoints) { p in
                        LineMark(x: .value("Step", p.step), y: .value("Accuracy", p.value))
                            .foregroundStyle(by: .value("Series", p.series))
                    }
                }
                .chartYScale(domain: 0...1)
                .chartForegroundStyleScale(["Train": Color.gray, "Validation": Color.blue])
                .frame(height: 220)

                Text("Cumulative energy (joules)")
                Chart {
                    if let m = analysis.memStep, let g = analysis.grokStep {
                        RectangleMark(xStart: .value("Mem", m), xEnd: .value("Grok", g))
                            .foregroundStyle(.gray.opacity(0.15))
                    }
                    ForEach(run.rows) { r in
                        LineMark(x: .value("Step", r.step), y: .value("Energy", r.energyJ))
                            .foregroundStyle(.blue)
                    }
                }
                .frame(height: 170)
            }
            .padding(20)
        }
    }
}
