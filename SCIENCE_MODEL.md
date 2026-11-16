# Science model — The Pellagra Mystery

What the simulation computes, what it assumes, and where it stops being true. Every number is in `data/*.json` and can be
changed without touching code. `tests/test_models.gd` checks the behaviour described here.

## Ground rules

- **Units are normalized classroom indices.** Nothing here is a measured human quantity, a dose, a clinical threshold or a
  prediction. "100% usable niacin" means "the illustrative reference intake that keeps this model's NAD pool full".
- **Source facts and model output are kept apart.** The historical evidence pages show figures from the lesson materials,
  read-only (`data/historical.json`). No model output is ever labelled as Goldberger's data, and the model is not fitted to it.
- **The lesson materials carry the narrative.** Where this model refines them, the refinement is listed under
  "Refinements to the lesson's simplifications" below.

## The causal chain

```
food + processing ──> usable niacin ──> body sufficiency S (slow) ──> NAD pool size ──> NAD⁺/NADH cycling
                                                                                          │
calories ──> glucose supply ─────────────────────────────────────────────────────────────> pathway rates ──> ATP made
workload ──> ATP demand ────────────────────────────────────────────────────────────────────────────────────> ATP level, work done
                                                                                                                │
                                                              each modeled person: own S ──> same cell model ──> modeled risk
```

## 1. Food and usable niacin (`data/foods.json`, `NutritionModel`)

```
usable niacin = niacin_content × niacin_bioavailability + tryptophan_contribution + fortification
```

| Profile | Content | Bioavailable fraction | Tryptophan | Fortification | Usable |
|---|---|---|---|---|---|
| Whole corn, untreated | 0.90 | 0.30 | 0.20 | 0 | **0.47** |
| Whole corn, nixtamalized | 0.85 | 0.90 | 0.22 | 0 | **0.99** |
| Degermed cornmeal, unfortified | 0.35 | 0.30 | 0.10 | 0 | **0.21** |
| Degermed cornmeal, fortified | 0.35 | 0.30 | 0.10 | 0.90 | **1.11** |
| Diverse foods | 1.00 | 0.75 | 0.50 | 0 | **1.25** |

What the numbers encode (the mechanisms, not the magnitudes, are the science):

- **Untreated corn:** the niacin is there, but most is bound and poorly absorbed. "Retained" is not "absorbed".
- **Nixtamalization:** alkaline cooking frees bound niacin. Content does not rise (it is set slightly lower, for losses in
  cooking water); the bioavailable fraction rises. It is a different process from degerming.
- **Degerming:** removes the germ and bran, and with them much of the niacin and some of the better-quality protein
  (tryptophan). Calories are unchanged.
- **Fortification:** adds niacin after milling. Calories are unchanged.
- **Tryptophan** is a fixed small number per profile: a simplified estimate. Real conversion varies with diet and status.
- **The niacin slider** overrides the food's value with a custom one (0–200%). The interface labels it as custom and offers an
  undo; choosing a food or processing again returns to the food's value.

## 2. Body niacin sufficiency (`NutritionModel`)

```
S_target = clamp(usable niacin, 0, 1)
S_next   = S + (S_target − S) × (1 − exp(−dt / tau))        tau = 40 days
NAD pool = 0.08 + 0.92 × S
```

- `tau` is a **teaching time scale**, chosen so that decline and recovery take visible weeks to months. It is not clinically
  calibrated. (In the historical prison investigation, signs took months to appear; the model is not fitted to that.)
- The update is the exact solution for a step of any length, so every time lapse gives the same result.
- The person starts at S = 1 (well nourished). Reset returns to that.
- The floor of 0.08 keeps a small pool at S = 0. It is a modelling convenience, not a claim.
- Intake above the reference does not raise S above 1: extra niacin does not make a "super" cell here.

## 3. Cell metabolism (`MetabolismModel`, `data/model.json` → `metabolism`)

State: NAD pool `N` (set by nutrition), `NADH` (so NAD⁺ = N − NADH), pyruvate, proton gradient `G`, ATP level `A`
(the fraction of the adenine pool that is ATP; ADP = 1 − A). `sat(x, K) = x / (x + K)`.

