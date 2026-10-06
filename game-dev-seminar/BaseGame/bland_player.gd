class_name BlandPlayer
extends RefCounted
## A seat at the table (the human or a bot).

var index: int = 0
var display_name: String = ""
var is_human: bool = false
var hand: Array[BlandCard] = []

var total_score: int = 0
var round_pairs: int = 0
var paired_ranks: Array[int] = []   # ranks this player has paired this round (shown on the table)
var paired_cards: Array = []        # [card_a, card_b] for each pair, so the table can show suit colours
var round_penalty: int = 0
var frozen_turns: int = 0
var finished: bool = false          # emptied their hand this round: safe from the Joker, can't rejoin


func _init(p_index: int, p_name: String, p_human: bool) -> void:
	index = p_index
	display_name = p_name
	is_human = p_human


func reset_for_round() -> void:
	hand.clear()
	round_pairs = 0
	paired_ranks.clear()
	paired_cards.clear()
	round_penalty = 0
	frozen_turns = 0
	finished = false


func joker_count() -> int:
	var n := 0
	for c in hand:
		if c.is_joker():
			n += 1
	return n


func has_joker() -> bool:
	return joker_count() > 0


func specials() -> Array[BlandCard]:
	var out: Array[BlandCard] = []
	for c in hand:
		if c.is_special():
			out.append(c)
	return out


func pair_card_count() -> int:
	var n := 0
	for c in hand:
		if c.is_pair_card():
			n += 1
	return n


func find_match_for(card: BlandCard) -> BlandCard:
	for c in hand:
		if card.matches(c):
			return c
	return null


func sort_hand() -> void:
	hand.sort_custom(func(a: BlandCard, b: BlandCard) -> bool: return a.sort_key() < b.sort_key())
