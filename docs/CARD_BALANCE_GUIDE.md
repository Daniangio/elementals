# Elemental Fusion TCG — Card Balance Rules v0.1

## Purpose

This document defines the initial quantitative framework for designing and balancing cards in the Elemental Fusion TCG prototype. It is intentionally simple enough to be used by humans or an LLM when generating cards, while exposing the quantities that should later be calibrated from playtest data.

The prototype is unusually suitable for quantitative balancing because combat is deterministic: creatures normally attack automatically at the end of the turn, usually directly at the opponent, and the game has no random mana draw system. This makes it useful to separate **absolute card value** from **tempo value**.

The numbers below are design heuristics, not established laws. Traditional TCG design uses similar stat-budget heuristics, but even Magic's official design discussion explicitly notes that there is no universal conversion between mana, tempo, and card advantage. The Magic "vanilla test" likewise describes creature-stat heuristics as contextual and less linear at higher costs. citeturn279261search0turn279261search1

---

# 1. Core philosophy

A card should be evaluated along at least three separate axes:

1. **Absolute value** — how much persistent or immediate game value is printed on the card.
2. **Tempo value** — how much useful impact the card can generate quickly after being played.
3. **Utility** — how many situations the card can meaningfully interact with outside pure face damage.

Do **not** collapse these into one universal score. A card can have lower absolute value but very high tempo, or high absolute value but poor tempo.

For example:

- A large vanilla creature can have excellent absolute value but poor early tempo.
- A small creature with an immediate damage effect can have lower stats but excellent tempo.
- A creature with a targeted attack ability can have lower direct face damage but higher utility.

---

# 2. Baseline absolute-value curve

For the first card set, use the following target total value.

| Mana cost | Target total value |
|---:|---:|
| 0 | 1.5 |
| 1 | 3.0 |
| 2 | 5.5 |
| 3 | 8.0 |
| 4 | 10.0 |
| 5 | 12.0 |
| 6 | 14.0 |
| 7 | 16.0 |
| 8 | 18.0 |
| 9 | 20.0 |
| 10 | 22.0 |

For costs 5 and above, the starting approximation is:

`TargetValue(cost) = 2 * cost + 2`

For costs 1–4 use the explicit table above.

These numbers are deliberately close to the user's proposed curve. They should be treated as a **design target**, not an automatic requirement. A card can intentionally deviate from the target when its role justifies it.

Recommended initial tolerance:

- **Vanilla / very simple card:** ±0.25 value points.
- **Normal ability card:** ±0.50 value points.
- **Complex, narrow, or intentionally swingy card:** ±1.00 value point, with explicit justification.

Cards substantially above target should be treated as suspect until playtesting demonstrates a reason for the premium.

---

# 3. Base stat valuation

For creatures:

`StatValue = ATK + 0.5 * HP`

Therefore:

| Stat line | Stat value |
|---|---:|
| 1/1 | 1.5 |
| 2/2 | 3.0 |
| 3/2 | 4.0 |
| 4/3 | 5.5 |
| 5/3 | 6.5 |
| 6/4 | 8.0 |
| 7/3 | 8.5 |
| 8/5 | 10.5 |
| 10/5 | 12.5 |
| 18/8 | 22.0 |

This intentionally values attack twice as highly as health in the basic budget. That reflects this game's rules: creatures automatically attack the opponent, so attack is immediately convertible into pressure, while HP primarily determines how long that pressure survives against interaction.

This weighting is only a starting model. If testing shows that HP is more valuable than expected because creatures frequently survive multiple turns or because targeted attacks create strong board control, the coefficient can be recalibrated.

---

# 4. Ability valuation

Abilities should consume part of the card's value budget. The remaining value is allocated to ATK and HP.

The first prototype should use a deliberately tiny ability vocabulary and assign every ability a **base ability-value estimate**.

These values are not permanent. They are starting priors for balancing and should be updated after simulations and playtesting.

## 4.1 Scorch X

**Rule:** When played, deal `X` damage directly to the opponent.

Initial value estimate:

`AbilityValue(Scorch X) = 0.75 + 0.75 * (X - 1)`

Therefore:

| Ability | Initial value |
|---|---:|
| Scorch 1 | 0.75 |
| Scorch 2 | 1.50 |
| Scorch 3 | 2.25 |

