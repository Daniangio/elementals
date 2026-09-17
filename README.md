# Elemental Fusion

Elemental Fusion is a deterministic two-player digital card game about building a collection, combining owned cards, and turning elemental Pillars into flexible mana engines.

Players construct a 30-card deck from cards they own. Ordinary cards are limited to three copies per deck, while base Pillars have no deck copy limit beyond the copies in the player's collection. During a match there are no action phases: the active player may play any affordable card, activate abilities, or merge compatible Pillars in any order before ending the turn.

Ending the turn starts combat. Creatures attack automatically in board-slot order over a two-second sequence, with visible attack and damage feedback. Pillars then add mana to the player's persistent, accumulating pool. The bot uses the same card data and rules, including threat-scored targets for flexible damage spells.

The prototype includes four working areas:

- Collection separates a full-size card browser from an Items page for packs and future inventory types.
- Fusion consumes two owned source cards and creates one persistent merged card.
- Decks contain 30–120 main-deck cards plus a public Foundation Pillar and Vanguard card.
- Hybrid Pillars have two source-element Attunements: merges choose one in play, while decked copies cost one mana of that attuned element and produce hybrid mana.
- The Forge offers Confluence and Imprint merge expressions with name-linked artwork.
- Multiple offline profiles keep independent progression, collections, decks, currency, and pack inventory.
- The Lobby links Profile, Collection, Deck, Forge, Bazaar, and Match, with future rooms declared in configuration.
- Economy, starter grants, rewards, packs, individual Bazaar card prices, rooms, and fantasy background paths are tunable under `data/`.
- The Deck Library manages named active decks; its editor creates and saves 30–120 card decks while enforcing ownership and copy rules.
- Match runs the board, Pillars, mana, abilities, animated combat, and bot turns.

Run the project by opening `project.godot` in Godot 4.7 or by starting the project from the command line.

## Project Map

- `data/cards.json`: authoritative immutable base cards, including subtypes and per-card ability parameters.
- `data/abilities.json`: reusable ability descriptions, valuation models, and legal scaling ranges.
- `data/fusion_rules.json`: Imprint fidelity tiers, stat rounding, and explicit ability recipes.
- `docs/design/cards_fire_v01.csv`: non-runtime Fire balance worksheet.
- `data/bootstrap_profile.json`: starting collection and deck for a new profile.
- `scripts/card_database.gd`: loads base data and resolves cards.
- `scripts/fusion_engine.gd`: generates legal Confluence and budgeted Imprint results.
- `scripts/profile_store.gd`: persists collection, decks, and merged cards.
- `scripts/main.gd`: screens and match orchestration.
- `tests/`: deterministic rule, gameplay, UI, and capture checks.

Persistent player data is stored under Godot's `user://` directory in `profile.json`.
