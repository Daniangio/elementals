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

Legacy `user://profile.json` data is imported into the first account only when `accounts.json` does not yet exist. Missing card IDs are never backfilled into an existing collection. `data/bootstrap_profile.json` is an empty profile schema. `data/starter_decks.json` defines the one-time choices and exact collection grant; `data/bot_decks.json` defines opponent lists; and `data/challenges.json` maps Combat Hall challenges to costs, rewards, XP, and random deck pools. `data/game_config.json` controls starting stats, the six-copy limit, packs, individually purchasable cards and their prices, room availability, paths, and backgrounds.

`game_config.json` also contains `debug.enabled` and `debug.owned_card_bonus`. `ProfileStore.owned()` applies that bonus only to collectible base definitions and profile-owned merged definitions. Virtual copies are consumed in a runtime-only counter when used by Forge, so debug sessions preserve correct transaction behavior without saving inflated counts or driving stored ownership negative.

## LAN Multiplayer

`LanMultiplayer` creates a one-client `ENetMultiplayerPeer` server on the configured game port (8910 by default). While a room is open, a `PacketPeerUDP` periodically broadcasts a signed JSON advertisement on the discovery port (8911); idle clients bind that discovery port, keep a short-lived room list, and obtain the sender address from the received datagram. The Combat room also exposes direct IPv4 joining as a fallback for routers, access points, or firewalls that suppress broadcast packets. ENet uses UDP, so the host may need to allow the configured ports through the operating-system firewall.

Both peers exchange their active deck definition, including only the merged-card definitions referenced by that deck. The host chooses the shuffle seed and starts the match. Host and guest construct mirrored state so `player` is always the local bottom side and `bot` is always the remote top side. Only the active peer accepts gameplay input. Card plays, resolved targets, and activated abilities send reliable mid-turn snapshots so the waiting peer updates immediately; card-play and ability events drive remote presentation. Combat sends ordered attack events for the opponent-side attack and damage animations. At End Turn the active peer sends the authoritative resolved snapshot and passes control; the receiver swaps the two sides before enabling input. Surrender and lethal-result messages place both peers in a terminal state, disable match actions, and open a blocking result modal with the outcome and reason. Each player returns to Combat and tears down their connection only after pressing the modal's confirmation button.

This is deliberately a trusted-LAN protocol for the current offline prototype, not an authoritative competitive service: the active peer resolves its own turn and supplies the resulting state. Internet matchmaking, identity authentication, replay verification, and anti-cheat validation remain outside its scope.

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

`fusion_rules.json` contains separate stat and ability fidelity values for every compression tier, stat rounding, wildtype stat conversion, dual-source package rules, and explicit ability recipes. `FusionEngine` computes Imprint stats as `max + stat alpha × min` and begins with `ability alpha × full ability value`. When both parents have abilities, the effective budget is floored at the combined value of every parent's minimum legal ability versions, ensuring packages from either source and mixed-source packages are enumerated regardless of argument order. Ability-free wildtypes convert unused effective ability value into configurable bonus ATK and HP. The engine enumerates authored discrete variants, fixed effects, omissions, and recipes; removes exact duplicates; then ranks preservation of both source identities before value and diversity. Selected cards persist both fidelity values, the effective ceiling, chosen value, bonuses, and all resolved fields so later balancing does not silently change an existing player-authored card. Confluence unions unique subtypes; Imprint offers either source's complete subtype set. Same-element pairs generate only Confluence. The selected merged name chooses the artwork from the source supplying its first name part. Resolved cards store `merge_count`; candidate generation rejects a source at depth two and sets the result to `max(source depths) + 1`. See `docs/FUSION_RULES.md` for the normative rules.

The CSV in `docs/design/` is a design and balance worksheet, not a runtime source. `data/cards.json` is the authoritative implementation format.

## Match State

Each battlefield is a fixed 32-element array mapped row-major to four rows and eight columns. Empty entries are `null`. Playing a persistent card chooses uniformly from the current empty indexes. The match UI intentionally hides this grid and renders only occupied cards.

