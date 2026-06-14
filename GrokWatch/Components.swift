import SwiftUI

// Spacing/radius tokens so everything lines up on an 8pt rhythm.
enum Theme {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let cardRadius: CGFloat = 8
}

extension Color {
    // One accent for the whole app. Muted emerald, not system-green neon.
    static let brand = Color(red: 0.13, green: 0.6, blue: 0.42)
    static let brandBright = Color(red: 0.28, green: 0.88, blue: 0.58)
}

extension ShapeStyle where Self == Color {
    static var brand: Color { .brand }
    static var brandBright: Color { .brandBright }
}

// Flat bordered panel. No shadow, no fill gradient.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(Theme.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    var accent: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).monospacedDigit()
                .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccuracyGauge: View {
    let value: Double
    let label: String
    var tint: Color = .brand

    private var v: Double { min(max(value, 0), 1) }

    var body: some View {
        VStack(spacing: Theme.s2) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 7)
                Circle().trim(from: 0, to: v)
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.2), value: v)
                Text("\(Int(v * 100))%").font(.title2).monospacedDigit()
            }
            .frame(width: 96, height: 96)
            Text(label).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.body, design: .monospaced))
            if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
    }
}

enum Fmt {
    static func pct(_ x: Double?) -> String {
        guard let x else { return "—" }
        return String(format: "%.0f%%", x)
    }
    static func co2(_ grams: Double) -> String {
        if grams >= 1000 { return String(format: "%.2f kg", grams / 1000) }
        if grams > 0 && grams < 0.1 { return String(format: "%.0f mg", grams * 1000) }
        return String(format: "%.1f g", grams)
    }
    static func usd(_ d: Double) -> String {
        d < 0.01 ? String(format: "$%.4f", d) : String(format: "$%.2f", d)
    }
    static func step(_ s: Int?) -> String { s.map(String.init) ?? "—" }

    static func energyAuto(_ joules: Double) -> String {
        let kwh = Energy.kWh(joules: joules)
        if kwh >= 1000 { return String(format: "%.2f MWh", kwh / 1000) }
        if kwh >= 1 { return String(format: "%.1f kWh", kwh) }
        return String(format: "%.0f Wh", kwh * 1000)
    }

    static func whole(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: x.rounded())) ?? String(Int(x))
    }
}
