# Gameplay Rules

## Collection and Decks

A player owns a quantity of each collectible card. New profiles are populated from `data/bootstrap_profile.json`; the debug bootstrap grants ten copies of every base card and zero copies of hybrid Pillars.

A main deck contains at least 30 and at most 120 cards. A player cannot add more copies of a card than they own. Cards are copy-limited by displayed name rather than internal ID: at most three main-deck cards may share a name. Base Fire, Water, and Nature Pillars have no main-deck copy limit. Steam, Wildfire, and Swamp Pillars only exist as match results, have zero collectible copies, and cannot be added to a deck.

Every deck also chooses two public starting cards outside the main deck:

- The **Foundation** is one base Pillar.
- The **Vanguard** is one non-Pillar card.

Foundation and Vanguard choices do not count toward the 30–120 main-deck size or the three-copy name limit. They remain visible to both players and may be played exactly as though they were in hand.

## Forge

The Forge displays the player's full collection. Selecting a card places its full card into source slot A or B. Only cards with at least one uncommitted owned copy can be selected.

When two compatible source cards are selected, the player first chooses one of the two combined names. The selected name also selects the artwork of the card that contributes its first name part. The Forge then divides all legal full-card results into two equally valid expressions:

- **Confluence** combines both cards' stats, abilities, costs, and unique subtypes.
- **Imprint** uses the strongest component stats and lets one source identity shape abilities and subtypes while elemental costs are transformed.

The player selects one result and confirms the merge. Imprint is an alternative expression, not a lesser merge.

Cards of different compatible elements offer Confluence and every legal Imprint. Two cards of the same element may also merge, but only as a Confluence. A resulting card may be merged again once, for a maximum merge depth of two. One or two gold merge marks at the lower-right of every full card show its merge depth; a card with two marks cannot be selected as a Forge source.

Confirming a merge performs one atomic collection update:

1. Remove one copy of each source card.
2. Save the resolved merged-card definition with stable source IDs.
3. Add one copy of the new merged card to the collection.
4. Save the profile immediately.

The resulting name is rules-significant for the three-copy deck limit.

## Match Flow

A match begins with 100 HP, seven drawn cards, and each player's public Foundation and Vanguard. The opponent's starting cards sit directly below their hand, with the Foundation outside and Vanguard inside; the player's sit directly above their hand, with the Vanguard inside and Foundation outside. There are no phases. During the active turn a player may perform legal actions in any order:

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

A Pillar produces no mana when played. After all attacks, damage, deaths, and triggered effects resolve at the end of its controller's turn, each Pillar produces one mana into that player's next-turn reserve. All producing Pillars animate together for one second, and each grouped portrait adds its full represented quantity when its glow begins: a Fire Pillar portrait marked `×3` produces three Fire.

Multiple Pillars with the same identity are represented by one portrait with a white translucent `×N` count strip. Their mana production remains one mana per represented copy.

To merge Pillars, activate Merge on one Pillar and then select another compatible base Pillar. Fire plus Water becomes Steam, Fire plus Nature becomes Wildfire, and Water plus Nature becomes Swamp. The two sources are replaced by one hybrid Pillar. Like every Pillar, it first produces at the end of its controller's turn. Hybrid Pillars can exist in a match but are never deck cards.

## Abilities

Each ability reference on a card contains its own cost and target mode. This allows two cards with the same ability to charge different prices.

Ability controls appear over the battlefield card and show the ability name and cost. Clicking an ability with no target executes it immediately when affordable. Clicking a targeted ability enters selection mode; the next legal target completes the action. Selection can be cancelled without spending mana.

The initial abilities include Scorch, Fury, Burn, Last Spark, Strike, Freeze, Heal, Growth, Scald, Regeneration, Flame Strike, and the three spell effects. Freeze targets an opposing battlefield card. Strike is activated without selecting a target: during that turn's combat it attacks a random opposing creature if one exists, falling back to the opponent otherwise. A Strike combat exchanges both creatures' damage concurrently before deaths and death triggers are resolved.

## Combat and Damage

Ending the turn resolves attacks in ascending board-slot order. The entire attacking sequence is paced across approximately two seconds rather than resolving in one frame.

Each attacking card displays a brief edge-wave animation that rises along its left and right sides. When a card or player takes damage, the damage amount appears over the target, floats upward, and fades quickly.

After combat and all effects, the active player's Pillars run their one-second production animation and create the next-turn reserve. Unspent current mana is cleared, then control passes to the opponent. The bot uses the same timing.

Full cards show card genre through an icon; subtype names remain on one horizontal line. Cards without abilities leave the ability area empty rather than displaying placeholder copy. Collection, Forge, and deckbuilding ownership counts sit outside and immediately below the card frame.