Pillars are separate match records with a unique runtime ID, an output element, an image, and optionally a Merge action. They have no battlefield-slot index and no count cap. Attuned hybrid definitions add an `attunement` field and a one-mana base-element `cost`; their `element_tags[0]` remains the hybrid mana they produce.

The match state also stores HP, deck, hidden/public hand size, public Foundation and Vanguard IDs, persistent mana, discard, active player, target-selection state, timed player effects such as Cinder Ward, challenge/reward metadata, the randomly chosen bot-deck ID, a newly randomized RNG, and an input lock used during animations.

## Interaction Model

All player actions use Godot `Button` and `Control` signals, while Spacebar is routed to the same end-turn function as the battlefield button. Targeted abilities and Pillar fusion use a two-step source-then-target interaction with a visible status prompt. A shared square portrait renderer is used by hands, special zones, battlefields, Pillars, and the deckbuilder; pointer entry creates a margin-aware full-card overlay at the root UI level.

After the second compatible base Pillar is selected, `pillar_attune` targeting opens a modal containing both resolved attuned card definitions. `_complete_pillar_attunement` removes the two source records only after a choice is made; cancellation is therefore lossless. The bot selects an attunement by comparing current mana against the base-element demand in its hand. Decked hybrid Pillars pass through normal affordability and payment checks, unlike zero-cost base Pillars.

Combat is asynchronous. The resolver orders occupied attacking slots, calculates a per-attack delay from a two-second total, triggers the card edge wave, applies damage, shows floating damage text, and then advances to the next slot. Input remains locked until combat and the bot response complete.

Scorch, Fireball, sacrifices, and Berserker Draught use one effect-target state. `_is_effect_targetable` drives both validation and the aim markers rendered on battlefield portraits and HP bars. Direct damage first mutates state, synchronizes HP/stat widgets, and only then starts the flash and floating number. The floating face-damage number receives a small offset from the match RNG. `_finish_match` applies profile rewards once, saves the active account, and schedules a Lobby return; surrender clears the match and returns immediately.

Foundation/Vanguard selection is stateful rather than dropdown-based. `deck_special_target` identifies the armed slot; collection cards validate against the slot rule before replacement. Selector children are removed synchronously before rebuilding, preventing a queued-free old portrait and its replacement from appearing together for one frame.

The Deck route renders the profile's deck library and `DeckEditor` renders the selected entry identified by `editing_deck_id`. Save validation opens a naming modal before replacing that dictionary entry. `active_deck_id` is persisted per profile, migrated to an existing deck when necessary, and resolved by `_new_match`. Invalid drafts cannot be activated. Clone operations deep-copy the deck under a new stable ID; deletion repairs the active ID when needed.

Collection uses a `TabContainer` to keep card and item inventory in independent full-height pages. Forge uses three upper regions (Confluence, centered sources/name, and a vertically scrolling two-column Imprint grid) plus the same filtered portrait collection pattern as Deckbuilder. Creature candidates still come from `FusionEngine.result_candidates`; base-Pillar pairs are resolved to the two immutable Attuned Pillar definitions and use an existing-card collection transaction rather than creating a merged-card definition. Fusion ownership is committed before the result overlay begins, so presentation interruption cannot leave consumed sources without the created card. After commitment, source IDs are retained individually when their post-transaction owned quantities permit another use, and the selected candidate index is retained when both slots survive.

Pack opening uses the pack size and pool from configuration, updates collection counts atomically in the active profile, saves, and presents the results in an overlay. The Bazaar uses separate tab pages for single cards and item/pack offers. Purchases save before a modal acquisition tween runs; its input-blocking shade prevents accidental repeat purchases during feedback. Pack purchases add unopened inventory.

Pillar production happens only after combat/effect resolution. The presentation layer groups equal records into a single portrait and stores its element and represented count as UI metadata. At the instant the fixed one-second production highlight begins, that count is added to the existing mana dictionary and the mana grid is redrawn. Neither turn transition replaces nor clears that dictionary.

