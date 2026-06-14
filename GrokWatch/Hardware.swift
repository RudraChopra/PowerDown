import Foundation

// Representative total board power while training. Used to scale the energy
// numbers so a laptop reads in milliwatt-hours and an H100 in real kWh.
enum Hardware: String, CaseIterable, Identifiable {
    case laptop = "Laptop"
    case a4000  = "RTX A4000"
    case h100   = "H100 node"

    var id: String { rawValue }

    var watts: Double {
        switch self {
        case .laptop: return 30
        case .a4000:  return 140
        case .h100:   return 700
        }
    }

    var powerLabel: String { "~\(Int(watts)) W" }
}

// Multiplies the toy run's compute up to a realistically-sized job, since the
// waste *percentage* is what holds; the absolute joules just scale with size.
enum RunScale: String, CaseIterable, Identifiable {
    case toy      = "Toy demo"
    case vision   = "Vision model"
    case fineTune = "LLM fine-tune"
    case pretrain = "LLM pretrain"

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .toy:      return 1
        case .vision:   return 120
        case .fineTune: return 2000
        case .pretrain: return 60000
        }
    }

    var detail: String {
        switch self {
        case .toy:      return "≈ seconds"
        case .vision:   return "≈ hours"
        case .fineTune: return "≈ days"
        case .pretrain: return "≈ weeks"
        }
    }
}

// Everyday equivalents for an energy/CO₂ amount.
enum Impact {
    static func phoneCharges(kWh: Double) -> Double { kWh / 0.012 }   // ~12 Wh per charge
    static func ledBulbHours(kWh: Double) -> Double { kWh * 1000 / 10 }
    static func milesDriven(co2Grams: Double) -> Double { co2Grams / 404 }   // avg US car
    static func treeYears(co2Grams: Double) -> Double { co2Grams / 21000 }
}
