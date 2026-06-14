# GrokWatch — Code Walkthrough (for Code Review)

Use this to explain the codebase confidently. Know the **stack**, the **data flow**,
and what each file does. If a judge points at a file, you can say what it does and why.

## Stack (say this out loud)
- **Native macOS app, SwiftUI + Swift Charts.** No web framework, no heavy dependencies.
- **Custom `Canvas` drawing** for the generalization grid (hand-written, not a library).
- **A real ML model** (a standardized linear regression) trained offline in Python
  (scikit-learn) on the experiment data; its learned weights are baked into the Swift app
  so inference runs locally with no API and no internet.
- **Data pipeline:** training runs were instrumented for energy on an Apple M4 Max
  (`powermetrics`) and replicated on a rented NVIDIA RTX A4000 (RunPod, NVML power sensor),
  with idle power subtracted.

## Data flow (one sentence)
Upload a dataset -> the simulator produces a grokking curve scaled by dataset difficulty ->
a standard run trains full-length while an optimized run stops at the accuracy plateau ->
the gap in energy is converted to kWh / CO2 / cost, and a trained model predicts the grok
step from the first 3,000 steps.

## File map (what each does)
| File | Responsibility |
|---|---|
| `GrokWatchApp.swift` | App entry point (`@main`). |
| `ContentView.swift` | Sidebar shell (NavigationSplitView) + Settings. |
| `TrainCompareView.swift` | Main screen: upload, live standard-vs-optimized comparison, energy/CO2/cost, AI auto-stop, recommender, fleet scale. |
| `DualTrainer.swift` | The simulation engine. Generates both runs; decides when the optimized run stops. |
| `GrokPredictor.swift` | The AI model. Extracts 11 features from early steps and predicts the grok step (baked linear weights). |
| `GeneralizationGridView` (in `EmbeddingCircleView.swift`) | Canvas visual: every (a,b) cell turns green as the model solves held-out data. |
| `QuizView.swift` | Quiz the model on held-out rows of the uploaded dataset. |
| `DashboardView.swift` | Explore Runs: load real CSVs, show waste + run the predictor on real data. |
| `Dataset.swift` | Streams huge CSVs with `memchr` (constant memory), detects train/test split, samples rows for the quiz. |
| `CSVParser.swift` | Parses training-log CSVs into rows. |
| `GrokAnalysis.swift` | Detects memorization and grok steps; computes wasted energy. |
| `Energy.swift` / `Hardware.swift` | Joules -> kWh -> CO2 -> dollars; hardware power profiles and real-world equivalents. |
| `Models.swift` | Shared `AppModel` state (runs, dataset, live test accuracy). |
| `Components.swift` | Design tokens (one accent, spacing, type) + reusable Card/MetricTile. |

## Three algorithms you should be able to explain
1. **When the optimized run stops (rule-based).** It watches validation accuracy each step
   and stops once accuracy has plateaued near its ceiling (`DualTrainer.advance`,
   `val >= valCeiling - 0.002`). The subtlety: naive early stopping fails for grokking
   because accuracy stays flat *low* for a long time before it jumps, so the rule waits for
   the *high* plateau, not just any flat region.
2. **The AI predictor.** From the first 3,000 steps it computes 11 features (memorization
   step, gradient-norm stats, activation-sparsity stats, train/val gap), standardizes them,
   and runs a linear model to predict the grok step (`GrokPredictor`). Trained on the real
   runs it scores R^2 = 0.58; the strongest feature is activation sparsity, which rises early
   for runs that grok sooner.
3. **Energy accounting.** Energy is cumulative joules (idle-subtracted). Saved energy =
   standard energy - optimized energy; kWh = J / 3.6M; CO2 = kWh * grid factor.

## If asked "is this AI-generated?"
Be honest: it was built with AI assistance, but you made the design decisions and you
understand it. Point to a real decision, e.g. "we stream multi-GB CSVs with `memchr` instead
of loading them into memory," or "the predictor is a linear model so it ports to Swift and
runs offline," or "the optimized run stops at the *high* plateau because naive early stopping
breaks on grokking." Understanding the *why* is what the rubric rewards.
