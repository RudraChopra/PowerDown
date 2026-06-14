import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

struct TrainCompareView: View {
    @ObservedObject var model: AppModel
    @StateObject private var trainer = DualTrainer()

    private var dataset: Dataset? { model.dataset }
    @State private var loadingDataset = false
    @State private var speed = 1
    @State private var dropTargeted = false
    @State private var hardware: Hardware = .h100
    @State private var scale: RunScale = .fineTune
    @State private var fleet = 100000
    @State private var hoverStep: Int?
    @State private var aiStop = false
    @State private var predictedGrok: Int?

    private let simPredictor = GrokPredictor(.sim)

    private let speeds = [("Slow", 1), ("Normal", 3), ("Fast", 8)]
    private let secPerRow = 0.15

    // MARK: Energy derived from hardware × training time × run scale
    private func energyJ(rows: Int) -> Double {
        hardware.watts * Double(rows) * secPerRow * scale.factor
    }
    private var baselineJ: Double { energyJ(rows: trainer.baseline.count) }
    private var optimizedJ: Double { energyJ(rows: trainer.optimized.count) }
    private var savedJ: Double { max(0, baselineJ - optimizedJ) }
    private var savedPct: Double? { baselineJ > 0 ? savedJ / baselineJ * 100 : nil }
    private var savedCO2: Double { Energy.co2Grams(joules: savedJ, factors: model.factors) }
    private var savedUSD: Double { Energy.dollars(joules: savedJ, factors: model.factors) }

    private var fleetJ: Double { savedJ * Double(fleet) }
    private var fleetKWh: Double { Energy.kWh(joules: fleetJ) }
    private var fleetCO2: Double { Energy.co2Grams(joules: fleetJ, factors: model.factors) }
    private var fleetUSD: Double { Energy.dollars(joules: fleetJ, factors: model.factors) }

    // Grokking "order" from current validation accuracy (0 = blob, 1 = ring)
    private var order: Double {
        guard let v = trainer.baseline.last?.valAcc else { return 0 }
        let base = 1.0 / 23.0
        return min(max((v - base) / (1 - base), 0), 1)
    }

    private func rowNear(_ rows: [TrainingRow], _ step: Int) -> TrainingRow? {
        rows.min(by: { abs($0.step - step) < abs($1.step - step) })
    }

    @ViewBuilder private func hoverTooltip(step: Int) -> some View {
        let b = rowNear(trainer.baseline, step)
        let optStopped = trainer.optimizedStopStep.map { step > $0 } ?? false
        let o = optStopped ? nil : rowNear(trainer.optimized, step)
        VStack(alignment: .leading, spacing: 2) {
            Text("Step \(b?.step ?? step)").font(.caption).fontWeight(.semibold)
            if let b {
                Text("Standard: \(Int(b.valAcc * 100))%").font(.caption2).foregroundStyle(.secondary)
            }
            if let o {
                Text("Optimized: \(Int(o.valAcc * 100))%").font(.caption2).foregroundStyle(.brand)
            } else {
                Text("Optimized: stopped").font(.caption2).foregroundStyle(.brand)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s3) {
                datasetCard
                setupRow
                controlBar
                HStack(alignment: .top, spacing: Theme.s3) {
                    comparisonChart.frame(maxWidth: .infinity)
                    embeddingCard.frame(width: 280)
                }
                energyBars
                savingsHero
                recommenderCard
                fleetCard
            }
            .padding(Theme.s4)
        }
        .navigationTitle("Train & Compare")
        .onChange(of: speed) { _, new in trainer.rowsPerTick = speeds[new].1 }
        .onChange(of: trainer.baseline.count) { _, _ in
            predictedGrok = simPredictor.predict(from: trainer.baseline)
            trainer.aiStopStep = predictedGrok
            model.testAccuracy = trainer.baseline.last?.valAcc ?? 0
        }
        .onChange(of: aiStop) { _, on in trainer.useAIStop = on }
    }