```
glycolysis   Jg = Vg · sat(glucose) · sat(NAD⁺) · sat(ADP)
matrix stage Jm = Vm · sat(pyruvate) · sat(NAD⁺)                    (pyruvate oxidation + citric acid cycle, grouped)
fermentation Jf = Vf · sat(pyruvate) · (NADH/N)² · sat(NADH)        (regenerates NAD⁺ without oxygen)
ETC          Je = Ve · sat(NADH) · sat(O₂) · (1 − G) · (1 − block)
ATP synthase Js = Vs · G · sat(ADP)

d NADH     = Jg + 4·Jm − Je − Jf                 d NAD⁺ = −d NADH   (the pool is conserved)
d pyruvate = Jg − Jm − Jf
d G        = (Je − Js − leak·G) / capacity
ATP made   = 1·Jg + 1·Jm + 2.5·Js               (substrate-level + oxidative)
ATP used   = demand · A·(1 + Kd) / (A + Kd)     (work slows as ATP runs low)
d A        = ATP made − ATP used
```

- Integrated with explicit steps of 0.02 s inside the 0.1 s model step; every state is clamped to its range and no flux can
  take more than is present. The tests run 3000 random steps at every time lapse and check bounds and conservation.
- **Why a small NAD pool limits ATP:** every NAD-dependent step runs at a rate that depends on how many carriers are
  available. With fewer carriers, glycolysis, the matrix stage and electron transport all slow, however much glucose there is.
- **ATP production and ATP demand are separate.** Demand is set by workload (0.55 resting, 0.90 active). "Work done" is the
  share of demanded work actually performed.
- **Respiratory control** is included (rates respond to ADP), so a resting cell runs slower than an active one, and ATP
  synthase cannot make ATP from a static gradient: making ATP drains it.
- Stoichiometry is schematic (per "half glucose": 1 NADH and 1 ATP in glycolysis, 4 NADH-equivalents and 1 ATP in the matrix
  stage, 2.5 ATP per NADH-equivalent oxidized). No claim that one NADH equals one ATP.

Steady states with the shipped numbers (`work` = share of demanded work done):

| NAD pool | Diet that leads there | Resting: ATP level / work | Active: ATP level / work |
|---|---|---|---|
| 1.00 | nixtamalized, fortified, diverse | 0.95 / 0.99 | 0.86 / 0.98 |
| 0.51 | untreated whole corn | 0.89 / 0.98 | 0.38 / 0.83 |
| 0.27 | unfortified degermed cornmeal | 0.38 / 0.82 | 0.12 / 0.52 |

Other checked behaviour: high calories with a 0.27 pool raise resting work only from 0.82 to 0.85; restricted oxygen cuts
oxidative ATP by more than half while glycolysis continues through fermentation; impeding NADH oxidation pushes the pool to
more than 70% NADH and the matrix stage slows.

## 4. Population (`PopulationModel`, `data/cohorts.json`)

- 120 modeled people in households of 5. Each has a requirement factor (mean 1, SD 0.10, clipped to 0.7–1.3) and a share of
  other, varied foods drawn around the preset's mean (mostly shared within a household). Fixed seed: every run is the same.
- Each person follows the same sufficiency rule as section 2, with their own target:
  `usable_i = (1 − share_i) × usable(diet) + share_i × 1.25`, `S_target_i = clamp(usable_i / requirement_i)`.
- Each person's NAD pool is turned into "work done" with a table of steady states of the **same cell model** at the current
  calories, workload and interventions (17 points; a test checks it against the live cell). 120 full cell simulations are not run.
- `exposure` is a 30-day smoothing of the shortfall (1 − work done), so duration matters. Status: **strained** at exposure ≥ 0.05,
  **high modeled risk** at ≥ 0.15. The graph shows the share that is strained or at high risk.
- **These are illustrative indicators with arbitrary thresholds.** They are not cases, prevalence or diagnosis, and they do
  not reproduce any historical count. In particular the "institution" preset puts nearly everyone past the line, which
  overstates what the historical records show; it illustrates "one food supply, no alternatives", nothing more.
- Presets describe **food access**. No modeled person has a race, sex or other category, and none affects susceptibility.
- Tissue indicators (muscle, nerves, intestine, skin) are the cell's work fraction raised to a fixed power (1.0, 1.6, 1.3,
  1.15). They are conceptual and are not a mechanism of pellagra's symptoms.

## 5. Storage and decomposition (`DecompositionModel`, `data/model.json` → `decomposition`)

