# The Pellagra Mystery

Investigate how corn processing changes usable niacin, NAD⁺/NADH cycling, ATP supply and community health, in one sandbox.

A supplement to New Visions Biology, Unit 5 *Food for All*, Lesson 3 (*Infectious Agent or Insufficient Diet*). It is a
classroom instrument, not a lesson: no levels, scores, quizzes, text entry, accounts or network requests.

- Design document: `Pellagra_Mystery_GDD_v0.1.md`
- Model, assumptions and limits: `SCIENCE_MODEL.md`
- Spanish wording for a colleague to check: `SPANISH_TRANSLATION_REVIEW.md`
- What this project learned about translating SimKit: `SIMKIT_LOCALIZATION_NOTES.md`
- Credits: `CREDITS.md`

## Features

- [x] One shared scientific state (`SimController`): diet, body niacin sufficiency, cell metabolism, community, storage samples
- [x] Cell view: glycolysis, fermentation, shuttle, citric acid cycle stage, electron transport chain, proton gradient, ATP synthase, cell work
- [x] NAD carriers visibly recycled (NAD⁺ ↔ NADH); the number of carriers follows the slow NAD pool
- [x] Particle rates driven by model fluxes; frozen when paused; still frame with counts for reduced motion or `particles=off`
- [x] Diet controls: food source, processing (only the combinations that make sense), niacin slider with an explicit, reversible custom mode, calories, workload
- [x] Processing shown whenever the food changes: caption, selected option, and a kernel animation in the control panel
- [x] Time lapse (off / day / week / month per second) for nutritional and population time; deficiency and recovery are gradual
- [x] Population view: 120 modeled people in households, shape-coded status, line graph, conceptual tissue indicators
- [x] Community presets (tenant farming, institution, diverse, nixtamalized tradition, fortified grain) that set the shared diet
- [x] Food panel: labelled kernel cross-section with degerming, nixtamalizing and fortifying animations; niacin breakdown bars
- [x] Storage and decomposition test on its own clock: two samples, temperature, air moisture, oxygen; matter accounted for; separate rancidity index
- [x] Historical evidence pages (read-only, sourced, one study per page), kept apart from model output
- [x] Graph and comparison: baseline + two kept runs as dashed lines; names generated from settings; CSV download of the run
- [x] Advanced data section with direct cellular interventions (oxygen, NADH hand-off), tagged as not diet
- [x] English and Spanish for every string, switchable at any time without touching the simulation; language never stored
- [x] Keyboard: every control reachable; Tab past the ends and Escape leave the game; Escape closes an open panel first
- [x] Display settings: text size, high contrast, reduced motion (follows the browser preference by default)
- [x] Optional discussion prompts (`prompts=on`), display only
- [x] Class settings from the page address
- [x] Headless regression tests (155 checks) and a real-browser check (29 checks)
- [x] Complete 1916 South Carolina income table (all five brackets and "All incomes", Total columns of the handout's Data Table 1)
- [x] Years for the five Goldberger studies, and every historical figure checked against the Student Materials (2026-11-16)
- [ ] Spanish reviewed by a Spanish-speaking colleague
- [ ] Manual checks listed under "Not yet checked"
- [ ] Phone layout polish (it works and scrolls, but the cell picture is cramped below about 560 px wide)

## Run, test, export (PowerShell 7)

```powershell
$godot = "C:\Users\seanm\Nextcloud2\Gamedev\Godot_v4.7.2-stable_win64_console.exe"
& $godot --path .                          # run on the desktop
& $godot --path . -- "--query=?view=population&food=degermed"   # try class settings on the desktop
pwsh tests/run_all.ps1                     # the three headless test files
& $godot --headless --path . --export-release "Web" "../sfminer.github.io/pellagra-sim/index.html"
pwsh tests/web/run_web_smoke.ps1           # serves the export in an iframe harness and checks it in Chrome
& $godot --path . --script tests/shot.gd -- --out=C:/tmp/shot.png --do=es,degermed,start,wait4   # a picture to look at
```

`tests/web/web_smoke.js` is this project's adaptation of SimKit's `deploy/web_smoke.js`. SimKit's own file is written for
its demo menu (it waits for `simkit: boot ok` and clicks demo buttons), so it cannot check another game unchanged, and the
addon copy is not edited. The adapted file uses SimKit's `deploy/harness.html` as it is.

## Registry facts (for the site agent)

| Fact | Value |
|---|---|
| Title | The Pellagra Mystery |
| Folder | `pellagra-mystery` (export at `GodotGames\sfminer.github.io\pellagra-sim\`, `index.html` at its root) |
| Description | Investigate how corn processing changes usable niacin, NAD cycling, ATP supply and community health. |
| Godot version | 4.7.2.stable.official (ed1daf0bf), GDScript, GL Compatibility, no threads |
| Export template | `Gamedev\godot-2d-web-template-adv\godot-4.7.2.web.template_release.wasm32.nothreads.adv.zip` (release, Export With Debug off) |
| HTML shell | SimKit `addons/simkit/deploy/shell.html` (unedited) |
| Toolkit | SimKit 0.1.0, unedited copy in `addons/simkit/` |
| Export size | about 24 MB uncompressed (the `.wasm` is 23.9 MB; the `.pck` is 0.26 MB) |
| Instructional use | 3 to 10 minutes at a time, at several points across the 7–8 day lesson (see design document section 6) |
| `application/config/name` | Pellagra Mystery |
| Stored in the browser | Display settings only (text size, contrast, motion). Never the language, never any student data. |
| Sent to the page | Only `sims:leave-game`. No scores, results or requests. |
| level, author, license | left blank for the owner |
| Publishing | hidden import only; publish only with the owner's explicit approval |

### Class settings (page address)

Example: `index.html?view=population&food=degermed&detail=basic`. Unknown keys, unknown values and mismatched
food/processing pairs are ignored and the default is used. They are conveniences, not locks.

| Key | Type | Values | Default | Effect |
|---|---|---|---|---|
| `view` | choice | `cell`, `population` | `cell` | Which view opens first. |
| `food` | choice | `whole`, `degermed`, `diverse` | `whole` | Food source selected at the start. |
| `processing` | choice | `untreated`, `nixtamalized`, `degermed`, `fortified` | `untreated` | Used only where it fits the food: `whole` takes `untreated` or `nixtamalized`; `degermed` takes `degermed` (unfortified) or `fortified`. |
| `detail` | choice | `basic`, `advanced` | `basic` | `advanced` opens the Advanced data section and uses fuller pathway names. |
| `particles` | choice | `on`, `off` | `on` | `off` shows the cell as a still frame with counts and rate labels. |
| `motion` | choice | `normal`, `reduced` | `normal` | `reduced` turns on Reduced motion. Without the key, the browser's preference is used. |
| `prompts` | choice | `off`, `on` | `off` | `on` adds the optional discussion prompts section. Nothing is required or blocked. |

### Keyboard

| Key | What it does |
|---|---|
| Tab / Shift+Tab | Next / previous control. Past the last or before the first: leaves the game (`sims:leave-game`). |
| Enter or Space | Presses the focused button. |
| Arrow keys | Move a focused slider; scroll a focused text panel (Help, evidence, storage controls). Page Up/Down, Home, End also scroll. |
| Escape | Closes the open panel (food, evidence, help). With none open: leaves the game. In browser full screen the first Escape only leaves full screen. |
| Space, R, N or Right arrow | Start/pause, reset, step: SimKit's hotkeys, active when no focused control uses the key. |

## What was checked, and how

**Automated, headless (Godot 4.7.2 on the desktop), `pwsh tests/run_all.ps1`: 155 checks, all passing.**

- `tests/test_models.gd` (62): every row of the design document's section 5.6 matrix except "toggle views" (that one is in the
  interface test), bounds and NAD conservation over 3000 random steps at every time lapse, matter balance over 108 storage
  runs, clock independence, reproducibility, presets, custom niacin.
- `tests/test_loc.gd` (31): English/Spanish key parity, matching `{places}`, no untranslated or unused text, every key the code
  and data use exists, every English literal inside SimKit has a translation route, the font has every character.
- `tests/test_ui.gd` (62): nothing runs before Start; language, view, panels, text size and contrast leave the state digest
  unchanged (also mid-run); no English left in Spanish on any view, panel or evidence page; Tab ring, exits, Escape order,
  focus kept through a language switch; controls at least 44 CSS px and out of the top-right 200 × 64 CSS px; class settings
  including bad ones; 1180 × 360 and 420 × 700 frames.

**Automated, real browser (Chrome 157 driven by Playwright, software GL), `pwsh tests/web/run_web_smoke.ps1`: 29 checks, all passing.**
Boot line `pellagra-mystery: boot ok`; no console error, page error or `SCRIPT ERROR`; canvas not blank; pixel-identical for
3 s before input; keyboard to the language button; `<html lang>` and the canvas label become Spanish; SimKit's "Running" and
"Paused" announcements reach the live region as "En marcha" and "En pausa"; Start runs, Pause freezes (pixel-identical for
2.5 s); Escape and Tab-past-the-end each send exactly one `sims:leave-game` and focus lands on the host page; Help opens and
Escape closes it without leaving; class settings and bad class settings; 1180 × 360, 1180 × 500 at DPR 1.5, 590 × 250,
380 × 640 at DPR 2; standalone tab. The iframe is SimKit's `harness.html` stand-in, not the real site.

**Looked at by the developer (screenshots from the desktop build and from the browser run):** cell, population, kernel
and storage in English and Spanish; evidence and help in English only; high-contrast still frame; 1180 × 360; Large text;
a 420 px wide frame. Spanish on the evidence and help pages was checked by the tests, not by eye.

**SimKit's `deploy/export_web.sh` contract check:** `index.html`, `.pck` and `.wasm` at the export root, no threads, live
regions present: all OK. Its own `.pck` leak check did not really run (it needs `strings`, which Git Bash here lacks).

**`.pck` inspected:** holds only `Main.tscn`, `icon.svg`, `scripts/`, `addons/simkit/` scripts, `data/*.json`, `locale/*.json`.
No tests, notes, screenshots, deploy files or user paths.

**Not yet checked (do not treat as passed):**

- Sean's own check in Chrome; a Chromebook; a phone; a physical-keyboard pass by a person.
- A screen reader (NVDA or ChromeVox). Canvas support is limited: the game sends short summaries to SimKit's live regions
  and that is all. Full accessibility is not claimed.
- The real site: `/play/pellagra-mystery`, its Full screen button and its focus hand-back.
- 200% browser zoom, a full one-minute idle watch (only 3 s was automated), touch.
- Performance on school hardware (frame rate, memory, start-up time).

**No-autoplay method:** both clocks start in SimKit's READY state and only Start (or its hotkey) runs them; views animate only
while their clock runs; there is no audio at all.

## Known behaviour

- A hidden or fully covered browser tab stops the simulation until it is shown again (the browser stops animation frames).
- SimKit pauses the clocks when the page loses focus (for example after Escape hands the keyboard back to the site).
- Screen-reader summaries are sent when the clock is paused, when a view or panel opens, and when the diet changes.
- Hover help on controls is a mouse tooltip only (SimKit's parameter panel); the same information is in Help.

## Editing the words (locale maintenance)

All text is in `locale/`, plain JSON, one file per language. No code changes are needed for wording.

- **Change wording:** edit the value in `locale/en.json` or `locale/es.json`. Keep the key, and keep every `{name}` in braces
  exactly as it is (it is replaced by a number or a name). `\n` is a line break.
- **Apply a reviewer's corrections:** copy each correction from `SPANISH_TRANSLATION_REVIEW.md` into the matching key in `es.json`.
- **Add a language:** copy `en.json` to `<code>.json`, translate the values, and add one line to `locale/registry.json`. The
  button cycles through the registry in order, showing the next language's own name. With many languages the button can be
  replaced by a menu without touching `Loc`.
- **Text that lives inside SimKit** (Start, Pause, Reset...) is listed in `locale/simkit_strings.json` with the catalog key that
  translates it. If SimKit is updated and a literal changes, `tests/test_loc.gd` fails and names it.
- **After any edit:** `pwsh tests/run_all.ps1`. It fails on a missing key, a changed `{name}`, an empty value, text left identical
  in both languages, or a character the built-in font cannot draw. Then look at the screen: longer text can wrap or clip.
- The built-in font has Spanish accents, ñ, ¿ ¡, ⁺ and ₂. It has no arrows (→ ↔) and no emoji: do not put them in catalog text.
- The language is never saved. Every visit starts in the registry's `default` language.

## Blockers and open items

- **Historical figures** were checked against the Student Materials handout (text and tables read from the `.docx`,
  2026-11-16). All counts matched. The income page shows the Total columns only; the handout's Males and Females columns
  are left out. The handout's graph (Figure 1) is an image and was not compared.
- **Handout misprints, for the lesson's owner:** Data Table 1 prints the second income bracket as "$8.00-$7.99" (shown in the
  simulation as $6.00 to $7.99) and the male total as "2.701" (the column adds up to 2,071). The table's title says seven
  villages; the paragraph above it says six. The simulation follows the table.
- **Lesson documents must not be committed or shipped.** They sat in `data/` during the check. The export only includes
  `data/*.json`, and the `.pck` was checked to hold no `.docx`.
- **Not a git repository** yet.

## Layout

```
Main.tscn, scripts/main.gd        top-level wiring (built in code)
scripts/model/                    SimController, MetabolismModel, NutritionModel, PopulationModel, DecompositionModel, SimData
scripts/views/                    CellView, PopulationView, KernelView, DecompView, PmDraw
scripts/ui/                       FoodInspector, EvidencePanel, HelpPanel, PmSection, KeyScroll, ParamText
scripts/loc/loc.gd                localization module (project-owned)
data/                             model.json, foods.json, cohorts.json, historical.json
locale/                           registry.json, en.json, es.json, simkit_strings.json
addons/simkit/                    SimKit 0.1.0, unedited
tests/                            headless tests, shot.gd, web/ browser check
```
