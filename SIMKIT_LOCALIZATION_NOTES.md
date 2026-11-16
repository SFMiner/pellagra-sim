# Translating a SimKit game: what this project did, how well it worked, and what SimKit should change

The Pellagra Mystery is the first SimKit game in two languages. SimKit 0.1.0 has no language support and its copy here
(`addons/simkit/`) was not edited. This page records the work-arounds used, whether each held up, and the changes to
SimKit that would make them unnecessary.

## What was built in the project

| Piece | File | What it does |
|---|---|---|
| Catalogs | `locale/registry.json`, `en.json`, `es.json` | Flat `key → text` per language, `{name}` for values, loaded at boot |
| `Loc` | `scripts/loc/loc.gd` | `Loc.t(key, {values})`, `bind(control, property, key)`, `cycle()`, a `changed` signal. Never saves the language |
| SimKit literal table | `locale/simkit_strings.json` | Each English string hard-coded in SimKit → a catalog key |
| `ParamText` | `scripts/ui/param_text.gd` | Rewrites `SkParam.label / choices / help` from the catalogs; keeps the machine names of choices |
| Page language | in `Loc._push_web()` | Sets `<html lang>`, the canvas `aria-label` and the title through `JavaScriptBridge` |

## Work-arounds and how they held up

| # | SimKit text | Work-around | Result |
|---|---|---|---|
| 1 | Button and label text (`"Start"`, `"Pause"`, `"Resume"`, `"Reset"`, `"Step"`, lesson headings) | Register each literal as a message in a `Translation` added to `TranslationServer` at run time. Godot's controls translate their own text, so SimKit's buttons change language untouched | **Works**, including in the lean 4.7.2 adv web template (checked in Chrome). Fragile: it is keyed on SimKit's exact English wording |
| 2 | Parameter labels, choices, help, units | `SkParam` fields are plain variables: set them, then call `SkParamPanel.bind()` again | **Works**, but every panel is rebuilt on a language switch, which destroys the focused control; the game restores focus by its position in the Tab ring |
| 3 | Announcements (`"Paused"`, `"Running"`, `"Reset"`, `"Started again"`, `"Settings reset"`, `": On"`, `"Chosen: "`) | `SkHost.announce` cannot be intercepted in GDScript, so the game wraps `window.skAnnounce` on the page with a small exact / start / end substitution table | **Works on the web** (Chrome showed "En marcha", "En pausa"). `SkHost.announcements` (what tests read) stays English. It is the least clean piece |
| 4 | Assembled strings (`"Lesson: %s (hide)"`, `"Observe: " + prompt`) | Register the whole assembled English line as a message each time the lesson is shown | **Works**, awkwardly: the game must know exactly how SimKit builds the line. The show/hide toggle works by replacing `"(hide)"` inside the English text |
| 5 | `SkGauge.verdict()`, `SkLineGraph.describe()` | Not used. Gauges have no bands; the game writes its own summaries | **Feature lost**: no "in / below / above the range" line on gauges |
| 6 | `SkA11y` labels and the `TEXT_NAMES` choices | Overwritten through `ParamText` | Works |
| 7 | `shell.html`: `lang="en"`, loading and error text, canvas label | Language set from the game after boot. Loading and error text stay English | Acceptable here only because every visit starts in English |
| 8 | Class settings (`apply_query`) match a choice's **display** name | A second, never-shown `SkParams` with machine words (`food=whole`), mapped by hand to the real parameters | Works; duplicates every class-setting definition |

Other things that got in the way, not about language:

- **Order of announcements.** `SkTransportBar` announces "Paused" *after* the session's `state_changed` signal, so a summary the
  game sends from that signal is replaced at once. The game delays its own by half a second.
- **Translated values in data.** `SkParams.to_labeled_dict()` and `SkLog`'s parameter events store the display name of a
  choice, so an exported log changes with the language it was recorded in.
- **`SkTransportBar` inside another flow container** gets only its narrowest width and stacks its buttons; the game sets its
  minimum width by hand, and again whenever the play button's word changes length.
- **Help text is a mouse tooltip only**, so keyboard and touch users never see a parameter's help.
- **`deploy/web_smoke.js` is written for the demo menu** (boot line, button order, demo names) and launches a downloaded
  Chromium. This project keeps an adapted copy in `tests/web/`.
- **`deploy/export_web.sh` needs `strings`** for its "pck has no tests, docs or home paths" check. Git Bash on the desktop has
  no `strings`, so that line printed OK without having looked. (This project's `.pck` was checked separately, byte by byte.)
  The script should fail, or say "not checked", when the tool is missing.
- SimKit's README says a lean web template was not verified. For what this game uses it now is (4.7.2 adv template,
  29 browser checks passing). Not exercised here: gauge bands, graph bands, lesson predictions, answer buttons and
  vocabulary, JSON export, the speed button.

## Recommended changes to SimKit, most valuable first

1. **One text function for every SimKit string.** Give each a key and an English default, and resolve it through a hook the
   game can set:

   ```gdscript
   class_name SkText
   const DEFAULTS: Dictionary = {"transport.start": "Start", "transport.pause": "Pause", "announce.paused": "Paused",
           "param.on": "On", "lesson.observe": "Observe: {prompt}", "lesson.title_hide": "Lesson: {title} (hide)"}
   ## func(key: String, values: Dictionary) -> String. Unset = English.
   static var resolver: Callable = Callable()
   static func t(key: String, values: Dictionary = {}) -> String
   ```

   Components call `SkText.t("transport.start")` instead of writing `"Start"`. This removes work-arounds 1, 3, 4, 5 and 6 and
   the JavaScript wrapper, and makes `SkHost.announcements` hold what was really said. A game without languages changes nothing.
2. **`refresh_text()` on the components** (`SkTransportBar`, `SkParamPanel`, `SkLessonPanel`, `SkGauge`, `SkLineGraph`): re-read
   labels in place, keeping controls, focus, scroll position and toggle states. `SkParamPanel` would also be able to change one
   row's choices without a full rebuild.
3. **Separate a choice's id from its name.** `SkParam.choice_param(id, label, ids, names)`; `apply_query`, `to_dict`,
   `to_labeled_dict`, `SkLog` and `class_settings_markdown()` use the ids, the panel shows the names. Class settings then need
   no second parameter set, and exported data stops depending on the language.
4. **Announcement ownership on the transport bar.** Either announce before changing state, or add `announce_states: bool` so a
   game can say its own, fuller message.
5. **Page language through `SkHost`.** `SkHost.set_page_language(code, title, canvas_label)`, and in `shell.html` a small table
   of loading/error strings chosen by a `data-lang` attribute or the address, for games that may start in another language.
6. **Lesson panel:** keep the show/hide state in a variable, not in the button's text.
7. **`web_smoke.js`:** read the boot line and the opening steps from environment variables or a small JSON file, default to
   `channel: 'chrome'`, and ignore the harness page's own favicon request, so one script can check any SimKit game.
8. **Transport bar width:** expose the row's natural width, or reserve room for the longest play-button word.
9. **Help text:** show a parameter's help under its label (optionally), not only as a tooltip.
10. **Docs:** an "Adding a second language" section in `integration-guide.md`; update the README's "Not verified: a lean web template" line.

## If SimKit stays as it is

The approach here can be copied into another game as it stands: `scripts/loc/loc.gd`, `scripts/ui/param_text.gd`,
`locale/simkit_strings.json` and the checks in `tests/test_loc.gd` (which fail, naming the string, if a SimKit update
changes or adds English text).
