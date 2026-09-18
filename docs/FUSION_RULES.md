# Fusion Rules

## Expressions

Only creatures can be forged. Two creatures of the same element can create only a **Confluence**. Two creatures whose elements form a supported hybrid can create both a Confluence and one or more **Imprints**. A card can participate in at most two merges.

A **Confluence** preserves the complete sources:

- mana costs are added;
- ATK and HP are added;
- every source ability is retained;
- unique source subtypes are combined.

An **Imprint** converts one or more matched pairs of source-element mana into hybrid mana. Greater cost compression lowers its fidelity, but Imprint remains a distinct strategic expression rather than a failed Confluence.

## Hybridization fidelity

For each Imprint cost:

    compression ratio = converted elemental pairs / total convertible pairs

The ratio maps independently to stat alpha and ability alpha through data/fusion_rules.json:

| Compression ratio | Stat alpha | Ability alpha |
|---:|---:|---:|
| 0 | 1.00 | 1.00 |
| up to 0.34 | 0.75 | 0.90 |
| up to 0.67 | 0.50 | 0.75 |
| up to 1.00 | 0.25 | 0.50 |

Each compressed stat uses:

    hybrid stat = round(max(source A, source B) + alpha × min(source A, source B))

Rounding behavior is configurable.

## Ability values

data/abilities.json is the authoritative ability catalog. Every ability has its player-facing description, a fixed/linear/lookup value model, a scalability flag, and—when scalable—an integer minimum, maximum, and step. The same file is usable by the runtime and external balance tools. Unsupported fractional effects are never invented.

    B_full = sum(source ability values)
    B_imprint = ability alpha × B_full

Ability fidelity is deliberately more generous than stat fidelity so even highly compressed hybrids retain meaningful gameplay identity. The Imprint budget is a ceiling. A package may leave budget unused, but it can never exceed the ceiling.

When both parents carry abilities, the effective ceiling has a configurable identity floor: it is raised, when necessary, to the combined value of the minimum authored version of every ability from both parents. This guarantees that generation can present each parent's effects alone and together instead of allowing source order or one expensive effect to erase the second parent's identity. The ceiling never exceeds the value of the parents' complete original abilities.

An ability-free **wildtype** converts its otherwise unused effective ability budget into extra ATK and HP. The conversion and minimum bonus are explicit in `data/fusion_rules.json`; the current rule grants each stat `round(unused ability value × 0.5)`, with a minimum of +1 to each stat whenever positive ability value was relinquished. Other packages do not receive this compensation.

## Package generation

For each Imprint cost, generation is deterministic:

1. Read every source ability.
2. Generate only authored legal strength variants, never stronger than the source.
3. Apply the dual-source identity floor when both parents have abilities.
4. Enumerate every legal package under the effective Imprint budget, including each parent alone and cross-parent combinations.
5. Consider explicit transformation recipes from data/fusion_rules.json.
6. Remove exact duplicates.
7. Rank packages that retain abilities from both sources first, then by spent value, effect count, and stable signature.
8. Apply wildtype stat compensation to the empty package.
9. Present every legal strategic package to the player.

The empty package is always a legal wildtype choice. Fixed abilities are indivisible: they are retained at full value or omitted. Scalable abilities may be weakened only to a configured discrete strength.

Recipes are alternative packages with their own output value. For example, Burn plus Freeze may become the strengthened Scald 5 only when Scald's configured value fits the current budget.

## Result persistence

The selected name determines source artwork. An Imprint chooses one complete source subtype set; a Confluence combines unique source subtypes.

Confirmed results permanently store source IDs, merge depth, expression, fidelity, ability ceiling, selected package value, and all resolved card fields. Later balance changes therefore do not silently rewrite cards already created by players.