```
growth factor = f(temperature) × f(water) × f(oxygen) × f(substrate)          each f in 0..1
uptake        = r_max × growth factor × microbes
food −= uptake;  microbes += 0.3·uptake − deaths;  CO₂ += share·0.7·uptake;  other products += the rest;  residue += deaths
water in the sample drifts toward the storage air at a rate set by the food (thin, dry foods exchange fast)
rancidity += rate × fat × f(oxygen) × f(temperature) × (1 − rancidity)        (separate, chemical)
```

- **Matter is conserved** by construction: food + microbes + CO₂ + other products + residue is constant (tested over 108 runs).
- **Environment and composition both matter.** Dry cornmeal in dry air barely changes; the same meal in damp air decomposes;
  cold slows it; sealing slows it. A burger in dry air dries out before microbes get going, and decomposes in damp air.
  There is no rule that processed food cannot rot.
- Not a validated growth law for any organism or food. Sixty "days" are illustrative.

## Refinements to the lesson's simplifications

Reported here because they go slightly beyond the lesson's wording. They change how the model behaves; they do not rewrite
any source finding.

1. **Untreated whole corn is modeled as marginal, not safe** (usable 0.47): its niacin is largely bound, so a diet that
   depends on it drifts toward shortage too, more slowly than on degermed meal. In the model a resting cell copes and an
   active one falls short.
2. **Why degermed meal keeps longer:** mainly because the oily germ, which turns rancid, is removed, and because dry meal
   gives microbes little water. At matched moisture the model lets microbes use whole and degermed meal at similar rates.
   Rancidity is therefore shown as its own index, labelled chemical.
3. **Why the NAD pool shrinks:** NAD is recycled in redox reactions and is not used up per ATP. The pool needs continual
   niacin because cells also break NAD down in other reactions (turnover). The model represents this only as "the pool
   follows sufficiency"; carriers fade from the picture, they are not shown as damaged.
4. **Pellagra is more than an ATP shortage.** NAD has other roles, and the symptoms are not a one-step result of low ATP.
   The tissue indicators are labelled as concepts for that reason.

## Known simplifications

- **One aggregate NAD pool.** Real cytosolic and mitochondrial pools are separate, and NADH does not cross the inner
  membrane; the picture shows a shuttle passing electrons, but the model has a single pool.
- **Calories are independent of niacin** in the controls. In real diets more of the same food brings more niacin, and niacin
  need rises with energy intake.
- **NADP, FAD and other carriers, fat and protein as fuels, and hormonal control** are left out.
- **Fermentation** stands for lactate formation; its products are not tracked in the cell.
- **Time scales are compressed.** The cell runs in seconds while days pass; the cell is treated as settling quickly to each
  day's NAD pool.
- **Oxygen "restricted"** is a single low value (3% of normal), not a physiological scenario.

## Historical evidence (`data/historical.json`)

| Record | Figures shown | Source |
|---|---|---|
| Orphanage M.J., 1914–1915 | 0 of 67 previously affected with symptoms the following spring; 0 new cases among 99 | Student Materials, Research Summaries, Experiment #1 |
| Orphanage B.J., 1914–1915 | 1 of 105 previously affected; 0 new cases among 69 | same |
| Georgia State Sanitarium, 1914–1915 | 0 of 72 on modified diets; comparison groups 9 of 17 and 6 of 15 | Experiment #2 |
| Prison investigation, 1915 | 6 of 11 remaining volunteers developed dermatitis | Experiment #3 |
| Transmission investigations, 1916 | 0 of 16 volunteers | Experiment #4 |
| South Carolina income, 1916 | Per 1,000: 42.7 (56 of 1,312) below $6.00; 26.0 (27 of 1,037) at $6.00–$7.99; 12.8 (10 of 784) at $8.00–$9.99; 4.1 (3 of 736) at $10.00–$13.99; 3.4 (1 of 291) at $14.00 and over; 23.3 (97 of 4,160) for all incomes | Goldberger's Investigation Part 2, Data Table 1, Total columns |

- **Checked against the Student Materials** on 2026-11-16 (text and tables of the `.docx`; its Figure 1 is an image and was
  not compared). Each rate equals cases ÷ persons × 1,000 to one decimal.
- **Years** are the period in which people were observed, as the summaries give it (diets changed in autumn 1914, results
  counted in 1915).
- The handout prints the second bracket as "$8.00-$7.99"; it is shown as $6.00 to $7.99. The Males and Females columns are not shown.
- The sanitarium record keeps the report's racial categories as labels of the source's groups, with a note that they are not
  a difference in how bodies use niacin. The investigations are shown as documents; none can be re-enacted in the simulation.
