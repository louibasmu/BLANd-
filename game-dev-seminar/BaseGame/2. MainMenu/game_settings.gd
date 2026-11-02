class_name GameSettings
extends RefCounted
## Tunable rules + the settings chosen on the main menu.
##
## This class is never instantiated: everything is `static`, so the main menu can change values
## and the game scene (loaded afterwards) reads the same values. Rules that should not change are `const`.
## Everything the team decided on 10/5 lives here so it is easy to change.
## Which brain the bots use (see bot_brain.gd): purely random choices, or simple rules of thumb.

enum BotStyle { RANDOM, BASIC }

# Number of rounds picked on the menu (clamped to MIN_ROUNDS..MAX_ROUNDS when a game is created).
# --- Chosen on the main menu (static so they survive the scene change) ---
static var pair_card_count: int = 40
static var num_rounds: int = 5
static var bot_style: int = BotStyle.BASIC
# Delay table for the menu's bot-speed choice, in seconds, so the human can follow what the bots do.
static var bot_delay: float = 1.4   # seconds between bot actions (set from the menu)
# Bots speed up to this once the human has run out of cards, since there is nothing left to watch.

const BOT_SPEEDS := {"Slow": 2.2, "Normal": 1.4, "Fast": 0.7}
const FAST_FORWARD_DELAY := 0.2   # bot speed once you're out of cards for the round

# --- Fixed rules from the 10/5 meeting ---
const NUM_PLAYERS := 4          # always 4, nobody is removed between rounds
const MIN_ROUNDS := 3
const MAX_ROUNDS := 7
const JOKER_PENALTY := 4        # points lost per Joker held when a round ends
# The deck is 40 pair cards: ranks Ace(1) to 10, four suits each.
const POINTS_PER_PAIR := 1
const FREEZE_TURNS := 2         # Freeze = target misses their next 2 turns

# Pair cards: A-10 in all four suits = 40 cards
const PAIR_RANKS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# Default special card counts (3 + 3 + 2 + 2 + 1 + 1 = 12). The player can change these
# in the Special Cards setup on the main menu; the game uses `special_counts`.
# in the Special Cards setup on the main menu; the game uses `special_counts`.
const DEFAULT_SPECIAL_COUNTS := {
	BlandCard.Special.SKIP: 3,
	BlandCard.Special.REVERSE: 3,
	BlandCard.Special.GIVE: 2,
	BlandCard.Special.FREEZE: 2,
	BlandCard.Special.ANGEL: 1,
	BlandCard.Special.VISION: 1,
# Upper limit per special type, used as the maximum of the setup screen's number boxes.
}
# The live counts (a copy of the defaults so editing them never changes DEFAULT_SPECIAL_COUNTS).

const MAX_COPIES_PER_SPECIAL := 6
static var special_counts: Dictionary = DEFAULT_SPECIAL_COUNTS.duplicate()

# Colours/names used for the rarity border on special cards.
# Rarity depends on how many copies of a card are in the deck:
#   1 copy = Rare (purple border), 2 = Uncommon (green), 3+ = Common (light blue)
enum Rarity { NONE, RARE, UNCOMMON, COMMON }
const RARITY_NAMES := {Rarity.NONE: "Not in deck", Rarity.RARE: "Rare", Rarity.UNCOMMON: "Uncommon", Rarity.COMMON: "Common"}
const RARITY_COLORS := {
	Rarity.NONE: Color(0.5, 0.5, 0.5),
	Rarity.RARE: Color(0.66, 0.33, 0.97),      # purple
	Rarity.UNCOMMON: Color(0.2, 0.8, 0.3),     # green
	Rarity.COMMON: Color(0.45, 0.78, 1.0),     # light blue
# Small lookup helpers so other scripts do not have to know how the dictionaries are laid out.
# count_of: how many copies of this special are in the deck (0 if none).
}


static func count_of(special: int) -> int:
	# Total number of special cards in the deck.
	return special_counts.get(special, 0)


static func total_specials() -> int:
	var n := 0
	for k in special_counts:
		n += special_counts[k]
	# Converts a copy count into a rarity (fewer copies = rarer).
	return n


static func rarity_for_count(count: int) -> int:
	if count <= 0:
		return Rarity.NONE
	if count == 1:
		return Rarity.RARE
	if count == 2:
		return Rarity.UNCOMMON
	# Rarity of a special, based on how many copies are currently in the deck.
	return Rarity.COMMON


