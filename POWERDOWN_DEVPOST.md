# PowerDown

## Elevator pitch
AI training quietly wastes up to half its energy running long after the model has already
learned. PowerDown measures that waste, uses a small ML model to predict the exact moment training
can stop, and turns it into real kWh, CO₂, and dollars saved at scale.

## Frameworks & tech
**macOS app (native):**
- SwiftUI — entire UI
- Swift Charts — the live accuracy and energy charts
- AppKit — native file/folder pickers (NSOpenPanel / NSSavePanel)
- Foundation — streaming multi-GB CSV parsing with `FileHandle` + `memchr` (constant memory)
- Combine / ObservableObject — app state
- XcodeGen — project generation

**Machine learning (offline):**
- Python, scikit-learn — Ridge linear regression that predicts the grok step from early features
- NumPy — feature engineering / evaluation

**Research & data pipeline:**
- PyTorch — trained the grokking models (small transformers + MLP) on modular arithmetic
- macOS `powermetrics` — energy instrumentation on an Apple M4 Max
- NVIDIA NVML / `nvidia-smi` — GPU power sampling
- RunPod — rented an NVIDIA RTX A4000 to replicate the experiment on different hardware

## Inspiration
We kept reading about how much energy AI training burns, but the numbers were always vague. Then we
ran into **grokking**: small models first *memorize* their training data, then much later suddenly
*generalize* ("grok"). The catch is people don't know when grokking will happen, so they train for a
long fixed schedule "to be safe" — which means the machine keeps drawing power long after the model
has already learned everything it's going to. That gap looked like measurable, recoverable waste, so
we set out to measure it and stop it.

## What it does
PowerDown is a native macOS app that makes wasted training energy visible and actionable:
- **Train & Compare** — upload a dataset and watch a standard training run and an energy-optimized
  run side by side. The optimized run stops once accuracy plateaus; the gap is wasted energy,
  converted live into Wh, CO₂, and cost, then projected to fleet scale (1k–1M runs/year) with
  real-world equivalents.
- **AI auto-stop** — a model we trained on our real runs predicts the grok step from only the first
  3,000 steps, so you can stop proactively instead of babysitting the curve.
- **Quiz the Model** — ask the model held-out questions from your dataset; it answers wrong before it
  groks and right after, making generalization tangible.
- **Explore Runs** — loads our actual experiment logs (across two different GPUs) and runs the
  predictor on real data.

## How we built it
First the science: we trained dozens of small models on modular arithmetic in PyTorch, across many
seeds and configs, while instrumenting real power draw — `powermetrics` on an M4 Max and NVML on a
RunPod-rented RTX A4000, with idle power subtracted so we only counted training energy. We measured
that **24% of training energy on average (up to 57% on the hard runs)** is spent after the model has
effectively stopped improving, and it held up across both pieces of hardware.

Then the ML: we fit a linear model that predicts the grok step from early-training features
(gradient norm, activation sparsity, train/val gap). It hits R²≈0.58 on real runs, and activation
sparsity turned out to be the strongest early signal.

Then the app: a native SwiftUI + Swift Charts macOS app that runs a fast, faithful simulation of the
grokking dynamics so the comparison plays out in seconds, with the predictor's weights baked directly
into Swift so it runs locally with no API.

## Challenges we ran into
- **Honest energy measurement.** A GPU draws power just sitting idle, so we had to measure and
  subtract an idle baseline to get the energy training actually added.
- **Naive early stopping doesn't work here.** In grokking, validation accuracy sits flat and low for
  a long time before it jumps, so the textbook "stop when it stops improving" rule quits too early.
  We had to stop on the *high* plateau, not just any flat region.
- **Deploying ML with no API.** A scikit-learn model doesn't drop into a Swift app, so we retrained a
  standardized linear version and pasted its weights into native code.
- **Generalization of the predictor.** It's accurate on runs like the ones it saw, but unreliable on
  brand-new task types — an honest limitation we surface rather than hide.
- **Cross-hardware replication.** Getting comparable energy numbers off two totally different GPUs
  meant matching the instrumentation and accounting carefully.

## Accomplishments that we're proud of
- A result that **replicated across an M4 Max and an RTX A4000** — same effect, different hardware.
- We tested a second hypothesis (a local power dip at the grok moment) and it came back **not
  significant (p = 0.96)** — and we report it as null instead of overclaiming.
- A **real trained ML model running natively and offline** inside the app, no API key needed.
- A polished native macOS app that a non-expert can actually use and understand.

## What we learned
- The mechanics of grokking, and that **activation sparsity rises early** as a model starts to
  generalize — an actual early warning sign.
- How to measure training energy honestly (idle subtraction, integrating power over time).
- That the obvious early-stopping rule fails in this regime, and why.
- How to take a Python ML model and ship it inside a native app with no backend.
- A lot of SwiftUI, Swift Charts, and how to keep a data app feeling intentional, not generated.

## What's next for PowerDown
- **Hook into real training loops** — a PyTorch callback that watches the live signals and stops the
  job automatically, instead of simulating it.
- **Predict before it happens, at scale** — more data and configs so the predictor generalizes
  across architectures and tasks, turning "detect and stop" into "forecast and schedule."
- **Real-time monitoring** — attach to a live run and show energy, CO₂, and the predicted stop point
  as it trains.
- **Beyond modular arithmetic** — test whether the same waste-and-stop story holds on larger,
  real-world training jobs.