The value is deliberately sublinear only weakly at low magnitude because direct damage is especially valuable when available immediately.

## 4.2 Fury X

**Rule:** Whenever this creature attacks the opponent, it permanently gains `+X ATK` after that attack.

Initial value estimate:

`AbilityValue(Fury X) = 1.50 + 0.50 * (X - 1)`

Therefore:

| Ability | Initial value |
|---|---:|
| Fury 1 | 1.50 |
| Fury 2 | 2.00 |

Fury is intentionally expensive because it creates compounding tempo. A card that survives for many turns becomes progressively stronger.

## 4.3 Burn X

**Rule:** Whenever this creature attacks the opponent, it deals `X` additional direct damage.

Initial value estimate:

`AbilityValue(Burn X) = 1.25 + 0.75 * (X - 1)`

Therefore:

| Ability | Initial value |
|---|---:|
| Burn 1 | 1.25 |
| Burn 2 | 2.00 |

Burn is highly tempo-sensitive. Its absolute-value number should therefore be considered a conservative printed-value estimate, while its tempo profile must always be inspected separately.

## 4.4 Strike

**Rule:** Pay `1F`: during this turn's combat this creature attacks a random opposing creature if one is present, instead of the opponent. If no opposing creature is present when it attacks, it attacks the opponent normally.

Initial ability value:

`Strike = 1.00`

Strike is primarily a utility ability rather than a raw-stat or face-damage ability. Its exact value depends strongly on the opposing board.

## 4.5 Last Spark X

**Rule:** When this creature is destroyed, deal `X` damage directly to the opponent.

Initial value estimate:

`AbilityValue(Last Spark X) = 0.50 * X`

For example:

`Last Spark 3 = 1.50`

This is intentionally valued below an equivalent immediate damage effect because the trigger is conditional on the creature dying.

---

# 5. Absolute-value equation

For a creature with ATK `A`, HP `H`, and abilities with total estimated value `V_ability`:

`AbsoluteValue = A + 0.5 * H + V_ability`

Compare this against the target value for the card's mana cost.

Define:

`ValueError = AbsoluteValue - TargetValue(cost)`

and:

`ValueRatio = AbsoluteValue / TargetValue(cost)`

Suggested interpretation:

- `ValueRatio < 0.90`: probably underpowered.
- `0.90–1.05`: normal design range.
- `1.05–1.15`: potentially strong; inspect tempo and synergies.
- `>1.15`: strong warning; usually requires a very narrow condition or explicit drawback.

These are starting review thresholds, not automated balance verdicts.

---

# 6. Tempo model

The game's deterministic automatic combat allows a useful closed-form approximation for an unopposed creature.

Let `A_t` be its attack value during attack `t` after all temporary and permanent modifications.

The face-damage tempo over `N` attacks is:

`TempoDamage(N) = sum(A_t) + immediate_direct_damage`

This is an **unopposed ceiling**, not a prediction of actual game damage. It assumes:

- the creature survives;
- the opponent does not prevent attacks;
- no opposing card changes its stats;
- the player does not choose a targeted attack instead;
- relevant triggered abilities continue to function.

This makes the measure useful for comparing cards but intentionally ignores interaction.

## 6.1 Vanilla creature

For a vanilla creature:

`TempoDamage(N) = ATK * N`

Example: a 4 ATK vanilla creature produces:

- 1 attack: 4 damage
- 3 attacks: 12 damage
- 5 attacks: 20 damage

## 6.2 Scorch X

`TempoDamage(N) = ATK * N + X`

The extra damage happens once, when the creature is played.

## 6.3 Fury X

After every successful direct attack, ATK increases by `X`.

Therefore:

`TempoDamage(N) = N * ATK + X * N * (N - 1) / 2`

Example: 3 ATK with Fury 1:

- 1 attack: 3
- 3 attacks: 3 + 4 + 5 = 12
- 5 attacks: 3 + 4 + 5 + 6 + 7 = 25

This is why Fury must receive a comparatively large ability budget despite sometimes looking harmless on the first turn.

## 6.4 Burn X

`TempoDamage(N) = (ATK + X) * N`

Example: 4 ATK with Burn 1:

