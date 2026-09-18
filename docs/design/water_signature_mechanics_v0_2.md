# Water Signature Mechanics v0.2

## Design direction

Water should have a much smaller and clearer mechanical identity than the previous draft.

The core Water concepts are:

1. **Cleanse** persistent negative effects.
2. **Freeze** cards temporarily.
3. **Sea Eggs** create delayed power that can be accelerated by Freeze.
4. **Late-game board investment** through large numbers of Eggs.
5. **Symmetric control** through effects such as Blizzard.

Cards created by spells or abilities are real card definitions with IDs and can exist independently in the card database.

---

## Sea Egg

**Sea Egg**

- Element: Water
- Type: Creature / Egg
- Cost: 1W
- ATK: 0
- HP: 2

### Abilities

**Clock 3**

The Egg has a countdown of 3.

At the appropriate end-of-turn timing, reduce the clock by 1.

When the clock reaches 0, transform the Sea Egg into a **Sea Drake**.

**Frozen Incubation**

When a Freeze effect would be applied to the Egg, do not make the Egg Frozen.

Instead, reduce its Clock by the duration of that Freeze.

Example:

```text
Sea Egg: Clock 3
Freeze 2 applied
        ↓
Clock becomes 1
Egg is not Frozen
```

This creates the central Water interaction:

> **Freeze is simultaneously a control tool and an incubation accelerator.**

---

## Sea Drake

**Sea Drake**

- Element: Water
- Type: Creature / Dragon
- Cost: 5W
- ATK: 5
- HP: 6
- Abilities: none

It is a vanilla creature.

A Sea Drake is the payoff for investing time and board space into Sea Eggs.

---

# Water Spells

## Clear the Tide

**Cost: 1W**

Remove Burn from all friendly creatures and the player.

Restore 6 player HP.

Role:

- anti-Burn technology;
- small amount of direct recovery;
- efficient early defensive spell.

The effect is intentionally narrow. Its strength should come mainly from being an excellent response to Burn rather than being a universally optimal healing spell.

---

## Sea Nursery

**Cost: 2W**

Place **2 Sea Eggs** into empty friendly board slots.

Role:

- early Water engine;
- creates delayed board value;
- starts the Egg strategy without immediately producing power.

Because Sea Eggs are real cards, the spell simply creates instances of the existing `Sea Egg` card definition.

---

## Deep Freeze

**Cost: 3W**

Freeze up to **3 creatures for 2 turns**.

Role:

- core Water control spell;
- can remove attackers from the combat sequence;
- can also interact positively with friendly Sea Eggs by accelerating their clocks instead of freezing them.

This dual use should be an important part of the Water identity.

---

## Mass Incubation

**Cost: 5W**

Place **6 Sea Eggs** into empty friendly board slots.

Role:

- major long-term investment;
- deliberately weak immediate tempo;
- potentially enormous late-game payoff.

The spell is naturally constrained by available board space and the vulnerability of Eggs before hatching.

---

## Blizzard

**Cost: 6W**

Freeze **all creatures for 2 turns**, including your own.

Role:

- symmetric board reset/delay;
- intentionally interacts with Sea Eggs in a special way:
  - normal creatures become Frozen;
  - Sea Eggs instead reduce their clocks by 2.

This means Blizzard can be used defensively or as an Egg acceleration tool.

---

# Why this set is more coherent

The previous Water set had too many independent mechanics.

This version creates a compact triangle:

```text
          FREEZE
         /      \
        /        \
   CONTROL     INCUBATION
       \        /
        \      /
        SEA EGGS
            |
        SEA DRAKE
```

A Water card should ideally reinforce one of these relationships instead of introducing an unrelated mechanic.

---

# Balance notes

## Sea Egg

The Egg itself has almost no immediate combat value:

`0 ATK / 2 HP`

Its value comes from eventual transformation.

Its design value should therefore be modeled as:

`EggValue = survival_probability × DrakeValue - incubation_cost/opportunity`

rather than simply assigning the Egg the full 5W value of a Sea Drake.

The 1W printed cost is deliberately not expected to mean that the Egg is a one-mana 5/6 creature.

## Sea Nursery

The theoretical maximum value is high because two Eggs can eventually become two 5/6 creatures.

The spell must therefore be balanced around:

- three-turn incubation;
- board-slot consumption;
- risk of removal;
- opportunity cost of spending mana on delayed value;
- Freeze interactions.

## Mass Incubation

Six Eggs is intentionally extreme and should be treated as a late-game engine rather than a normal curve card.

It will frequently be limited by the 32-slot board.

## Blizzard

Blizzard should not be valued simply as "Freeze N × number of creatures".

Its symmetric nature is fundamental:

- against an opposing swarm it can buy substantial time;
- against your own board it also prevents attacks;
- with Eggs it becomes an acceleration mechanism.

This makes its correct power highly board-state dependent.
