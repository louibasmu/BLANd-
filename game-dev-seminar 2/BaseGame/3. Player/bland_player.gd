class_name BlandPlayer
extends RefCounted # object type 
## A seat at the table (the human or a bot).
##
## Holds everything the game needs to remember about one player: their hand plus
## their scores and status for the current round. It has no behaviour of its own beyond
## small hand queries; the rules live in bland_game.gd.

# Seat number 0-3 (0 is always the human). The table and the bots use this to refer to a player.
var index: int = 0 # starting value 
var display_name: String = "" # name shown on screen
var is_human: bool = false # whether it's human: true for player, false for bots

var hand: Array[BlandCard] = [] # The cards this player currently holds. Order matters: new cards go on the end.


var total_score: int = 0 # Running score across all rounds (pair points are added immediately; Joker penalties are applied at round end).
var round_pairs: int = 0# Pairs made so far this round (also used to calculate the round summary).
var paired_ranks: Array[int] = []   # ranks this player has paired this round (shown on the table)
var paired_cards: Array = []        # [card_a, card_b] for each pair, so the table can show suit colours
var round_penalty: int = 0 # Points to subtract at round end (Joker penalty). Reset every round.
# How many upcoming turns this player must miss. Set by the Freeze card and counted down
# by the game at the start of each of their turns (Skip is tracked separately in BlandGame).
var frozen_turns: int = 0
var finished: bool = false          # emptied their hand this round: safe from the Joker, can't rejoin; true once hand is empty


# Called when the game seats a player. `p_` prefixes avoid clashing with the member names.
# runs automatically when we write BlandPlayer.new(0, "You", true)
# parameters start with p_ so they don’t have the same name as the member variables above
# void - returns nothing
func _init(p_index: int, p_name: String, p_human: bool) -> void: # when a player is created, recieves a seat number, a name and a human flag
	index = p_index # store the seat number in index
	display_name = p_name # store name
	is_human = p_human # store the human flag


# Wipes the per-round state ready for a new deal. total_score is deliberately NOT reset,
# since it accumulates over the whole game.
# runs between rounds
func reset_for_round() -> void: 
	hand.clear() # empty the hand, numbers get = 0 and booleans get = false.
	round_pairs = 0 # Set the round pair count to 0
	paired_ranks.clear() # Empty the lists of paired ranks and paired cards
	paired_cards.clear() 
	round_penalty = 0 # Set the round penalty to 0
	frozen_turns = 0 # Set frozen turns to 0
	finished = false # Mark the player as not finished
	


# How many Jokers are in this hand. At round end each one costs JOKER_PENALTY points.
func joker_count() -> int: # function returns a whole number
	#var n := 0 creates a local variable that exists only inside this function
	var n := 0 # Start a counter at 0
	for c in hand: # For each card in the hand:
		if c.is_joker(): 
			n += 1 # If the card is a Joker: Add 1 to the counter
	return n


# Convenience wrapper over joker_count(); this is what the Angel card reveals.
func has_joker() -> bool:
	return joker_count() > 0 # return true if the joker counts is more than 0


# All special cards currently in hand (used for both the human's buttons and the bot's choices).
# returns a new list, but leaves hand unchanged
func specials() -> Array[BlandCard]: # building and returning a list
	var out: Array[BlandCard] = [] # Make an empty list called out
	for c in hand: # For each card in the hand:
		if c.is_special(): #  If the card is a special card: Add it to out
			out.append(c) # adds one item to the end
	return out 


# How many scoring (pair) cards remain in hand, ignoring specials and Jokers.
func pair_card_count() -> int: # counting and filter loop
	var n := 0 
	for c in hand: # For each card in the hand:
	#If it is an ordinary pair card (not special, not Joker):
	   # Counter + 1
		if c.is_pair_card():
			n += 1
	return n


# Finds a card in this hand that would pair with `card`, or null if there is none.
# Used right after drawing to see whether a pair has just been made.
# takes a parameter, card, and returns a BlandCard or null
func find_match_for(card: BlandCard) -> BlandCard: # given a card
	for c in hand: # for eac card in the hand
		if card.matches(c): # If the given card pairs with this one
			return c # Give back this card and stop
	return null # If none matched, give back "nothing" (null)


# Sorts the hand using BlandCard.sort_key() (pairs by rank, then specials, then Jokers).
# Nothing calls this at the moment (hands stay in dealt order so the player must arrange them
# themselves), but it is ready to use, e.g. for a "sort my hand" button.
func sort_hand() -> void:
	hand.sort_custom(func(a: BlandCard, b: BlandCard) -> bool: return a.sort_key() < b.sort_key())