- 1 attack: 5
- 3 attacks: 15
- 5 attacks: 25

Burn therefore scales linearly with survival time rather than quadratically like Fury.

## 6.5 Last Spark X

Last Spark does not contribute to the unopposed damage ceiling unless the creature is destroyed.

Record its value separately as **death-trigger utility**.

A future simulation should estimate:

`ExpectedLastSparkDamage = X * P(destroyed within horizon)`

rather than pretending it is guaranteed damage.

## 6.6 Strike

Strike creates two branches:

1. **Face branch:** the creature continues to attack directly.
2. **Removal branch:** the creature attacks a random opposing creature when at least one is present.

Therefore Strike should not be assigned a fixed face-damage bonus. Its benefit should be evaluated using a separate board-state utility simulation.

---

# 7. Temporal value must be reported at multiple horizons

For every creature, record at least:

- `Tempo_1`: direct damage possible after 1 attack.
- `Tempo_3`: direct damage possible after 3 attacks.
- `Tempo_5`: direct damage possible after 5 attacks.

For a creature being evaluated as a curve card, these values should be interpreted relative to its intended role.

A low-cost aggressive creature should be judged heavily on `Tempo_1` and `Tempo_3`.

A high-cost bomb should be judged more heavily on its immediate board impact, survivability, and `Tempo_3`/`Tempo_5` rather than only on `Tempo_1`.

---

# 8. Utility score

For the first prototype, use a coarse utility score only as a secondary design signal.

Suggested scale:

| Utility score | Interpretation |
|---:|---|
| 0 | No special utility; vanilla stats only |
| 1 | Minor narrow utility |
| 2 | Useful conditional effect or targeted interaction |
| 3 | Strong repeated utility |
| 4 | Broad, powerful utility |
| 5 | Build-defining / potentially dangerous utility |

A simple starting mapping is:

- Vanilla: 0
- Scorch: 1
- Fury: 2
- Burn: 2
- Strike: 2
- Last Spark: 1

This is intentionally coarse. The `ability_value` field is the quantitative balance variable; `utility_score` is a readability/design-role variable.

---

# 9. Fire-specific design direction

Fire is the first specialized element and should be clearly aggressive.

The initial Fire card pool should therefore tend toward:

- high ATK relative to HP;
- low and medium mana costs;
- direct damage;
- scaling attack pressure;
- a small number of targeted-combat tools;
- very few expensive cards;
- expensive cards should be spectacular rather than numerous.

A rough distribution for an initial 15-card Fire creature subset:

- 0–2 mana: about half the cards;
- 3–4 mana: several cards;
- 5–6 mana: a few cards;
- 7+ mana: only a few bombs.

Avoid giving every Fire creature an ability. Vanilla creatures are valuable as calibration anchors and make the ability budget measurable.

---

# 10. Aggro stat-shape rule

For Fire creatures, prefer allocating value into ATK rather than HP.

For example, when two stat lines have approximately equal value:

`5/3` is generally more Fire-like than `3/7`.

This is not because 3/7 is objectively weaker; it is because Fire's strategic identity should be to convert resources into pressure quickly.

As a starting heuristic:

- 0–2 mana Fire: preferably attack >= health.
- 3–5 mana Fire: strongly attack-biased.
- 6+ mana Fire: still attack-biased, but enough HP should remain for the card to survive a meaningful amount of interaction.

---

# 11. Important warning about 0-cost creatures

A 0-cost creature is uniquely dangerous in this game because creatures attack automatically at the end of the turn and therefore generate immediate board presence without consuming mana.

The first baseline should therefore be extremely conservative:

`0 mana → about 1.5 total value`

A 1/1 vanilla creature is the intended initial reference.

Do not initially create 0-cost cards with recurring abilities, direct damage, card draw, or mana generation.

The first balance question to test is simply whether a 0-cost 1/1 is already too valuable because it produces immediate attacks and occupies a persistent board slot.

---

# 12. Ability stacking and synergies

The value equation assumes that abilities are evaluated in isolation.

This assumption breaks when cards interact.

For example:

- Burn becomes much stronger when a card can attack more frequently.
- Fury becomes stronger when a card has protection or high HP.
- Scorch becomes stronger in an all-in aggro deck because immediate opponent damage compresses the race.
- Strike becomes stronger when opponents tend to play high-value creatures.

