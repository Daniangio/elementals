# Technical Documentation

## Data Ownership

Base definitions are immutable JSON content shipped in `data/`. The player profile owns mutable collection counts, decks, and resolved merged-card definitions. Decks contain stable card IDs rather than duplicated card data.

Local persistence uses `user://accounts.json`. It stores the active profile ID and an independent profile dictionary for every local account:

```json
{
  "active_profile_id": "profile_1",
  "profiles": {
    "profile_1": {
      "name": "Adventurer", "level": 1, "xp": 0, "currency": 1000,
      "inventory": {"packs": {"elemental_core": 1}},
      "collection": {"card_id": 10},
      "merged_cards": {"merged_id": {}},
      "active_deck_id": "starter",
      "decks": {"starter": {"id": "starter", "name": "First Fusion", "card_ids": [], "foundation_id": "pillar_fire", "vanguard_id": "ember_pup"}}
    }
  }
}
```

Legacy `user://profile.json` data is imported into the first account. The bootstrap file is used when a profile is created and when required collection fields are migrated. `data/game_config.json` controls starting level, XP, currency, match rewards, packs, individually purchasable cards and their prices, room availability, and room background paths. Add entries under `single_cards` to expand the Bazaar card market. `data/bootstrap_profile.json` controls starter cards and starter decks.

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

Reusable effect meaning and balance metadata live in `abilities.json`; kind, price, target mode, and optional numeric `strength` live on each card reference. Every catalog entry contains its description, value model, scalability flag, and legal strength domain. Permanent and triggered abilities normally have no cost.

`fusion_rules.json` contains separate stat and ability fidelity values for every compression tier, plus stat rounding and explicit ability recipes. `FusionEngine` computes Imprint stats as `max + stat alpha × min` and limits generated ability packages to `ability alpha × full ability value`. Ability alpha is intentionally higher than stat alpha at every compressed tier. The engine enumerates authored discrete variants, fixed effects, omissions, and recipes; removes exact duplicates; then ranks preservation of both source identities before value and diversity. Selected cards persist both fidelity values, the ceiling, chosen value, and all resolved fields so later balancing does not silently change an existing player-authored card. Confluence unions unique subtypes; Imprint offers either source's complete subtype set. Same-element pairs generate only Confluence. The selected merged name chooses the artwork from the source supplying its first name part. Resolved cards store `merge_count`; candidate generation rejects a source at depth two and sets the result to `max(source depths) + 1`. See `docs/FUSION_RULES.md` for the normative rules.

The CSV in `docs/design/` is a design and balance worksheet, not a runtime source. `data/cards.json` is the authoritative implementation format.

## Match State

Each battlefield is a fixed 32-element array mapped row-major to four rows and eight columns. Empty entries are `null`. Playing a persistent card chooses uniformly from the current empty indexes. The match UI intentionally hides this grid and renders only occupied cards.

Pillars are separate match records with a unique runtime ID, an output element, an image, and optionally a Merge action. They have no battlefield-slot index and no count cap. Attuned hybrid definitions add an `attunement` field and a one-mana base-element `cost`; their `element_tags[0]` remains the hybrid mana they produce.

The match state also stores HP, deck, hidden/public hand size, public Foundation and Vanguard IDs, persistent mana, discard, active player, target-selection state, timed player effects such as Cinder Ward, a newly randomized RNG, and an input lock used during animations.

## Interaction Model

All player actions use Godot `Button` and `Control` signals, while Spacebar is routed to the same end-turn function as the battlefield button. Targeted abilities and Pillar fusion use a two-step source-then-target interaction with a visible status prompt. A shared square portrait renderer is used by hands, special zones, battlefields, Pillars, and the deckbuilder; pointer entry creates a margin-aware full-card overlay at the root UI level.

After the second compatible base Pillar is selected, `pillar_attune` targeting opens a modal containing both resolved attuned card definitions. `_complete_pillar_attunement` removes the two source records only after a choice is made; cancellation is therefore lossless. The bot selects an attunement by comparing current mana against the base-element demand in its hand. Decked hybrid Pillars pass through normal affordability and payment checks, unlike zero-cost base Pillars.

Combat is asynchronous. The resolver orders occupied attacking slots, calculates a per-attack delay from a two-second total, triggers the card edge wave, applies damage, shows floating damage text, and then advances to the next slot. Input remains locked until combat and the bot response complete.

