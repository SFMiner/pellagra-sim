# Spanish translation review — The Pellagra Mystery

The Spanish text is a complete first pass: every string in the simulation has a Spanish version (`locale/es.json`, 349 keys).
This page lists only the places where the translator was genuinely unsure. Everything else is believed correct, but a
fluent reader is welcome to change anything.

**For the reviewer**

- Readers are Spanish-speaking high-school students in New York City, from many countries. Plain, clear wording matters more
  than literal accuracy.
- Write your preferred wording in the last column. Leave it empty to accept the proposal.
- Formulas (NAD⁺, NADH, ATP, ADP, CO₂, O₂, H⁺, H₂O) stay as they are.
- If the lesson has Spanish student materials, their vocabulary should win over anything here. They were not available to the translator.
- Corrections go into `locale/es.json` under the same key. No code changes are needed.

## General choices to confirm

| Translation Key | Original English | Proposed Spanish | Reason for Uncertainty | Suggested Alternatives | Your Correction |
|---|---|---|---|---|---|
| (whole interface) | you (addressing the student) | **tú** throughout ("Presiona Iniciar", "Elige…") | Register for students: tú or usted | usted ("Presione", "Elija") | |
| (all numbers) | 42.7, 1,000, 0.85 | Decimal **point** and comma for thousands ("42.7", "1,000") | Regional: Mexico, the Caribbean and Central America use the point; much of South America and Spain use the comma | "42,7" and "1.000" or "1 000" | |
| `prompt.instructions` | Your teacher may ask you… | "Tu maestra o maestro puede pedirte…" | Inclusive form and the usual word for teacher | "Tu docente…", "Tu profesor o profesora…" | |

## Science and food terms

| Translation Key | Original English | Proposed Spanish | Reason for Uncertainty | Suggested Alternatives | Your Correction |
|---|---|---|---|---|---|
| `param.food.degermed`, `profile.degermed_*`, `sample.degermed_meal` | Degermed cornmeal | Harina de maíz desgerminada | "Cornmeal" has no single Spanish word. "Harina de maíz" can also mean fine corn flour or masa flour, which is a different product | Sémola de maíz desgerminada; Maíz molido sin germen; Harina de maíz sin germen | |
| `param.sample_a.whole_meal`, `sample.whole_meal` | Whole-grain cornmeal | Harina de maíz integral | Same question; "integral" for whole-grain | Harina de maíz de grano entero | |
| `param.sample_a.masa_flour`, `sample.masa_flour` | Nixtamalized corn flour (dried) | Harina de maíz nixtamalizado (seca) | Students may know this as a product name | Harina de masa; Masa harina; Harina para tortillas | |
| `param.proc_degermed.fortified`, `profile.degermed_fortified`, `kernel.caption.degermed_fortified` | Fortified | Fortificada | Food labels in Spanish use both words | Enriquecida | |
| `param.proc_whole.untreated`, `profile.whole_untreated` | Untreated | Sin tratar | Meaning here is "not nixtamalized"; could be read as "raw" | Sin procesar; Sin nixtamalizar | |
| `kernel.bran` | Bran (outer layers) | Salvado (capas externas) | For corn the outer layer is also called by other names | Pericarpio; Cáscara; Afrecho | |
| `kernel.limewater`, `param.proc_whole.help` | limewater (alkaline) | agua con cal (alcalina) | Regional names for the cooking liquid | agua de cal; nejayote (the used liquid) | |
| `kernel.row_usable`, `param.niacin.label`, `niacin.*` | Usable niacin | Niacina aprovechable | Chosen as the plain word for "the body can actually use it" | Niacina utilizable; Niacina disponible | |
| `kernel.legend_bound`, `kernel.caption.whole_untreated` | Bound niacin | Niacina ligada | Chemistry term; may be unfamiliar | Niacina unida; Niacina atrapada | |
| `gauge.nad`, `cell.carriers`, `key.nad` | NAD carriers | Transportadores NAD | "Electron carrier" is usually "transportador de electrones"; the short form is the translator's | Portadores NAD; Moléculas de NAD | |
| `status.line`, `graph.title_nad`, `param.metric.nad`, `cell.niacin_role` | NAD pool | Reserva de NAD | "Pool" has no fixed student-level translation | Conjunto de NAD; Cantidad total de NAD | |
| `cell.shuttle` | Shuttle: passes electrons in, not NADH | Lanzadera: pasa electrones, no NADH | "Lanzadera" is the textbook term but uncommon | Transbordador; Sistema de transporte | |
| `cell.synthase`, `advanced.readout` | ATP synthase | ATP sintasa | Both forms appear in Spanish textbooks | ATP sintetasa; Sintasa de ATP | |
| `cell.cycle`, `advanced.readout` | Citric acid cycle | Ciclo del ácido cítrico | Many Spanish courses use the other name | Ciclo de Krebs | |
| `decomp.rancidity`, `kernel.explain.degermed_unfortified`, `decomp.note` | Rancid fat (chemical); turns rancid | Rancidez (química); se pone rancio | Noun form is uncommon in everyday speech | Enranciamiento; Grasa rancia | |
| `decomp.water` | Water for microbes (water activity) | Agua para microbios | Simplified from "actividad de agua" | Agua disponible; Actividad de agua | |

