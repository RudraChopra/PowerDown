import Foundation

struct EnergyFactors {
    // US grid average-ish. ~50 for France/nuclear, 700+ for coal-heavy grids.
    var gridCarbonGramsPerKWh = 369.0
    var pricePerKWh = 0.18
}

enum Energy {
    static func kWh(joules: Double) -> Double { joules / 3_600_000 }

    static func co2Grams(joules: Double, factors: EnergyFactors) -> Double {
        kWh(joules: joules) * factors.gridCarbonGramsPerKWh
    }

    static func dollars(joules: Double, factors: EnergyFactors) -> Double {
        kWh(joules: joules) * factors.pricePerKWh
    }

    static func joulesString(_ j: Double) -> String {
        j >= 1000 ? String(format: "%.2f kJ", j / 1000) : String(format: "%.1f J", j)
    }
}
