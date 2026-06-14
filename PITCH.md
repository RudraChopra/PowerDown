# GrokWatch — 5-Minute Pitch + Q&A (Sustainable Track)

## One-liner
AI training quietly wastes up to half its energy running long after the model has already
learned. GrokWatch measures that waste, predicts when to stop, and shows the energy, CO2,
and money saved at scale.

## The 5 minutes (rough timing)

**0:00 - 0:30  Hook (problem + number).**
"When a model learns, it first memorizes, then much later 'groks' the real rule. People keep
training long after that, burning power for nothing. In our experiments, **24% of training
energy on average, and up to 57% on the hardest runs**, was spent after the model had
effectively stopped improving."

**0:30 - 2:45  Live demo (Train & Compare).**
1. Upload `mod97_train.csv` (it auto-finds the test split, shows 50/50).
2. Set Hardware to **H100 node**, Run scale **LLM fine-tune**.
3. Press **Run comparison**. Narrate: "Both runs learn identically. The green optimized run
   stops the moment accuracy plateaus; the gray standard run keeps going. That red region is
   wasted energy."
4. Point at the **generalization grid** flooding green: "this is the model going from
   memorizing the training data to correctly solving data it never saw."
5. Turn on **AI auto-stop**: "from the first 3,000 steps, a model we trained predicts where
   it'll grok, so you can stop without babysitting it."
6. Land on **savings**: "same accuracy, less energy," then flip **At scale** to 100,000 runs
   to show MWh and tons of CO2 and the real-world equivalents.

**2:45 - 3:30  Proof on real data (Explore Runs + Quiz).**
- Explore Runs: "this is our actual experiment data across two different GPUs. The predictor
  runs on the real runs too, R^2 0.58."
- Quiz the Model: ask a held-out row, show it answers correctly once trained.

**3:30 - 4:00  Impact close.**
"Every AI lab trains thousands of models. Stopping at the right moment is free, needs no new
hardware, and at scale it's real megawatt-hours and tons of CO2."

**4:00 - 5:00  Q&A / Code Review** (see below + CODE_WALKTHROUGH.md).

## Own the caveats before a judge finds them
- The app **simulates** the grokking curve so the demo runs in seconds; the science behind it
  is real and measured.
- Hardware/scale numbers are **estimates** using each device's typical power; the demo runs
  locally on the Mac.
- We tested a second hypothesis (a local power dip at grok) and it was **not significant**
  (p = 0.96). We report it as null. (Judges respect this.)

## Rubric talking points
- **Innovation:** framing grokking as a measurable *energy* problem, plus an early-warning
  predictor. Not a new algorithm, a new lens and tool.
- **Technical:** native SwiftUI app, custom Canvas viz, a real trained ML model ported to run
  offline, multi-GB streaming CSV, cross-hardware energy instrumentation.
- **Functionality:** judges can upload, run, toggle, quiz, and explore real data live.
- **Design:** one accent, tabular figures, consistent cards, no clutter.
- **Impact:** AI energy use is a top sustainability issue; the fix is free and scales.
- **Relevance:** directly a sustainability tool: measure and cut wasted training energy.
- **Code quality:** commented, organized, MIT open source (LICENSE), and you can explain it.

## Q&A bank (honest answers)
**Has this been done before?** The pieces exist separately (early stopping, grokking research,
carbon tracking). Framing grokking as energy waste and showing that *naive* early stopping
fails here is the contribution. It's a novel application, not a new algorithm.

**How exactly do you save energy?** You stop training once accuracy has plateaued, instead of
running a fixed long schedule. The saved energy is the wasteful flat "tail" you didn't run.

**Do you skip memorization?** No, you can't. Memorization is the first phase. We stop the
wasteful steps *after* the model has generalized, not the front of training.

**How does the AI work with no API key?** It's not an LLM. It's a small model we trained on
our data; the learned weights are baked into the app, so it runs locally with no API.

**How much did you save?** Across the real experiments, 15,258 J of 62,620 J (24%), up to 57%
on hard runs. Per run it's small because the models are tiny; the percentage is what scales.

**What's the long tail?** The flat top of the accuracy curve where the model is already as
good as it gets but training keeps running. That's the wasted part.
