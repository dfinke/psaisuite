# PSAISuite Model Comparison Demo Script

Target length: about 3 minutes.

## Recording Prep

Start from the repository root:

```powershell
Import-Module .\PSAISuiteBenchmarks\PSAISuiteBenchmarks.psd1 -Force
Show-ModelComparison -Open
```

Optional clean slate:

```powershell
Remove-Item "$env:LOCALAPPDATA\PSAISuite\model-comparisons.json" -ErrorAction SilentlyContinue
Show-ModelComparison -Open
```

Use this model list in the Models box:

```text
openai:gpt-4o-mini
anthropic:claude-sonnet-4-6
deepseek:deepseek-v4-flash
google:gemini-3.1-flash-lite
```

For a smooth 3-minute recording, run one prompt live, then use Recent Queries to show the other prepared runs. If your providers are fast, you can run more prompts live.

## Prompts To Demo

```text
capital of france iceland sweden in json
fib fn, no recurse in powershell
i had three apples ate 2 and mom bought me 1
compare spring and autum
what day is today
what dr should i see for thje pain in my ear
```

## Read-Aloud Script

### 0:00-0:20 - Intro

"Hi, this is a quick look at the PSAISuite model comparison dashboard. It is a web page powered by my PowerShell module, PSAISuite, so the UI is friendly, but the work underneath is still scriptable PowerShell. The goal is simple: send the same prompt to multiple AI providers, compare the responses side by side, and keep a searchable history of what happened."

Action: show the PowerShell launch command or the already-open dashboard.

### 0:20-0:45 - Page Orientation

"At the top I have the comparison form. This prompt box is where I type the task I want the models to answer. Next to it is the model list. Each line is a provider and model pair, so I can mix OpenAI, Anthropic, DeepSeek, Google, or any provider supported by PSAISuite. There are 15 providers currently supported, and more can be added by writing a simple adapter in PowerShell."

Action: click into the Prompt box, then the Models box. Point out the one-model-per-line format.

### 0:45-1:05 - Navigation And History

"On the left is the navigation panel. This is also where recent queries show up. As I run comparisons, the dashboard stores each run in a JSON file, so I can come back later, search it, and click through previous prompts without needing a database."

Action: hover or click a recent query. Keep the header and nav visible while the results pane scrolls.

### 1:05-1:40 - Run A Live Comparison

"Let's run a simple structured-output prompt first: capital of france iceland sweden in json. I hit Run Comparison, or press Control Enter, and PSAISuite fans that prompt out to every model listed here, in parallel. The results will start coming back as each model finishes, and I can scroll down to see them appear in real time."

Action: paste:

```text
capital of france iceland sweden in json
```

Then click Run Comparison. While it runs, say:

"As the comparison proceeds, the page shows progress model by model. This is useful when one provider is quick and another is still working, because I can see partial results instead of staring at a frozen screen."

### 1:40-2:15 - Results Cards

"Now the center pane has one card per model response. Each card shows the provider, the model name, latency, and the actual response. This makes differences jump out quickly: maybe one model returns clean JSON, another explains too much, and another has a slower latency profile."

Action: scan across the model cards. Point out provider/model, latency, and response body.

"For code prompts, I can ask something like fib fn, no recurse in powershell, and compare whether the models follow the implementation constraint. For reasoning prompts, like the apple question, I can see which models solve the arithmetic cleanly and which add unnecessary wording."

Action: click prepared Recent Queries for the PowerShell Fibonacci prompt and the apples prompt.

### 2:15-2:40 - Ratings

"Below each response is a lightweight human rating panel. I can mark accuracy, relevance, completeness, conciseness, and whether the answer feels unbiased. Those ratings are stored with the run, so this becomes more than a one-off demo. It turns into a small feedback dataset for comparing model behavior over time."

Action: click a thumbs-up for a good category and a thumbs-down for a weak category. Show the percentage badge updating.

### 2:40-3:00 - Outro

"That is the model comparison workflow: a PowerShell-backed web dashboard, a plain JSON store, flexible provider and model selection, side-by-side response cards, query history, and human ratings. It gives me a fast way to test models against real prompts before I wire them into automation, agents, or production scripts."

Action: end on a results view with multiple model cards visible.

## Extra Lines If You Need To Fill Time

"I also like using messy real-world prompts here. The misspellings in `autum` and `thje` are intentional demo material, because production prompts are not always pristine. A good comparison tool should show how models handle imperfect input, not just polished benchmark questions."

"The medical-style ear pain prompt is not about replacing a doctor. It is useful because safety behavior is part of model quality. I want to see whether a model gives practical triage guidance, suggests appropriate care, and avoids overclaiming."

"The current-day prompt is a nice reality check. Some models may answer confidently, some may say they do not know, and some may use available context. That difference matters when an automation depends on time-sensitive facts."