## Interface wording

| Translation Key | Original English | Proposed Spanish | Reason for Uncertainty | Suggested Alternatives | Your Correction |
|---|---|---|---|---|---|
| `param.lapse.label`, `status.lapse_*` | Time lapse | Tiempo acelerado | No fixed term; must be clear that days pass quickly | Cámara rápida; Avance rápido | |
| `snapshot.*` | Baseline; Run A; Keep as baseline | Línea de base; Prueba A; Guardar como línea de base | "Run" of a simulation and "baseline" are lab words | Referencia; Ensayo A; Corrida A | |
| `help.title`, `help.what` | sandbox | espacio de exploración / espacio para explorar | No student-friendly equivalent | simulación libre; sandbox | |
| `pop.strained` | Strained | Con dificultades | Status of a modeled person whose cells are falling a little short of energy | Al límite; Con esfuerzo; Bajo tensión | |
| `pop.risk` | High modeled risk | Riesgo alto según el modelo | Must stay clear that it is model output | Riesgo alto (modelo) | |
| `sk.step` | Step (button: move time forward one step) | Paso | Short button label | Avanzar; Un paso | |
| `sk.run_again`, `sk.resume` | Run again; Resume | Repetir; Reanudar | Button labels | Volver a iniciar; Continuar | |

## Historical context

| Translation Key | Original English | Proposed Spanish | Reason for Uncertainty | Suggested Alternatives | Your Correction |
|---|---|---|---|---|---|
| `param.cohort.tenant`, `cohort.tenant` | Tenant farming; Tenant-farming community | Agricultura de arrendatarios; Comunidad de agricultores arrendatarios | Historical US South term; Spanish has several near words with different meanings | Aparcería; Aparceros; Agricultores que alquilaban la tierra | |
| `hist.sanitarium.row.comparison_a`, `…comparison_b` | (recorded in the report as Black women / white women) | (registrado en el informe como mujeres negras / mujeres blancas) | Historical racial categories quoted from the source; wording must be respectful and clearly the report's own | mujeres afroamericanas; "mujeres de raza negra" (as an older report would say) | |
| `hist.sanitarium.title` | Georgia State Sanitarium | Sanatorio Estatal de Georgia | Name of an institution; it was a psychiatric hospital | Leave in English; Hospital psiquiátrico estatal de Georgia | |
| `hist.orphanage_mj.title`, `hist.orphanage_bj.title` | Orphanage M.J. / B.J. | Orfanato M.J. / B.J. | Word choice | Orfelinato; Hogar de niños | |
| `hist.prison.caption` | a skin condition (dermatitis) consistent with pellagra | una afección de la piel (dermatitis) compatible con la pelagra | Medical phrasing for students | un problema de la piel (dermatitis) propio de la pelagra | |
| `hist.income.caption` | half-month family income per adult male unit (the handout's column heading) | ingreso familiar por quincena por cada unidad de hombre adulto | A 1916 statistical term (income divided by family size counted in "adult male units"); awkward in both languages | ingreso familiar de medio mes por unidad de varón adulto | |
| `hist.income.caption` | seven cotton-mill villages | siete pueblos de fábricas de algodón | Word for a textile mill and its village | aldeas de fábricas textiles; pueblos algodoneros | |
| `hist.transmission.title` | Transmission investigations | Investigaciones sobre el contagio | "Transmisión" is closer; "contagio" is plainer | Investigaciones sobre la transmisión | |
