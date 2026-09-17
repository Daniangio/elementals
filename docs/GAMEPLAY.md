# Gameplay Rules

## Lobby and Profiles

The Lobby is the navigation hub. It lists every current and planned room from `data/game_config.json`: Profile, Collection, Deck, Forge, Bazaar, Match, Quests, and Arena. Planned rooms are visible but disabled.

On a fresh installation, the player chooses a name before entering the Lobby. An offline profile owns its name, level, XP, crowns, collection, unopened packs, merged cards, and decks. The Profile room can create and switch between multiple independent local profiles, similar to choosing a user on a streaming service.

Winning a match grants the configured XP and crown reward; a loss grants the configured participation XP. Finished matches and surrendered matches return to the Lobby.

## Collection and Decks

A player owns a quantity of each collectible card. New profiles are populated from `data/bootstrap_profile.json`; the debug bootstrap grants ten copies of every base card and every attuned hybrid Pillar. The old unattuned hybrid definitions remain non-collectible compatibility records.

A main deck contains at least 30 and at most 120 cards. A player cannot add more copies of a card than they own. Cards are copy-limited by displayed name rather than internal ID: at most three main-deck cards may share a name. Every Pillar ignores the three-copy name limit but remains limited by owned copies. Base Fire, Water, and Nature Pillars cost zero. Attuned Steam, Wildfire, and Swamp Pillars may be included in decks and cost one mana of their attuned base element to play.

The Deck room is a library rather than the editor itself. Every deck preview shows its saved name, Foundation, Vanguard, card count, and active status. From the library a player may create, edit, clone, delete, or make a valid deck active. The active deck is the one loaded by Match. An incomplete draft remains editable but cannot become active; deleting a deck requires confirmation, and the final remaining deck cannot be deleted.

Every deck also chooses two public starting cards outside the main deck:

- The **Foundation** is one base Pillar.
- The **Vanguard** is one non-Pillar card.

Foundation and Vanguard choices do not count toward the 30–120 main-deck size or the three-copy name limit. They remain visible to both players and may be played exactly as though they were in hand.

In the Deckbuilder, Foundation and Vanguard are stacked in a right-hand column within the main deck panel, leaving the rest of the vertical space to the main deck and collection. Pressing **Select from collection** arms either slot. The armed slot is highlighted, compatible collection cards are highlighted, and the next compatible card clicked replaces the previous choice. The selector always displays exactly one current card. Saving first validates the deck and then asks for its display name.

## Bazaar, Packs, and Collection Items

Crowns are the offline in-game currency. The Bazaar sells pack and single-card offers loaded from `data/game_config.json`. Each single-card entry independently defines its card ID and crown price, so the market can be expanded without changing gameplay code. The initial card market sells only the three base Pillars for 12 crowns each. The initial Elemental Core Pack costs the configured amount and contains eight independently drawn base cards.

Purchased packs are inventory items rather than immediately opened cards. Collection has separate **Cards** and **Items** pages so the card browser uses the full room. Items shows unopened pack quantities and an Open action. Opening a pack displays a full-screen result overlay and adds every revealed card to that profile's collection.

## Forge

The Forge displays the player's collection as a horizontal strip across the bottom half of the room. Selecting a card places its full card into one of the two centered source slots. Name and artwork selection sits below those slots; Confluence results occupy the left panel and the horizontally scrollable Imprint choices occupy the right. Only cards with at least one uncommitted owned copy can be selected.

When two compatible source cards are selected, the player first chooses one of the two combined names. The selected name also selects the artwork of the card that contributes its first name part. The Forge then divides all legal full-card results into two equally valid expressions:

- **Confluence** adds both cards' stats, abilities, costs, and unique subtypes.
- **Imprint** converts paired elemental costs into hybrid mana. Its fidelity is based on the converted share: each stat becomes the larger source stat plus stat alpha times the smaller, while abilities use a separate, more generous ability alpha so hybrids retain meaningful effects. Legal scaled packages must remain beneath that ability budget. It keeps either source's subtype set.

Ability descriptions, power evaluations, and legal integer strength ranges are explicit in data/abilities.json. Fidelity tiers and special recipes live in data/fusion_rules.json. The Forge lists all deterministic legal packages, preferring results that preserve both source identities; it never silently selects one for the player. Full formulas and persistence rules are documented in docs/FUSION_RULES.md.

