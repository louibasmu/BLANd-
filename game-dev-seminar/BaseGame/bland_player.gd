class_name BlandPlayer
extends RefCounted
## A seat at the table (the human or a bot).
##
## Holds everything the game needs to remember about one player: their hand plus
## their scores and status for the current round. It has no behaviour of its own beyond
## small hand queries; the rules live in bland_game.gd.

# Seat number 0-3 (0 is always the human). The table and the bots use this to refer to a player.
var index: int = 0
var display_name: String = ""
var is_human: bool = false
# The cards this player currently holds. Order matters: new cards go on the end.
var hand: Array[BlandCard] = []

# Running score across all rounds (pairs earn points, Jokers at round end lose points).
var total_score: int = 0
# Pairs made so far this round (points are added to total_score when the round ends).
var round_pairs: int = 0
var paired_ranks: Array[int] = []   # ranks this player has paired this round (shown on the table)
var paired_cards: Array = []        # [card_a, card_b] for each pair, so the table can show suit colours
# Points to subtract at round end (Joker penalty). Reset every round.
var round_penalty: int = 0
# How many upcoming turns this player must miss. Set by the Freeze card and counted down
# by the game at the start of each of their turns (Skip is tracked separately in BlandGame).
var frozen_turns: int = 0
var finished: bool = false          # emptied their hand this round: safe from the Joker, can't rejoin


# Called when the game seats a player. `p_` prefixes avoid clashing with the member names.
func _init(p_index: int, p_name: String, p_human: bool) -> void:
	index = p_index
	display_name = p_name
	is_human = p_human


# Wipes the per-round state ready for a new deal. total_score is deliberately NOT reset,
# since it accumulates over the whole game.
func reset_for_round() -> void:
	hand.clear()
	round_pairs = 0
	paired_ranks.clear()
	paired_cards.clear()
	round_penalty = 0
	frozen_turns = 0
	finished = false


# How many Jokers are in this hand. At round end each one costs JOKER_PENALTY points.
func joker_count() -> int:
	var n := 0
	for c in hand:
		if c.is_joker():
			n += 1
	return n


# Convenience wrapper over joker_count(); this is what the Angel card reveals.
func has_joker() -> bool:
	return joker_count() > 0


# All special cards currently in hand (used for both the human's buttons and the bot's choices).
func specials() -> Array[BlandCard]:
	var out: Array[BlandCard] = []
	for c in hand:
		if c.is_special():
			out.append(c)
	return out


# How many scoring (pair) cards remain in hand, ignoring specials and Jokers.
func pair_card_count() -> int:
	var n := 0
	for c in hand:
		if c.is_pair_card():
			n += 1
	return n


# Finds a card in this hand that would pair with `card`, or null if there is none.
# Used right after drawing to see whether a pair has just been made.
func find_match_for(card: BlandCard) -> BlandCard:
	for c in hand:
		if card.matches(c):
			return c
	return null


# Sorts the hand using BlandCard.sort_key() (pairs by rank, then specials, then Jokers).
# Nothing calls this at the moment (hands stay in dealt order so the player must arrange them
# themselves), but it is ready to use, e.g. for a "sort my hand" button.
func sort_hand() -> void:
	hand.sort_custom(func(a: BlandCard, b: BlandCard) -> bool: return a.sort_key() < b.sort_key())