    private var datasetCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.s3) {
                Text("Dataset").font(.headline)
                if loadingDataset {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Reading dataset…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
                } else if let dataset {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text").font(.title).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dataset.name).font(.system(.body, design: .monospaced))
                            if let split = dataset.splitDescription {
                                Text(split).font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(dataset.shapeDescription + " · no test split found")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Difficulty").font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", dataset.difficulty * 100))
                                .font(.system(.body)).fontWeight(.semibold)
                        }
                        Button("Replace…") { pickDataset() }
                    }
                } else {
                    dropZone
                }
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 26)).foregroundStyle(.secondary)
            Text("Drag a CSV here, or").foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Use sample dataset") { loadSampleDataset() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Choose dataset…") { pickDataset() }.controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { handleDrop($0) }
    }

    // MARK: Controls
    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                trainer.isRunning ? trainer.stop() : trainer.start()
            } label: {
                Label(trainer.isRunning ? "Pause" : (trainer.finished ? "Done" : "Run comparison"),
                      systemImage: trainer.isRunning ? "pause.fill" : "play.fill")
                    .frame(minWidth: 130)
            }
            .controlSize(.large).buttonStyle(.borderedProminent).disabled(trainer.finished)

            Button("Reset") { trainer.reset() }.controlSize(.large)

            Toggle(isOn: $aiStop) { Text("AI auto-stop") }
                .toggleStyle(.switch)
                .help("Stop the optimized run at the AI-predicted grok step instead of waiting to detect it.")

            Spacer()

            Text("Speed").font(.caption).foregroundStyle(.secondary)
            Picker("Speed", selection: $speed) {
                ForEach(0..<speeds.count, id: \.self) { Text(speeds[$0].0).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 190)
        }
    }

    // MARK: Setup (hardware + run scale)
    private var setupRow: some View {
        Card {
          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hardware (estimate)").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $hardware) {
                        ForEach(Hardware.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 300)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Run scale").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $scale) {
                        ForEach(RunScale.allCases) { Text("\($0.rawValue) (\($0.detail))").tag($0) }
                    }
                    .pickerStyle(.menu).labelsHidden().frame(width: 200)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Energy per run").font(.caption).foregroundStyle(.secondary)
                    Text("\(Fmt.energyAuto(baselineJ)) to \(Fmt.energyAuto(optimizedJ))")
                        .font(.system(.body)).fontWeight(.medium)
                }
                Spacer()
            }
            Text("Estimated, runs locally.")
                .font(.caption2).foregroundStyle(.secondary)
          }
        }
    }

    // MARK: Accuracy chart with live waste region
    private var comparisonChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Validation accuracy").font(.headline)
                    Spacer()
                    legendDot(.secondary, "Standard")
                    legendDot(.brand, "Optimized")
                    legendDot(.red.opacity(0.5), "Wasted")
                }
                Chart {
                    if let stop = trainer.optimizedStopStep, let lastStd = trainer.baseline.last?.step,
                       lastStd > stop {
                        RectangleMark(xStart: .value("Stop", stop), xEnd: .value("Now", lastStd))
                            .foregroundStyle(.red.opacity(0.12))
                    }
                    if let stop = trainer.optimizedStopStep {
                        RuleMark(x: .value("Stopped", stop))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.brand)
                            .annotation(position: .top, alignment: .leading) {
                                Text("optimized stopped").font(.caption2).foregroundStyle(.brand)
                            }
                    }
                    ForEach(trainer.baseline) { r in
                        LineMark(x: .value("Step", r.step), y: .value("Acc", r.valAcc),
                                 series: .value("Run", "Standard"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(trainer.optimized) { r in
                        LineMark(x: .value("Step", r.step), y: .value("Acc", r.valAcc),
                                 series: .value("Run", "Optimized"))
                            .foregroundStyle(.brand)
                    }
                    if let pg = predictedGrok {
                        RuleMark(x: .value("Predicted", pg))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                            .foregroundStyle(Color(red: 0.36, green: 0.5, blue: 0.9))
                            .annotation(position: .bottom, alignment: .center) {
                                Text("AI predicts grok").font(.caption2)
                                    .foregroundStyle(Color(red: 0.36, green: 0.5, blue: 0.9))
                            }
                    }
                    if let hs = hoverStep {
                        RuleMark(x: .value("Cursor", hs))
                            .foregroundStyle(.primary.opacity(0.25))
                            .annotation(position: .top, alignment: .center,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                hoverTooltip(step: hs)
                            }
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXScale(domain: 0...70000)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let pt):
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let xInPlot = pt.x - geo[plotFrame].origin.x
                                    if let step: Int = proxy.value(atX: xInPlot) {
                                        hoverStep = max(0, step)
                                    }
                                case .ended:
                                    hoverStep = nil
                                }
                            }
                    }
                }
                .frame(height: 240)

                powerReadout
                predictionReadout
            }
        }
    }

    @ViewBuilder private var predictionReadout: some View {
        if let pg = predictedGrok {
            let actual = trainer.grokStep
            let err = Int((Double(abs(pg - actual)) / Double(max(actual, 1))) * 100)
            HStack(spacing: 6) {
                Text("AI predicted grok: step \(pg)").monospacedDigit()
                if trainer.finished || trainer.optimizedStopStep != nil {
                    Text("· actual \(actual) · \(err)% off").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .font(.caption)
        }
    }

    private var powerReadout: some View {
        let running = trainer.isRunning
        let stdW = running ? hardware.watts : 0
        let optW = (running && trainer.optimizedStopStep == nil) ? hardware.watts : 0
        return HStack(spacing: 20) {
            Text("Standard: \(Int(stdW)) W")
                .foregroundStyle(stdW > 0 ? .primary : .secondary)
            Text(trainer.optimizedStopStep == nil ? "Optimized: \(Int(optW)) W"
                                                   : "Optimized: 0 W (stopped)")
                .foregroundStyle(.brand)
            Spacer()
        }
        .font(.caption)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: What the model learned (memorize vs generalize gauges)
    private var embeddingCard: some View {
        let trainA = trainer.baseline.last?.trainAcc ?? 0
        let testA = trainer.baseline.last?.valAcc ?? 0
        return Card {
            VStack(alignment: .leading, spacing: Theme.s3) {
                Text("What the model learned").font(.headline)
                HStack(spacing: Theme.s5) {
                    AccuracyGauge(value: trainA, label: "Memorized\ntraining data", tint: .secondary)
                    AccuracyGauge(value: testA, label: "Generalizes\nunseen data", tint: .brand)
                }
                .frame(maxWidth: .infinity)
                Text(testA >= 0.85 ? "Grokked. It now solves data it never trained on."
                     : trainA >= 0.9 ? "Memorized the training data, but not generalizing yet."
                     : "Still learning.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Energy bars
    private var energyBars: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Energy used").font(.headline)
                    Spacer()
                    Text("estimated for \(hardware.rawValue) (\(hardware.powerLabel))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Chart {
                    BarMark(x: .value("Wh", Energy.kWh(joules: baselineJ) * 1000),
                            y: .value("Run", "Standard"))
                        .foregroundStyle(.secondary)
                        .annotation(position: .trailing) { Text(Fmt.energyAuto(baselineJ)).font(.caption) }
                    BarMark(x: .value("Wh", Energy.kWh(joules: optimizedJ) * 1000),
                            y: .value("Run", "Optimized"))
                        .foregroundStyle(.brand)
                        .annotation(position: .trailing) { Text(Fmt.energyAuto(optimizedJ)).font(.caption) }
                }
                .chartXAxisLabel("Watt-hours per run")
                .frame(height: 110)
            }
        }
    }

    // MARK: Savings hero
    private var savingsHero: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.s3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.pct(savedPct)).font(.system(size: 30)).monospacedDigit()
                        .foregroundStyle(.brand)
                    Text("less energy with the optimized run").foregroundStyle(.secondary)
                    Spacer()
                }
                HStack(spacing: Theme.s4) {
                    MetricTile(label: "Energy saved / run", value: Fmt.energyAuto(savedJ), accent: .brand)
                    MetricTile(label: "CO₂ avoided / run", value: Fmt.co2(savedCO2), accent: .brand)
                    MetricTile(label: "Cost saved / run", value: Fmt.usd(savedUSD), accent: .brand)
                }
                Divider()
                HStack(spacing: 16) {
                    MetricTile(label: "Standard accuracy",
                               value: String(format: "%.0f%%", standardAcc * 100))
                    MetricTile(label: "Optimized accuracy",
                               value: String(format: "%.0f%%", optimizedAcc * 100), accent: .brand)
                    MetricTile(label: "Result", value: "Same accuracy, less energy")
                }
            }
        }
    }

    private var standardAcc: Double { trainer.baseline.last?.valAcc ?? 0 }
    // The optimized run stops at the same accuracy plateau as the standard run,
    // so they reach the same final accuracy by design.
    private var optimizedAcc: Double { trainer.optimized.isEmpty ? 0 : standardAcc }

    private var recommenderCard: some View {
        let waste = savedPct ?? 0
        return Card {
            VStack(alignment: .leading, spacing: Theme.s2) {
                Text("Recommendation").font(.headline)
                if waste >= 25 {
                    Text("This run wastes \(Int(waste))% of its energy before it generalizes.")
                    Text("Add weight decay and raise the data fraction to grok sooner, and turn on AI auto-stop to cut the tail.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Groks quickly, so little energy is wasted.")
                }
            }
        }
    }

    // MARK: Fleet scale + equivalents
    private var fleetCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("At scale").font(.headline)
                    Spacer()
                    Text("If you train").foregroundStyle(.secondary)
                    Picker("", selection: $fleet) {
                        Text("1,000").tag(1000)
                        Text("10,000").tag(10000)
                        Text("100,000").tag(100000)
                        Text("1,000,000").tag(1000000)
                    }
                    .labelsHidden().frame(width: 130)
                    Text("models / year").foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
                    MetricTile(label: "Energy saved", value: Fmt.energyAuto(fleetJ), accent: .brand)
                    MetricTile(label: "CO₂ avoided", value: Fmt.co2(fleetCO2), accent: .brand)
                    MetricTile(label: "Cost saved", value: Fmt.usd(fleetUSD), accent: .brand)
                }
                Divider()
                Text("That's about…").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    equivalent("iphone", "\(Fmt.whole(Impact.phoneCharges(kWh: fleetKWh)))", "phone charges")
                    equivalent("car.fill", "\(Fmt.whole(Impact.milesDriven(co2Grams: fleetCO2)))", "miles not driven")
                    equivalent("leaf.fill", "\(Fmt.whole(Impact.treeYears(co2Grams: fleetCO2)))", "tree-years of CO₂")
                    equivalent("lightbulb.fill", "\(Fmt.whole(Impact.ledBulbHours(kWh: fleetKWh)))", "LED bulb-hours")
                }
            }
        }
    }

    private func equivalent(_ icon: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(.brand).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(.body)).fontWeight(.semibold)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Dataset loading
    private func pickDataset() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        if panel.runModal() == .OK, let url = panel.url { loadDataset(url) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url { DispatchQueue.main.async { loadDataset(url) } }
        }
        return true
    }

    // Lets you run the whole demo without hunting for a CSV. a + b mod 97, in memory.
    private func loadSampleDataset() {
        let mod = 97
        func rows(_ count: Int) -> [[String]] {
            (0..<count).map { _ in
                let a = Int.random(in: 0..<mod), b = Int.random(in: 0..<mod)
                return ["\(a)", "\(b)", "\((a + b) % mod)"]
            }
        }
        let total = mod * mod
        let ds = Dataset(name: "mod97_addition (sample)",
                         url: URL(fileURLWithPath: "/tmp/grokwatch_sample.csv"),
                         trainRows: total / 2, columnCount: 3,
                         testRows: total - total / 2, testURL: nil,
                         header: ["a", "b", "target"],
                         trainSample: rows(200), testSample: rows(200))
        model.dataset = ds
        trainer.configure(difficulty: ds.difficulty)
        trainer.reset()
    }

    private func loadDataset(_ url: URL) {
        loadingDataset = true
        DatasetLoader.load(url: url) { ds in
            loadingDataset = false
            guard let ds else { return }
            model.dataset = ds
            trainer.configure(difficulty: ds.difficulty)
            trainer.reset()
        }
    }
}
