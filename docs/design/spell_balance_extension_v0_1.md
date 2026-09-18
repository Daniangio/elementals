# Spell Balance Extension — v0.1

## Purpose

Extend the creature balance framework to spells without pretending that a one-shot control
effect is directly interchangeable with ATK and HP.

The core creature curve remains:

| Mana | Target Value |
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

For a spell there are no persistent stats, so the whole card budget is allocated to its effect.

## Absolute Value

For spells:

`AbsoluteValue = EffectValue`

The effect value is built from the same ability-value library used for creatures.

Examples:

- Freeze 1 turn: ~2.0
- Bounce 1 creature: ~3.0
- Heal 6: ~3.0
- Spawn 1/1 Elf: ~1.5
- Spawn 3 1/1 Elves: ~4.5 before board-space/synergy adjustments
- Permanent +2/+2: ~4.5 as an initial heuristic

These values are starting priors only.

## Dynamic Effects

Some Nature effects scale with board state.

For example:

`Thorn Volley: damage = number of friendly creatures`

should not be assigned one universal value.

Instead define:

`V(damage, board_count)`

and evaluate it at reference states such as:

- 1 creature
- 3 creatures
- 5 creatures
- 8 creatures

The spell should be tested across these states rather than balanced only at its average case.

Likewise:

`Wildheart Strike = 2 × friendly creature count`

has a much higher late-game value than early-game value by design.

## Delayed Effects

Water's Sea Egg spells deliberately violate the immediate-tempo intuition.

A Sea Egg is latent value:

`Spell -> Egg -> future creature`

Its value should be discounted for:

- number of turns until hatch;
- board slot occupied during incubation;
- vulnerability to enemy removal;
- opportunity to accelerate hatch;
- synergy with other Water cards.

For v0.1 use a conservative static value in the CSV and validate the real value using simulation.

## Control Effects

Freeze, Bounce, Spore generation and Shell are utility-heavy effects.

Their balance should therefore be inspected through both:

1. absolute effect value;
2. tempo/utility in representative game states.

A Bounce spell can be weak when targeting a 1-mana creature and extremely strong against a 9-mana bomb.
Therefore a single fixed score is only a design prior.

## Tempo

For direct-damage spells:

`TempoDamage(N) = immediate damage`

because the spell does not remain in play.

For delayed or utility spells, record:

- immediate board swing;
- expected surviving board value;
- future damage enabled;
- utility/control score.

Do not assign speculative future face damage as guaranteed damage.

## Nature Scaling

Nature deliberately has effects whose value rises with friendly creature count.

Examples:

`Thorn Volley = friendly_count damage`

`Wildheart Strike = 2 × friendly_count damage`

`Forest Armada = create 4 Elves + conditional team buff`

These cards should therefore be tested at multiple board widths.

A useful simulation matrix is:

`friendly creatures = 0, 2, 4, 6, 8, 10`

and compare the spell's resulting value against its mana cost.

## Water Late Game

Water should have fewer efficient early direct-damage effects than Fire and should concentrate part of its card budget into:

- delayed creatures;
- Freeze/Bounce;
- defensive cleansing;
- egg acceleration;
- powerful late-game transformations.

Its late-game cards may therefore have lower immediate tempo than Fire while still having high total value.

## Design Rule

A spell may intentionally sit above or below the target value when its role requires it.

Do not balance all spells to the same scalar.

Instead ask:

> Is the card's absolute power appropriate for its cost?

and separately:

> Does its tempo profile create the intended elemental play pattern?

Water should generally trade immediate pressure for control and late-game inevitability.

Nature should generally trade immediate efficiency for board development, protection and compounding swarm value.
