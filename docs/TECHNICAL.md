# Technical Documentation

## Data Ownership

Base definitions are immutable JSON content shipped in `data/`. The player profile owns mutable collection counts, decks, and resolved merged-card definitions. Decks contain stable card IDs rather than duplicated card data.

`profile.json` contains:

```json
{
  "collection": { "card_id": 10 },
  "merged_cards": { "merged_id": {} },
  "decks": { "deck_id": { "card_ids": [], "foundation_id": "pillar_fire", "vanguard_id": "ember_pup" } }
}
```

The bootstrap file is read only when a profile is first created or when required fields are migrated into an older profile. Debug quantities can be changed without editing gameplay code.

## Card and Ability Schema

Each card definition includes its stable ID, display data, type, subtypes, elements, cost, stats, image path, Pillar flags, deck eligibility, and ability references.

```json
{
  "id": "water_sprite",
  "display_name": "Water Sprite",
  "card_type": "Creature",
  "subtypes": ["Spirit"],
  "element_tags": ["Water"],
  "cost": {"Water": 1},
  "attack": 2,
  "max_hp": 4,
  "image": "res://assets/elemental_mark.svg",
  "abilities": [
    {"id": "Freeze", "kind": "activated", "cost": {"Water": 1}, "target": "enemy_card"}
  ]
}
```

Reusable effect meaning lives in `abilities.json`; kind, price, target mode, and optional numeric `strength` live on each card reference. Permanent/triggered abilities normally have no cost. Fusion preserves resolved references so later base-card balancing does not silently change an existing player-authored card. Confluence unions unique subtypes; Imprint offers either source's complete subtype set. Same-element pairs generate only Confluence. The selected merged name chooses the artwork from the source supplying its first name part. Resolved cards store `merge_count`; candidate generation rejects a source at depth two and sets the result to `max(source depths) + 1`.

The CSV in `docs/design/` is a design and balance worksheet, not a runtime source. `data/cards.json` is the authoritative implementation format.

## Match State

Each battlefield is a fixed 32-element array mapped row-major to four rows and eight columns. Empty entries are `null`. Playing a persistent card chooses uniformly from the current empty indexes. The match UI intentionally hides this grid and renders only occupied cards.

Pillars are separate match records with a unique runtime ID, an element, an image, and a Merge action. They have no battlefield-slot index and no count cap.

The match state also stores HP, deck, hidden/public hand size, public Foundation and Vanguard IDs, mana, reserve, discard, active player, target-selection state, and an input lock used during animations.

## Interaction Model

All player actions use Godot `Button` and `Control` signals, while Spacebar is routed to the same end-turn function as the battlefield button. Targeted abilities and Pillar fusion use a two-step source-then-target interaction with a visible status prompt. A shared square portrait renderer is used by hands, special zones, battlefields, Pillars, and the deckbuilder; pointer entry creates a margin-aware full-card overlay at the root UI level.

Combat is asynchronous. The resolver orders occupied attacking slots, calculates a per-attack delay from a two-second total, triggers the card edge wave, applies damage, shows floating damage text, and then advances to the next slot. Input remains locked until combat and the bot response complete.

Pillar production happens only after combat/effect resolution. The presentation layer groups equal records into a single portrait and stores its element and represented count as UI metadata. At the instant the fixed one-second production highlight begins, that count is added to reserve and the mana grid is redrawn, keeping feedback and state mutation synchronized.

The side rails render all six mana pools as a two-column icon grid. Layered HP progress bars show current HP over the projected post-combat value; the forecast uses current board attack, frozen state, armed Strike state, Burn, and Scald. Activated cards receive a short element-colored overlay animation. Portrait artwork uses a shared canvas shader so the image corners follow the rounded card contour.

## Persistence Rules

The profile is saved after fusion, every deck edit that is explicitly saved, and debug export. Fusion validates ownership before mutating counts. A failed validation does not partially consume cards.

Existing prototype profiles are migrated by adding missing collection counts and default Foundation/Vanguard fields without deleting merged cards or decks.

## Verification

Automated checks cover:

- Confluence and Imprint cost/stat calculations.
- Defined and undefined ability fusion behavior.
- Unlimited Pillar deck copies and ordinary three-copy limits.
- Collection consumption and merged-card acquisition.
- Delayed end-of-turn Pillar mana and in-match fusion.
- Random placement constrained to 32 slots.
- Numeric Scorch, Burn, and Last Spark strength behavior.
- Paid, random-creature Strike behavior.
- Confluence and Imprint subtype fusion rules.
- Loading Collection, Fusion, Deck, and Match screens.
- Desktop and 720 by 1280 mobile rendering.