Bot direct-damage targeting assigns a large bonus to lethal unit targets, then ranks them with `_unit_threat`, which weighs current attack, HP, damage/scaling/control abilities, and engine value. Burn targeting performs the same check against existing plus newly applied Burn, prioritizing creatures that will die at their next end-of-turn resolution. Activated Freeze uses the same valuation to select the highest-value opposing battlefield card, pays the ability's own cost, and records its once-per-turn use. Frozen sources are rejected by both player and bot activation paths. Spell-specific helpers choose low-value sacrifice fodder and high-value surviving buff targets. Cinder Ward is stored as a remaining opposing-combat counter on the protected player; its retaliation is applied in the face-attack branch before deaths are resolved and the counter decrements once after that combat phase.

Nature spells reuse the generic effect-target state for friendly buffs, multi-target temporary Shell, and creature-count damage. Runtime units store temporary Shell strength and owner-turn duration separately from printed abilities. Spore attrition resolves after Burn and Clock effects but before Pillar production at the afflicted side's end turn. Seed Elf and Spore are non-collectible, non-deck-eligible token definitions; First Sprout may still put Seed Elf IDs into the transient match hand.

All Freeze entry points route through `_apply_freeze_to_unit`. Normal creatures receive the duration as Frozen turns; cards with Frozen Incubation reduce their Clock instead. Clock is initialized from the card's Clock strength in the unit record and advances after that owner's Burn resolution but before Pillar production. Reaching zero replaces the unit record in the same slot with a fresh Sea Drake. Deep Freeze keeps a selected-slot set in targeting state, supports both battlefields, and resolves its pending spell only after three unique selections or exhaustion of legal targets.

The side rails render all six mana pools as a two-column icon grid. Layered HP progress bars show current HP over the projected post-combat value; the immediate-combat forecast uses current board attack, frozen state, armed Strike state, and Scald. Pending Burn is displayed separately because it resolves at the end of its afflicted side's own turn. Cards show pending Burn and permanently granted Burn independently. Activated cards receive a short element-colored overlay animation. Portrait artwork uses a shared canvas shader so the image corners follow the rounded card contour.

`_ability_description` is the single presentation resolver for `abilities.json` text and per-card placeholders such as `strength`, `duration`, and `hp_change`. Full-card spell rows render that description directly. Keyword labels retain `_ability_label` for compactness and use the resolved description as hover-panel content; battlefield activated-ability buttons use the same tooltip source.

## Persistence Rules

The profile is saved after fusion, every deck edit that is explicitly saved, and debug export. Fusion validates ownership before mutating counts. A failed validation does not partially consume cards.

Existing prototype profiles retain their collection, merged cards, and decks, but migration no longer injects missing bootstrap cards. A fresh or newly created profile is empty until `apply_starter_deck` atomically grants its selected starter and creates its active deck. For a clean debug first run, `scripts/reset_profiles.gd` removes `accounts.json`, the legacy `profile.json`, and the debug export from the exact Godot user-data directory.

Room backgrounds are ordinary `TextureRect` layers beneath the application shell. Their resource paths are data-driven and safely fall back to the flat application color if an asset is absent.

## Verification

Automated checks cover:

- Confluence and fidelity-weighted Imprint cost/stat calculations.
- Ability metadata coverage, scaling values, budget ceilings, package preservation, and explicit recipes.
- Unlimited Pillar deck copies and ordinary six-copy limits.
- Collection consumption and merged-card acquisition.
- Delayed end-of-turn Pillar mana and in-match fusion.
- Random placement constrained to 32 slots.
- Numeric Scorch and Last Spark behavior, plus stacking end-of-owner-turn Burn on players and cards.
- Paid, random-creature Strike behavior.
- Confluence and Imprint subtype fusion rules.
- Loading Collection, Fusion, Deck, and Match screens.
- Loading Lobby, Profile, Bazaar, and every existing gameplay room.
- Randomized match seeds, one-card starting selectors, HP-bar Scorch feedback, and Lobby return after victory or surrender.
- Desktop and 720 by 1280 mobile rendering.
- Mirrored LAN host/guest orientation, turn-state handoff, and a real two-process ENet/discovery handshake.