static func rarity_of(special: int) -> int:
	# The border colour for a special's rarity.
	return rarity_for_count(count_of(special))


static func rarity_color(special: int) -> Color:
	# The rarity name for a special, e.g. "Rare".
	return RARITY_COLORS[rarity_of(special)]


static func rarity_name(special: int) -> String:
	return RARITY_NAMES[rarity_of(special)]


# Jokers per round, keyed by how many rounds the player picked.
# Copied from the "Difficulty Curve" sheet in likelihood_for_card_nums.xlsx.
# Each list is the number of Jokers for round 1, 2, 3 ... so the game gets harder as it goes on.
# Copied from the "Difficulty Curve" sheet in likelihood_for_card_nums.xlsx.
const JOKER_SCHEDULE := {
	3: [1, 2, 3],
	4: [1, 1, 2, 3],
	5: [1, 1, 2, 2, 3],
	6: [1, 1, 2, 2, 3, 3],
	7: [1, 1, 1, 2, 2, 2, 3],
# Number of Jokers for a given round. A round number past the end of the list reuses the last entry,
# and an unknown round count falls back to a single Joker.
}
# clampi keeps the index inside the list, and round numbers start at 1 while list indexes start at 0, hence the -1.


static func jokers_for_round(total_rounds: int, round_number: int) -> int:
	var schedule: Array = JOKER_SCHEDULE.get(total_rounds, [1])
	var i: int = clampi(round_number - 1, 0, schedule.size() - 1)
	# Text for the menu showing the schedule, e.g. "Jokers per round — R1: 1   R2: 1 ...".
	return schedule[i]


static func schedule_text(total_rounds: int) -> String:
	var parts: PackedStringArray = []
	var schedule: Array = JOKER_SCHEDULE.get(total_rounds, [])
	for i in schedule.size():
		parts.append("R%d: %d" % [i + 1, schedule[i]])
	# Rules shown in the "How to play" screen. Written in Godot's BBCode ([b] = bold, [color] = colour);
	# it should be updated whenever the rules above change.
	return "Jokers per round  —  " + "   ".join(parts)


const RULES_TEXT := """[b]Goal[/b]
Score the most points after all rounds. Every pair you make is worth 1 point. Anyone still holding a Joker when the round ends loses 4 points per Joker.

[b]The deck[/b]
40 pair cards (A–10, four suits), the special cards (12 by default; change them in Special Cards setup), plus 1–3 Jokers depending on the round. All cards are dealt out to the 4 players. Pairs in your starting hand are discarded (and scored) right away.

[b]Before each round[/b]
Your hand is dealt in random order. Arrange it however you like, then lock it. Once the round starts you can't reorder, and any card you take or receive goes to the end of your hand.

[b]Your turn[/b]
On your turn you either [b]draw[/b] a face-down card from ANY other player who still has cards (pick the player, then the card), or [b]play a special card[/b] from your hand.
• [b]Make a pair → go again.[/b] Draw again or play a special.
• [b]Draw a special card[/b] → you may play it right away, or keep it for later (keeping it ends your turn).
• [b]Play a special and don't make a pair → your turn is over[/b] — except [b]Skip[/b] and [b]Reverse[/b]: after playing one of those you still take a card.
• Draw anything else → your turn is over.

[b]Special cards[/b]  (border colour = rarity: [color=#73c7ff]light blue = Common[/color] (3+ copies), [color=#33cc4d]green = Uncommon[/color] (2), [color=#a854f7]purple = Rare[/color] (1))
• [b]Skip[/b] (3) – the next player loses their turn.
• [b]Reverse[/b] (3) – turn order flips direction.
• [b]Give[/b] (2) – give one card from your hand to any player. Yes, you can give away a Joker.
• [b]Freeze[/b] (2) – pick a player; they miss their next 2 turns.
• [b]Angel[/b] (1) – pick a player; you learn whether they hold a Joker (yes/no).
• [b]Vision[/b] (1) – pick a player and a card position (the numbers under their cards). You see that card, then take it or leave it. If taking it makes a pair you go again; otherwise your turn ends.

[b]End of round[/b]
A player who runs out of cards is [b]out for the round and safe from the Joker[/b]. They can't be drawn from, given cards, or targeted, and they don't rejoin until the next round.
The round ends when every pair card has been matched. Jokers left in hands cost 4 points each. Players never leave the game – everyone plays every round.
"""
