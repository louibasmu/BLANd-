class_name BlandPlayer

extends RefCounted

## A seat at the table (the human or a bot).
##
## Holds everything the game needs to remember about one player:
## their hand, scores, and status for the current round.
## The rules live in bland_game.gd.

# Seat number 0-3 (0 is always the human).
var index: int = 0

# Name shown on screen.
var display_name: String = ""

# Whether this is the human player.
var is_human: bool = false

# Cards currently held by the player. Order matters.
var hand: Array[BlandCard] = []

# Running score across all rounds.
var total_score: int = 0

# Pairs made so far this round.
var round_pairs: int = 0

# Ranks paired this round (shown on the table).
var paired_ranks: Array[int] = []

# Card pairs, stored as [card_a, card_b], for suit colours.
var paired_cards: Array = []

# Points to subtract at round end (Joker penalty).
var round_penalty: int = 0

# Number of upcoming turns this player must miss.
var frozen_turns: int = 0

# True when the player has emptied their hand this round.
var finished: bool = false


## Called when a player is created.
## Example: BlandPlayer.new(0, "You", true)
func _init(p_index: int, p_name: String, p_human: bool) -> void:
	index = p_index
	display_name = p_name
	is_human = p_human


## Resets per-round state.
## total_score is not reset because it accumulates across the game.
func reset_for_round() -> void:
	hand.clear()
	round_pairs = 0
	paired_ranks.clear()
	paired_cards.clear()
	round_penalty = 0
	frozen_turns = 0
	finished = false

## Returns the number of Jokers in the hand.
func joker_count() -> int:
	var n := 0

	for c in hand:
		if c.is_joker():
			n += 1

	return n

## Returns true if the player has at least one Joker.
func has_joker() -> bool:
	return joker_count() > 0

## Returns all special cards currently in the hand.
## Creates a new list without changing the original hand.
func specials() -> Array[BlandCard]:
	var out: Array[BlandCard] = []

	for c in hand:
		if c.is_special():
			out.append(c)

	return out

## Counts scoring cards remaining in the hand.
## Ignores special cards and Jokers.
func pair_card_count() -> int:
	var n := 0

	for c in hand:
		if c.is_pair_card():
			n += 1

	return n

## Finds a card that would pair with the given card.
## Returns null if there is no match.
func find_match_for(card: BlandCard) -> BlandCard:
	for c in hand:
		if card.matches(c):
			return c

	return null

## Sorts the hand using BlandCard.sort_key().
## Pairs are sorted by rank, followed by specials and Jokers.
func sort_hand() -> void:
	hand.sort_custom(
		func(a: BlandCard, b: BlandCard) -> bool:
			return a.sort_key() < b.sort_key()
	)