Selecting one result reveals the Merge button between the source slots. Pressing it commits the collection transaction immediately, then opens a modal animation in which the two sources collapse into particles and reveal the resulting card. The result is already safely owned while the player views and closes this presentation. Imprint is an alternative expression, not a lesser merge.

Cards of different compatible elements offer Confluence and every legal Imprint. Two cards of the same element may also merge, but only as a Confluence. A resulting card may be merged again once, for a maximum merge depth of two. One or two gold merge marks at the lower-right of every full card show its merge depth; a card with two marks cannot be selected as a Forge source.

Confirming a merge performs one atomic collection update:

1. Remove one copy of each source card.
2. Save the resolved merged-card definition with stable source IDs.
3. Add one copy of the new merged card to the collection.
4. Save the profile immediately.

The resulting name is rules-significant for the three-copy deck limit.

## Match Flow

A match begins with 100 HP, seven drawn cards, and each player's public Foundation and Vanguard. Every new match creates a newly randomized shuffle; repeated matches do not reuse a fixed seed. The opponent's starting cards sit directly below their hand, with the Foundation outside and Vanguard inside; the player's sit directly above their hand, with the Vanguard inside and Foundation outside. There are no phases. During the active turn a player may perform legal actions in any order:

- Play a base Pillar.
- Play an affordable creature, structure, spell, or merged card.
- Activate an affordable ability shown on a card.
- Merge two compatible base Pillars.
- End the turn with Spacebar or the **End Turn (Spacebar)** battlefield button.

Playing a non-Pillar persistent card places it into one random empty slot on a 4-row by 8-column battlefield. Structures occupy slots but do not normally attack.

The opponent's hand is a vertical stack at the upper left and the player's hand is a vertical stack at the lower right. Cards overlap with a vertical step of roughly twenty-five percent of a portrait's height. Both hands use square portraits with costs outside the card; playable player cards and their costs are highlighted.

The underlying battlefield remains a random 32-slot array, but empty slots are not drawn. Creatures appear as compact square image cards in the central field, while Pillars, Structures, and Items use the back row. Player mana appears in the lower-left rail and opponent mana in the upper-right rail. Each mana rail is a two-column grid containing every base and merged mana type, including zero balances, and uses the same illustrated icons as card and ability costs.

An HP bar below each mana grid shows current and maximum HP. Its red forecast segment and numeric suffix show the face damage currently threatened by the opposing board.

Hovering any portrait in a hand, battlefield, Pillar row, deck, or deckbuilding collection opens a full-card preview beside the pointer. The preview changes side near viewport edges so it remains visible.

The main menu links to Collection, Deck, Forge, and Match. During a match all navigation is removed; the top menu only offers Surrender.

## Pillars

Pillars are displayed as cards in a dedicated row. The opponent's Pillars are above their battlefield; the player's Pillars are below their battlefield.

A Pillar produces no mana when played. After all attacks, damage, deaths, and triggered effects resolve at the end of its controller's turn, each Pillar adds one mana to that player's persistent pool. Unspent mana carries across turns: producing five Fire while two Fire remain raises the pool to seven. All producing Pillars animate together for one second, and each grouped portrait adds its full represented quantity when its glow begins, at the exact moment the displayed mana total changes.

Multiple Pillars with the same identity are represented by one portrait with a white translucent `×N` count strip. Their mana production remains one mana per represented copy.

To merge Pillars, activate Merge on one Pillar and then select another compatible base Pillar. Fire plus Water becomes Steam, Fire plus Nature becomes Wildfire, and Water plus Nature becomes Swamp. Before replacing the sources, the player must choose **Attune** for either source element:

- Fire + Water offers Fire-Attuned Steam and Water-Attuned Steam.
- Fire + Nature offers Fire-Attuned Wildfire and Nature-Attuned Wildfire.
- Water + Nature offers Water-Attuned Swamp and Nature-Attuned Swamp.

Both variants produce the same hybrid mana. Attunement determines the one-mana play cost when that hybrid Pillar is included in a deck; a hybrid created directly on the battlefield has already been formed and pays no additional cost. Cancelling the Attune panel leaves both source Pillars unchanged.

## Abilities

Each ability reference on a card contains its own cost and target mode. This allows two cards with the same ability to charge different prices.

