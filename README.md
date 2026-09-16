# Elemental Fusion

Elemental Fusion is a deterministic two-player digital card game about building a collection, combining owned cards, and turning elemental Pillars into flexible mana engines.

Players construct a 30-card deck from cards they own. Ordinary cards are limited to three copies per deck, while base Pillars have no deck copy limit beyond the copies in the player's collection. During a match there are no action phases: the active player may play any affordable card, activate abilities, or merge compatible Pillars in any order before ending the turn.

Ending the turn starts combat. Creatures attack automatically in board-slot order over a two-second sequence, with visible attack and damage feedback. Pillars then generate the reserve used on the next turn. A simple bot uses the same card data and rules.

The prototype includes four working areas:

- Collection shows every owned base and merged card with its copy count.
- Fusion consumes two owned source cards and creates one persistent merged card.
- Deckbuilder creates and saves a 30-card deck while enforcing ownership and copy rules.
- Match runs the board, Pillars, mana, abilities, animated combat, and bot turns.

Run the project by opening `project.godot` in Godot 4.7 or by starting the project from the command line.

## Project Map

- `data/cards.json`: authoritative immutable base cards, including subtypes and per-card ability parameters.
- `data/abilities.json`: reusable ability behavior descriptions.
- `docs/design/cards_fire_v01.csv`: non-runtime Fire balance worksheet.
- `data/bootstrap_profile.json`: starting collection and deck for a new profile.
- `scripts/card_database.gd`: loads base data and resolves cards.
- `scripts/fusion_engine.gd`: generates legal Full and Hybrid results.
- `scripts/profile_store.gd`: persists collection, decks, and merged cards.
- `scripts/main.gd`: screens and match orchestration.
- `tests/`: deterministic rule, gameplay, UI, and capture checks.

Persistent player data is stored under Godot's `user://` directory in `profile.json`.
