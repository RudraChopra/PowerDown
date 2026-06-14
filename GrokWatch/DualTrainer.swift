import Foundation

private extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}

// Drives two runs at once: `baseline` trains the full schedule, `optimized`
// stops once it's grokked. Same curve, same final accuracy — the optimized one
// just doesn't keep burning power after it's done. It's a simulation, not a real
// model; dataset difficulty sets how late it groks.
final class DualTrainer: ObservableObject {
    @Published private(set) var baseline: [TrainingRow] = []
    @Published private(set) var optimized: [TrainingRow] = []
    @Published private(set) var isRunning = false
    @Published private(set) var finished = false
    @Published private(set) var optimizedStopStep: Int?

    var rowsPerTick = 3   // how fast the curve fills in on screen

    private let tickInterval = 0.05
    private let stepsPerRow = 100
    private let maxRows = 700
    private let modulus = 23

    // When on, the optimized run stops at the predicted step (set by the view)
    // instead of waiting to detect the plateau itself.
    var useAIStop = false
    var aiStopStep: Int?

    private var grokRow = 380
    private let memRow = 4
    private var valCeiling = 0.985   // real runs top out below 100%, so this one does too
    private var i = 0
    private var energyBaseline = 0.0
    private var energyOptimized = 0.0
    private var optStopped = false
    private var timer: Timer?

    var baselineEnergyJ: Double { baseline.last?.energyJ ?? 0 }
    var optimizedEnergyJ: Double { optimized.last?.energyJ ?? 0 }
    var grokStep: Int { grokStepValue ?? grokRow * stepsPerRow }
    private var grokStepValue: Int?

    // Harder dataset → groks later → bigger wasted tail.
    func configure(difficulty: Double) {
        let d = min(max(difficulty, 0), 1)
        grokRow = Int(280 + d * 200)
    }

    func reset() {
        timer?.invalidate(); timer = nil
        baseline = []; optimized = []
        i = 0; energyBaseline = 0; energyOptimized = 0
        optStopped = false; isRunning = false; finished = false
        optimizedStopStep = nil
        grokStepValue = nil
        valCeiling = Double.random(in: 0.97...0.995)
    }

    func start() {
        guard !isRunning, !finished else { return }
        isRunning = true
        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
        isRunning = false
    }

    private func tick() {
        for _ in 0..<rowsPerTick {
            if i >= maxRows { stop(); finished = true; return }
            advance()
            i += 1
        }
    }

    private func advance() {
        let x = Double(i)
        let base = 1.0 / Double(modulus)

        let trainRaw = logistic(x, mid: Double(memRow), k: 1.2) + noise(0.01)
        let train = trainRaw.clamped(0.05, 1)

        let grokCurve = logistic(x, mid: Double(grokRow), k: 0.06)
        let valRaw = base + (valCeiling - base) * grokCurve + noise(0.004)
        let val = valRaw.clamped(0, valCeiling)

        let power = 4.8 + noise(0.4)
        let dt = 0.15
        let grad = 9 * exp(-Double(i) / 120) + 1 + noise(0.2)
        // Activation sparsity creeps up early in proportion to how soon the run
        // will grok — the precursor signal the predictor reads.
        let sparsity = min(max(0.55 * (Double(i) / Double(grokRow))
                                 + (val > 0.5 ? 0.12 : 0) + noise(0.01), 0), 1)

        energyBaseline += power * dt
        baseline.append(row(step: (i + 1) * stepsPerRow, dt: dt, train: train, val: val,
                            grad: grad, sparsity: sparsity, energy: energyBaseline, power: power))

        // Record the grok (plateau) step the first time accuracy nears the ceiling.
        if grokStepValue == nil, val >= valCeiling - 0.003 { grokStepValue = (i + 1) * stepsPerRow }

        // The optimized run stops once accuracy has PLATEAUED at its ceiling (so it
        // reaches the same accuracy as the standard run), or at the AI-predicted step.
        let shouldStop: Bool
        if useAIStop, let ai = aiStopStep {
            // Stop exactly at the predicted step (early or late), so the stop lines
            // up with the AI prediction. The 0.5 floor guards a wildly early
            // prediction; the plateau fallback only applies if the prediction lands
            // beyond the run length.
            let predRow = max(1, ai / stepsPerRow)
            shouldStop = (i >= predRow && val >= 0.5)
                || (predRow > maxRows && val >= valCeiling - 0.002)
        } else {
            // Rule-based: stop once accuracy has plateaued at its ceiling.
            shouldStop = val >= valCeiling - 0.002
        }
        if !optStopped {
            if shouldStop {
                optStopped = true
                optimizedStopStep = (i + 1) * stepsPerRow
            } else {
                energyOptimized += power * dt
                optimized.append(row(step: (i + 1) * stepsPerRow, dt: dt, train: train, val: val,
                                     grad: grad, sparsity: sparsity, energy: energyOptimized, power: power))
            }
        }
    }

    private func row(step: Int, dt: Double, train: Double, val: Double, grad: Double,
                     sparsity: Double, energy: Double, power: Double) -> TrainingRow {
        TrainingRow(step: step, elapsedS: Double(step) / Double(stepsPerRow) * dt, trainAcc: train,
                    valAcc: val, gradNorm: grad, activationSparsity: sparsity,
                    energyJ: energy, meanPowerW: power, rawPowerW: power + noise(0.3))
    }

    private func logistic(_ x: Double, mid: Double, k: Double) -> Double {
        1.0 / (1.0 + exp(-k * (x - mid)))
    }
    private func noise(_ a: Double) -> Double { Double.random(in: -a...a) }
}