Therefore the first implementation should support both:

1. **printed value** from the card model;
2. **empirical value** measured by simulation or bot matches.

If empirical performance consistently disagrees with printed value, adjust the ability budget rather than endlessly changing individual card stats.

---

# 13. Recommended automated balance checks

Every generated creature should automatically compute:

`TargetValue`

`StatValue`

`AbilityValue`

`AbsoluteValue`

`ValueError`

`ValueRatio`

`Tempo_1`

`Tempo_3`

`Tempo_5`

`UtilityScore`

The first automated warning system should flag:

- absolute value > +10% of target;
- absolute value < -10% of target;
- 0-cost cards with non-trivial abilities;
- very high `Tempo_1` relative to other cards of the same cost;
- very high `Tempo_3` or `Tempo_5` relative to cards of the same cost;
- recursive/scaling abilities combined with high base ATK;
- high-HP creatures that also have strong repeated abilities;
- cards whose ability value appears small but whose long-horizon tempo is very large.

---

# 14. Balance should eventually be calibrated empirically

The mathematical model is useful because it gives the card pool a common language, but it should not be mistaken for a proof of balance.

A sensible calibration loop is:

1. Generate cards around the value curve.
2. Run deterministic test matches between simple decks.
3. Measure win rate, average damage by turn, survival time, cards played, and pillar usage.
4. Identify cards that systematically outperform cards of similar cost.
5. Update the ability budget or stat weighting.
6. Regenerate/rebalance the card pool.

In particular, measure the same cards in both:

- isolated benchmark scenarios;
- actual bot matches.

The isolated benchmark tells us *why* a card looks strong. Bot matches tell us whether that strength actually matters in the game.

---

# 15. First Fire creature set

The design worksheet at `docs/design/cards_fire_v01.csv` contains 15 initial Fire creatures following these rules. It is supporting design material only; runtime definitions live in `data/cards.json`.

The worksheet records subtype, ability kind, per-card activation cost, and optional ability strength separately. Runtime ability references mirror this shape: activated abilities carry a cost, while permanent, triggered, and on-play abilities normally have an empty cost. Numeric abilities such as `Scorch 2` carry `strength: 2`; non-numeric abilities such as `Strike` omit strength.

Cards can have multiple subtypes. A **Confluence** merge adds the unique subtypes of both sources. An **Imprint** merge keeps the subtype set of exactly one selected source. These are parallel creative expressions: Imprint's focused identity is not treated as an inferior or incomplete merge.

Same-element cards may use Confluence but do not generate Imprint options. A card's merge depth is capped at two; balance reviews should therefore consider both first-generation and second-generation merged cards, but no deeper recursive combinations.

The set deliberately includes several vanilla creatures so that the curve itself can be inspected independently from the ability system.

The intended shape is strongly aggressive:

- many 0–3 cost creatures;
- high ATK/low-to-moderate HP;
- direct-damage abilities;
- a small amount of targeted combat utility;
- only three high-cost bombs at 7, 9, and 10 mana.

The CSV is a **design seed**, not a final balanced set.

---

# 16. Sources and design context

Magic's "Vanilla Test" is a useful external reference for the general idea that a creature's printed stats can be compared against mana cost, while also emphasizing that the heuristic is more useful in some formats than others and becomes less linear at higher costs. citeturn279261search0

Magic's official discussion of tempo and card advantage emphasizes that tempo is closely related to mana and board development, but that there is no universal fixed exchange rate between tempo and other resources. This is why this document keeps absolute value and tempo as separate measurements. citeturn279261search1turn279261search3

The Hearthstone community has historically used simple vanilla stat heuristics as well, illustrating that stat-to-mana ratios can serve as useful starting anchors, but those heuristics are not universal and change with game context. citeturn279261search2

---

# 17. Future calibration parameters

The following parameters should remain configurable in the balance tool:

- `atk_weight` — initial value 1.0
- `hp_weight` — initial value 0.5
- target value per mana cost
- ability-value constants
- utility-score mapping
- tolerance band
- tempo benchmark horizons (1, 3, 5)
- optional survival probabilities for expected-value simulations

This allows the balance model to evolve without rewriting card definitions.
