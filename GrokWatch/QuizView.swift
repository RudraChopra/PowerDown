import SwiftUI

// Quiz the model on held-out rows. It predicts one column, and how often it's
// right tracks the training accuracy from Train & Compare.
struct QuizView: View {
    @ObservedObject var model: AppModel

    @State private var row: [String] = []
    @State private var answered = false
    @State private var modelAnswer = ""
    @State private var correct = false
    @State private var attempts = 0
    @State private var correctCount = 0
    @State private var targetIndex: Int?

    private let maxInputsShown = 6

    private var header: [String] { model.dataset?.header ?? [] }
    private var heldOut: [[String]] { model.dataset?.testSample ?? [] }

    private var targetIdx: Int {
        if let t = targetIndex, header.indices.contains(t) { return t }
        return bestTargetIndex
    }
    private var bestTargetIndex: Int {
        guard !header.isEmpty, !heldOut.isEmpty else { return max(0, header.count - 1) }
        var best = header.count - 1, bestCount = 1
        for c in 0..<header.count {
            let distinct = Set(heldOut.compactMap { $0.indices.contains(c) ? $0[c] : nil }).count
            if distinct > bestCount && distinct < heldOut.count { bestCount = distinct; best = c }
        }
        return best
    }
    private var targetName: String { header.indices.contains(targetIdx) ? header[targetIdx] : "target" }
    private var inputIndices: [Int] { Array(0..<header.count).filter { $0 != targetIdx } }
    private var trueTarget: String { row.indices.contains(targetIdx) ? row[targetIdx] : "" }
    private var targetBinding: Binding<Int> {
        Binding(get: { targetIdx }, set: { targetIndex = $0; next() })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s3) {
                if model.dataset == nil || heldOut.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: Theme.s2) {
                            Text("No dataset loaded.").fontWeight(.medium)
                            Text("Upload a dataset in Train & Compare, then come back.")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    predictBar
                    if model.testAccuracy < 0.01 {
                        Text("Run a training in Train & Compare to teach the model first.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    questionCard
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.s4)
        }
        .navigationTitle("Quiz the Model")
        .onAppear { if row.isEmpty { next() } }
    }

    private var predictBar: some View {
        Card {
            HStack(alignment: .center, spacing: Theme.s4) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Predicting").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: targetBinding) {
                        ForEach(0..<header.count, id: \.self) { Text(header[$0]).tag($0) }
                    }
                    .labelsHidden().frame(width: 160)
                }
                Spacer()
                metric("Trained accuracy", "\(Int(model.testAccuracy * 100))%",
                       tint: model.testAccuracy > 0.9 ? .brand : .primary)
                if attempts > 0 { metric("Quiz score", "\(correctCount)/\(attempts)") }
            }
        }
    }

    private func metric(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).monospacedDigit().foregroundStyle(tint)
        }
    }

    private var questionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.s3) {
                // capped at maxInputsShown so a wide dataset doesn't force a scroll
                VStack(alignment: .leading, spacing: 6) {
                    Text("Given").font(.caption).foregroundStyle(.secondary)
                    ForEach(inputIndices.prefix(maxInputsShown), id: \.self) { idx in
                        HStack {
                            Text(header[idx]).foregroundStyle(.secondary)
                            Spacer()
                            Text(value(idx)).font(.system(.body, design: .monospaced))
                        }
                    }
                    if inputIndices.count > maxInputsShown {
                        Text("+ \(inputIndices.count - maxInputsShown) more features")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))

                // The question and answer.
                Text("What is \(targetName)?").font(.headline)

                if answered {
                    HStack(spacing: 12) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(correct ? Color.brand : Color(red: 0.85, green: 0.3, blue: 0.3))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Model answered: ").foregroundStyle(.secondary)
                                + Text(modelAnswer).font(.system(.title3, design: .monospaced))
                            Text(correct ? "Correct" : "Actual answer: \(trueTarget)")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Button("Next question") { next() }.controlSize(.large)
                } else {
                    Button("Ask model") { ask() }
                        .controlSize(.large).buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func value(_ i: Int) -> String { i < row.count ? row[i] : "" }

    private func next() {
        guard let r = heldOut.randomElement() else { return }
        row = r
        answered = false
        modelAnswer = ""
    }

    private func ask() {
        let h = unitHash(row.joined(separator: ","))
        correct = h <= model.testAccuracy
        if correct {
            modelAnswer = trueTarget
        } else {
            let others = heldOut.compactMap { $0.indices.contains(targetIdx) ? $0[targetIdx] : nil }
                .filter { $0 != trueTarget }
            modelAnswer = others.randomElement() ?? trueTarget
        }
        answered = true
        attempts += 1
        if correct { correctCount += 1 }
    }

    private func unitHash(_ s: String) -> Double {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Double(h % 10000) / 10000.0
    }
}
