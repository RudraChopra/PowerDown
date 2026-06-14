import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var section: AppSection? = .train

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $section) { s in
                Label(s.title, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .navigationTitle("GrokWatch")
        } detail: {
            switch section ?? .train {
            case .train:    TrainCompareView(model: model)
            case .quiz:     QuizView(model: model)
            case .explore:  DashboardView(model: model)
            case .settings: SettingsView(model: model)
            }
        }
        .frame(minWidth: 1060, minHeight: 720)
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case train, quiz, explore, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .train: "Train & Compare"
        case .quiz: "Quiz the Model"
        case .explore: "Explore Runs"
        case .settings: "Settings"
        }
    }
    var icon: String {
        switch self {
        case .train: "bolt"
        case .quiz: "bubble.left.and.text.bubble.right"
        case .explore: "chart.xyaxis.line"
        case .settings: "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Sustainability factors") {
                LabeledContent("Grid carbon intensity") {
                    HStack {
                        TextField("", value: $model.factors.gridCarbonGramsPerKWh, format: .number)
                            .frame(width: 90).multilineTextAlignment(.trailing)
                        Text("g CO₂ / kWh").foregroundStyle(.secondary)
                    }
                }
                Slider(value: $model.factors.gridCarbonGramsPerKWh, in: 0...900, step: 1)
                Text("≈50 nuclear-heavy (France) · ≈369 US average · ≈700+ coal-heavy")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Electricity price") {
                    HStack {
                        TextField("", value: $model.factors.pricePerKWh, format: .number)
                            .frame(width: 90).multilineTextAlignment(.trailing)
                        Text("$ / kWh").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Explore Runs data") {
                LabeledContent("Folder", value: model.folderURL?.path ?? "none")
                Button("Choose results folder…") { model.pickFolder() }
                Text("\(model.runs.count) runs loaded").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