Ability controls appear over the battlefield card and show the ability name and cost. Clicking an ability with no target executes it immediately when affordable. Clicking a targeted ability enters selection mode; legal cards and player HP bars receive a clickable aim marker. A mandatory on-play or spell target must be resolved before another action or End Turn.

Scorch deals its numeric damage to any selected player or card with HP, including its controller and friendly cards. Freeze is an activated targeted ability, normally costing one Water. Its controller selects one opposing card; that card cannot attack or activate abilities for a number of its turns equal to Freeze's strength. The persistent ice overlay shows the remaining count. The bot selects the highest-value legal opposing card. Bounce returns up to its numeric number of highest-threat opposing creatures to their owner's hand and animates each departing card. Shell reduces each instance of combat damage dealt to its creature by its numeric value, to a minimum of zero, and appears as a translucent shield. Provoke redirects up to its numeric number of opposing attackers to fight its creature during combat; its icon and ability flash identify the interception. Strike is activated without selecting a target: during that turn's combat it attacks a random opposing creature if one exists, falling back to the opponent otherwise. Creature combat exchanges both creatures' damage concurrently before deaths and death triggers are resolved.

Each activated ability on a card can be used only once per turn unless its definition explicitly sets `repeatable` to true. Usage resets at the start of that card controller's turn.

The Fire spell suite is:

- **Fireball** — 3 Fire; deal 6 damage to any player or card with HP.
- **Fire Rain** — 4 Fire; deal 2 damage to every enemy creature and structure.
- **Ember Offering** — 1 Fire; sacrifice a friendly creature and gain 8 Fire.
- **Cinder Ward** — 4 Fire; for the next three opposing combat phases, each creature that attacks the protected player takes 2 concurrent retaliation damage. A pulsing fire line and remaining duration appear on that battlefield.
- **Ashen Bargain** — 1 Fire; sacrifice a friendly creature and draw two cards.
- **Berserker Draught** — 3 Fire; give any card with HP +5 ATK and deal 3 damage to it.

Nature builds a wide battlefield through Sapling tokens and persistent creature synergies. Spawn Sapling creates a 1/1 token, either when its source enters or through an explicitly costed activation. Sprout creates Saplings at turn start. Nurture permanently grants +ATK/+HP to another highest-value friendly creature. Elf Chorus gives other friendly Elves ATK while its source remains in play. Pack Growth gives its source +ATK/+HP for other creatures sharing a subtype, while Living Grove counts every other friendly creature. Grove Blessing permanently increases every friendly creature's maximum and current HP. Elder Call creates a 2/2 Elder Sapling. Dynamic bonuses update when creatures enter or leave play; tokens are neither collectible nor deck-eligible.

The bot scores opposing cards from current attack, HP, relevant damage or engine abilities, and card type. Damage effects strongly prefer a lethal low-HP target, then break viable choices by this threat score. Sacrifice spells offer its least valuable creature, while Berserker Draught favors a high-threat card that survives the HP loss.

## Combat and Damage

Ending the turn resolves attacks in ascending board-slot order. The entire attacking sequence is paced across approximately two seconds rather than resolving in one frame.

Each attacking card displays a brief edge-wave animation that rises along its left and right sides. When a card or player takes damage, the damage amount appears over the target, floats upward, and fades quickly.

Face damage numbers appear beside the damaged player's HP bar with a small randomized offset. HP totals and portrait stats change in the same frame that the damage animation begins, rather than on the following hit or refresh.

After combat and all effects, the active player's Pillars run their one-second production animation and add to the persistent mana pool. Unspent mana is not cleared when control passes. The bot uses the same timing.

Full cards show card genre through an icon; subtype names remain on one horizontal line. Spell cards print their complete resolved effect description in the ability area instead of repeating the spell ability name. Creature and structure keywords remain compact—such as **Scorch 2** or **Last Spark 3**—and hovering a keyword opens its textual rules explanation. Activated ability controls expose the same explanation. Cards without abilities leave the ability area empty rather than displaying placeholder copy. Collection, Forge, and deckbuilding ownership counts sit outside and immediately below the card frame.

Lobby, Profile, Collection, Deck, Forge, Bazaar, and Match each use a configurable fantasy background. Background paths live in `data/game_config.json` and can be replaced without changing UI code.