Scorch, Fireball, sacrifices, and Berserker Draught use one effect-target state. `_is_effect_targetable` drives both validation and the aim markers rendered on battlefield portraits and HP bars. Direct damage first mutates state, synchronizes HP/stat widgets, and only then starts the flash and floating number. The floating face-damage number receives a small offset from the match RNG. `_finish_match` applies profile rewards once, saves the active account, and schedules a Lobby return; surrender clears the match and returns immediately.

Foundation/Vanguard selection is stateful rather than dropdown-based. `deck_special_target` identifies the armed slot; collection cards validate against the slot rule before replacement. Selector children are removed synchronously before rebuilding, preventing a queued-free old portrait and its replacement from appearing together for one frame.

The Deck route renders the profile's deck library and `DeckEditor` renders the selected entry identified by `editing_deck_id`. Save validation opens a naming modal before replacing that dictionary entry. `active_deck_id` is persisted per profile, migrated to an existing deck when necessary, and resolved by `_new_match`. Invalid drafts cannot be activated. Clone operations deep-copy the deck under a new stable ID; deletion repairs the active ID when needed.

Collection uses a `TabContainer` to keep card and item inventory in independent full-height pages. Forge uses three upper regions (Confluence, centered sources/name, horizontally scrolling Imprint) plus a horizontal collection strip. Forge source selection and `FusionEngine.result_candidates` both reject non-creatures. Fusion ownership is committed before the result overlay begins, so presentation interruption cannot leave consumed sources without the created card.

Pack opening uses the pack size and pool from configuration, updates collection counts atomically in the active profile, saves, and presents the results in an overlay. Bazaar purchases only add unopened inventory.

Pillar production happens only after combat/effect resolution. The presentation layer groups equal records into a single portrait and stores its element and represented count as UI metadata. At the instant the fixed one-second production highlight begins, that count is added to the existing mana dictionary and the mana grid is redrawn. Neither turn transition replaces nor clears that dictionary.

Bot direct-damage targeting assigns a large bonus to lethal unit targets, then ranks them with `_unit_threat`, which weighs current attack, HP, damage/scaling/control abilities, and engine value. Activated Freeze uses the same valuation to select the highest-value opposing battlefield card, pays the ability's own cost, and records its once-per-turn use. Frozen sources are rejected by both player and bot activation paths. Spell-specific helpers choose low-value sacrifice fodder and high-value surviving buff targets. Cinder Ward is stored as a remaining opposing-combat counter on the protected player; its retaliation is applied in the face-attack branch before deaths are resolved and the counter decrements once after that combat phase.

The side rails render all six mana pools as a two-column icon grid. Layered HP progress bars show current HP over the projected post-combat value; the forecast uses current board attack, frozen state, armed Strike state, Burn, and Scald. Activated cards receive a short element-colored overlay animation. Portrait artwork uses a shared canvas shader so the image corners follow the rounded card contour.

`_ability_description` is the single presentation resolver for `abilities.json` text and per-card placeholders such as `strength`, `duration`, and `hp_change`. Full-card spell rows render that description directly. Keyword labels retain `_ability_label` for compactness and use the resolved description as hover-panel content; battlefield activated-ability buttons use the same tooltip source.

## Persistence Rules

The profile is saved after fusion, every deck edit that is explicitly saved, and debug export. Fusion validates ownership before mutating counts. A failed validation does not partially consume cards.

Existing prototype profiles are migrated by adding missing collection counts and default Foundation/Vanguard fields without deleting merged cards or decks.

Room backgrounds are ordinary `TextureRect` layers beneath the application shell. Their resource paths are data-driven and safely fall back to the flat application color if an asset is absent.

## Verification

Automated checks cover:

- Confluence and fidelity-weighted Imprint cost/stat calculations.
- Ability metadata coverage, scaling values, budget ceilings, package preservation, and explicit recipes.
- Unlimited Pillar deck copies and ordinary three-copy limits.
- Collection consumption and merged-card acquisition.
- Delayed end-of-turn Pillar mana and in-match fusion.
- Random placement constrained to 32 slots.
- Numeric Scorch, Burn, and Last Spark strength behavior.
- Paid, random-creature Strike behavior.
- Confluence and Imprint subtype fusion rules.
- Loading Collection, Fusion, Deck, and Match screens.
- Loading Lobby, Profile, Bazaar, and every existing gameplay room.
- Randomized match seeds, one-card starting selectors, HP-bar Scorch feedback, and Lobby return after victory or surrender.
- Desktop and 720 by 1280 mobile rendering.
