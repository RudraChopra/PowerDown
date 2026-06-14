import Foundation

// Predicts the grok step from the first ~3000 steps. Standardized linear model,
// weights trained offline (in Python) and pasted in:
//   .real  – fit on the real experiment logs (R²≈0.58)
//   .sim   – fit on the in-app simulator (R²≈0.78), so the live demo lines up
struct GrokPredictor {
    enum Model { case real, sim }

    static let features = ["mem_step", "grad_mean", "grad_last", "grad_slope", "grad_min",
                           "spars_mean", "spars_last", "spars_max", "val_mean", "val_max", "traingap"]

    private let mean: [Double]
    private let std: [Double]
    private let coef: [Double]
    private let intercept: Double

    init(_ model: Model) {
        switch model {
        case .real:
            mean = [490.1099, 7.5356, 5.6743, -0.0567, 2.3621, 0.0909, 0.1291, 0.13, 0.2899, 0.3483, 0.6535]
            std  = [556.4912, 6.1501, 6.903, 0.2859, 1.7907, 0.0387, 0.0707, 0.0705, 0.157, 0.1865, 0.1154]
            coef = [-0.2406, 0.0334, 0.021, 0.0445, -0.0438, -0.0722, -0.0765, -0.0957, 0.1313, -0.1991, -0.0133]
            intercept = 4.3759
        case .sim:
            mean = [853.0, 8.99698, 8.07874, -0.06387, 7.9194, 0.0219, 0.04273, 0.05296, 0.04353, 0.06389, 0.78939]
            std  = [110.56371, 0.03675, 0.2108, 0.00968, 0.13432, 0.00361, 0.01218, 0.00832, 0.0019, 0.00504, 0.03476]
            coef = [0.00598, 0.00051, -0.00264, 0.00181, 0.00184, -0.04321, -0.00341, -0.00617, 0.00088, 0.00072, 0.00832]
            intercept = 4.65514
        }
    }

    // Order has to match `features` above (and the trained weights).
    static func features(from rows: [TrainingRow], earlyStep: Int = 3000) -> [Double]? {
        let w = rows.filter { $0.step <= earlyStep }
        guard w.count >= 8 else { return nil }
        let gn = w.map(\.gradNorm)
        let sp = w.map(\.activationSparsity)
        let tr = w.map(\.trainAcc)
        let va = w.map(\.valAcc)
        let memStep = Double(rows.first(where: { $0.trainAcc >= 0.95 })?.step ?? earlyStep)
        func mean(_ a: [Double]) -> Double { a.reduce(0, +) / Double(a.count) }
        return [
            memStep,
            mean(gn), gn.last!, (gn.last! - gn.first!) / Double(gn.count), gn.min()!,
            mean(sp), sp.last!, sp.max()!,
            mean(va), va.max()!,
            mean(tr) - mean(va)
        ]
    }

    func predict(from rows: [TrainingRow]) -> Int? {
        guard let f = GrokPredictor.features(from: rows) else { return nil }
        var logY = intercept
        for i in 0..<coef.count {
            let z = (f[i] - mean[i]) / std[i]
            logY += coef[i] * z
        }
        let step = pow(10, logY)
        guard step.isFinite else { return nil }
        return min(max(Int(step), 500), 100000)
    }
}
