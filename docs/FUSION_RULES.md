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

## Package generation

For each Imprint cost, generation is deterministic:

1. Read every source ability.
2. Generate only authored legal strength variants, never stronger than the source.
3. Enumerate packages under the Imprint budget.
4. Consider explicit transformation recipes from data/fusion_rules.json.
5. Remove exact duplicates.
6. Rank packages that retain abilities from both sources first, then by spent value, effect count, and stable signature.
7. Present every legal strategic package to the player.

The empty package is legal when no ability can fit. Fixed abilities are indivisible: they are retained at full value or omitted. Scalable abilities may be weakened only to a configured discrete strength.

Recipes are alternative packages with their own output value. For example, Burn plus Freeze may become Scald only when Scald's configured value fits the current budget.

## Result persistence

The selected name determines source artwork. An Imprint chooses one complete source subtype set; a Confluence combines unique source subtypes.

Confirmed results permanently store source IDs, merge depth, expression, fidelity, ability ceiling, selected package value, and all resolved card fields. Later balance changes therefore do not silently rewrite cards already created by players.
