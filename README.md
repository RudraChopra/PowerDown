# GrokWatch

A native macOS app (SwiftUI + Swift Charts) for the **Milpitas Hacks 3 Sustainable track**.

When a model groks, it first memorizes, then much later generalizes. Most training runs keep
going long after the model has generalized, burning power for no gain. GrokWatch shows that waste:
you upload a dataset, run a **standard training** and an **energy-optimized training** side by side,
and watch how much power, CO₂, and money the optimized run saves by stopping once the model groks.

## What it does
- **Train & Compare** — upload a CSV dataset (drag-and-drop or picker), press **Run comparison**,
  and watch two validation-accuracy curves fill in live. The standard run trains the full schedule;
  the optimized run auto-stops just after grokking. Below, an energy bar chart and a savings panel
  show **% energy saved, Wh saved, CO₂ avoided, and cost saved**, with a projection over 100 / 1,000
  / 10,000 runs.
- **Explore Runs** — point it at a folder of training-log CSVs (defaults to your results folder) to
  inspect real runs: accuracy curves with the wasted-compute band shaded, plus per-run energy stats.
- **Settings** — set your grid carbon intensity (g CO₂/kWh) and electricity price so the numbers
  reflect your region.

## Open it in Xcode

**Option A — XcodeGen (recommended):**
```bash
brew install xcodegen
cd ~/Downloads/results/GrokWatch
xcodegen generate
open GrokWatch.xcodeproj
```
Press ▶ in Xcode.

**Option B — Manual (no extra tools):**
1. Xcode → File ▸ New ▸ Project ▸ macOS ▸ App. Name it **GrokWatch**, Interface **SwiftUI**.
2. Set Minimum Deployments to **macOS 14.0**.
3. Delete the auto-generated `ContentView.swift` and `GrokWatchApp.swift`.
4. Drag in every **.swift** file from `GrokWatch/GrokWatch/` (not `Info.plist`).
5. Target ▸ Signing & Capabilities ▸ remove **App Sandbox** (or keep it; the file pickers still work).
6. Press ▶.

## Sample data (already in your results folder)
- `samples/datasets/modNN_train.csv` + `modNN_test.csv` for NN = 23, 53, 97 — proper 50/50
  train/test splits of the modular-addition task. **Upload the `_train.csv` file** in Train &
  Compare; the app auto-finds the matching `_test.csv` and shows the split ratio. Bigger modulus
  (97) → harder → groks later → more energy saved.
- `samples/sample_live_run.csv`, `sample_fast_grok.csv` — full training logs for **Explore Runs**.

## Demo script (~3 min)
1. Open **Train & Compare**, drag in `mod97_train.csv` (difficulty ~95%, 50/50 split shown).
2. Press **Run comparison** at Normal speed. Narrate: "Both runs learn identically — but the green
   optimized run stops the moment it groks, while the standard run keeps burning power."
3. Land on the savings panel: "~40–55% less energy for the exact same model."
4. Switch projection to **10,000 runs** to show fleet-scale kWh / CO₂ / dollars.
5. Open **Settings**, slide carbon intensity from France (50) to coal (700): "Same waste, very
   different climate cost."

**Q&A note:** the science behind this is real — in the underlying experiments, 40–57% of training
energy was spent before models generalized, and the effect replicated across an M4 Max and an
RTX A4000. You also tested whether power drops locally at the grok step and it was indistinguishable
from noise (p = 0.96), so you only claim the global waste effect. Judges respect that honesty.

## How the numbers are computed
- Energy is cumulative joules (idle-subtracted), the same format the real logs use.
- Saved energy = standard run energy − optimized run energy. kWh = J ÷ 3.6M; CO₂ = kWh × grid factor;
  cost = kWh × price.
- The in-app trainer is a fast, faithful **simulation** of grokking dynamics so the demo runs in
  seconds; dataset size scales the grok timing.

## Files
```
GrokWatch/
├── project.yml              # XcodeGen config
├── README.md
└── GrokWatch/
    ├── GrokWatchApp.swift    # @main
    ├── ContentView.swift     # sidebar shell + Settings
    ├── TrainCompareView.swift# main feature: upload, live compare, savings
    ├── DualTrainer.swift     # baseline vs optimized simulation engine
    ├── Dataset.swift         # dataset upload + difficulty
    ├── DashboardView.swift   # Explore Runs (real CSVs)
    ├── Components.swift       # Card, MetricTile, formatters
    ├── Models.swift          # AppModel, data types
    ├── CSVParser.swift        # CSV loading
    ├── GrokAnalysis.swift     # mem/grok detection + waste math
    ├── Energy.swift           # J → kWh → CO₂ → $
    └── Info.plist
```
