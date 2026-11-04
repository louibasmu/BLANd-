class_name BlandGame
extends RefCounted
## All of the rules, with no UI. The table scene and the bots both drive the
## game only through the public functions below, so the rules can be changed
## (or simulated headless, see tools/simulate.gd) without touching the UI.
##
## Typical flow of one game:
##   start_round() -> ARRANGE (players reorder their hand) -> finish_arranging() ->
##   turns (PLAY_OR_DRAW ...) -> _finish_round() -> ROUND_OVER -> next_round() -> ... -> GAME_OVER
## The game never touches the UI directly. Instead it emits the signals below and the
## table listens to them and updates the screen.

# --- Signals: how the rules tell the outside world what happened ---
signal changed                              # anything on the table changed
signal log_message(text: String)            # public event, everyone sees it
signal private_info(text: String)           # only the human should see this
signal pair_made(player_index: int, card_a: BlandCard, card_b: BlandCard)
signal turn_ended(player_index: int)
signal joker_received(player_index: int)
signal turn_started(player_index: int)
signal turn_continued(player_index: int)                 # made a pair, so the same player goes again
signal special_drawn(player_index: int, card: BlandCard) # drew a special: may play it right away
signal player_finished(player_index: int)                # emptied their hand: safe for the rest of the round
signal affected(target: int, actor: int, text: String)   # someone's move hit `target` (used for pop-up alerts)
signal round_over(summary: Array)           # Array of Dictionaries, one per player
signal game_over(standings: Array)          # players sorted by score

## The phase says what the game is waiting for right now. The table and the bots both
## check it to know which actions are currently legal.
## IDLE / ARRANGE - before play starts / players are ordering their hands
## PLAY_OR_DRAW  - current player may draw, or play a special from their hand
## SPECIAL_DRAWN - they just drew a special: play it now, or keep it (ends the turn)
## VISION_DECIDE - they peeked with Vision and must take or leave the card
## ROUND_OVER / GAME_OVER - the round / the whole game has finished
enum Phase { IDLE, ARRANGE, PLAY_OR_DRAW, SPECIAL_DRAWN, VISION_DECIDE, ROUND_OVER, GAME_OVER }

# Hard cap on turns (and extra "go again" actions) so a bug can never freeze the game in an endless loop.
const SAFETY_TURN_LIMIT := 2000   # ends a round if something loops forever

#------------------------------------------------------------------------ funcs
var total_rounds: int = 5 # Total rounds picked on the main menu, and which round we are on (1-based once started).
var _rng := RandomNumberGenerator.new() # Our own random number generator (instead of the global one) used for shuffling.
var players: Array[BlandPlayer] = [] # --- Game state ---

# Creates the four seats. Seat 0 is the human ("You"); the rest are bots. The round count is
# clamped to the allowed range so a bad value can't break the Joker schedule.
	#@param p_total_round -> int value that represents total rounds being played, Array -> array of players and bots
	#@return void
func _init(p_total_rounds: int = 5, names: Array = ["You", "CPU 1", "CPU 2", "CPU 3"]) -> void: #LEAN
	total_rounds = clampi(p_total_rounds, GameSettings.MIN_ROUNDS, GameSettings.MAX_ROUNDS)
	_rng.randomize()
	for i in GameSettings.NUM_PLAYERS: #const value from 0 - 3 (both values are inclusive)
		players.append(BlandPlayer.new(i, names[i], i == 0))

var round_number: int = 0
var jokers_this_round: int = 1 #Jokers shuffled into this round's deck (grows with the round, see GameSettings.JOKER_SCHEDULE).
var direction: int = 1 # 1 = clockwise, -1 = counter-clockwise
var skip_pending = false # True once someone plays Skip. The skip is applied in _end_turn() to whoever would have played next.
var turns_this_round: int = 0
var discard_pile: Array[BlandCard] = [] #Every pair card that has been matched and removed from play, plus every special that has been played.
var last_peek: Dictionary = {} #{player, target, index, card} from Vision this turn remembered by Vision so the player (or bot) can then take or leave the card they saw.
var _round_starter: int = 0 #Which seat deals/starts the round. It rotates one seat each round so nobody always goes first.
var phase: Phase = Phase.IDLE
var current: int = 0

# Sets up and deals a new round: resets everyone, builds and shuffles the deck, deals it
# out one card at a time round the table, then discards any pairs players were dealt.
# If that already finishes the round the game moves straight on; otherwise it waits in ARRANGE.
	#@param none
	#@return void
func start_round() -> void:
	round_number += 1
	jokers_this_round = GameSettings.jokers_for_round(total_rounds, round_number)
	direction = 1 	# Every round starts clockwise, with no pending Skip.
	skip_pending = false
	turns_this_round = 0
	discard_pile.clear()
	last_peek = {}
	for p in players:
		p.reset_for_round()
	var deck := _build_deck(jokers_this_round)
	_shuffle(deck)
	# Dealing starts from the round's starter and goes round the table, so everyone ends up with
	# (almost) the same number of cards. The remainder goes to the first seats dealt to.
	var seat := _round_starter
	for card in deck:
		players[seat].hand.append(card)
		seat = (seat + 1) % players.size()

	_log("[b]Round %d of %d[/b] — %d cards dealt, %d Joker%s in the deck." % [
		round_number, total_rounds, deck.size(), jokers_this_round,
		"" if jokers_this_round == 1 else "s"])
	
	for p in players:
		_discard_starting_pairs(p) #hands stay in their random dealt order
	
	_update_finished()
	# Advance the starter for next round now, after this round's first player has been recorded in `current`.
	current = _round_starter
	_round_starter = (_round_starter + 1) % players.size()
	if _is_round_complete():
		changed.emit() #signal
		_finish_round()
		return
	# (An unlucky deal could pair everything off immediately, in which case there is no game to play.)
	# Before play starts, players may arrange their hands. Once play begins the order is locked.
	phase = Phase.ARRANGE
	_log("Arrange your hand, then start the round. After that, card order is locked.")
	changed.emit() #signal	

## Move a card within a hand. Only allowed during the ARRANGE phase.
## Used by the drag-to-reorder UI; returns whether the move was legal (valid indexes, different slots).
	#@param p -> int num of players, from -> int intial position, to -> int final position
	#@return boolean
func move_card(p: int, from: int, to: int) -> bool:
	var hand := players[p].hand
	if phase != Phase.ARRANGE or from < 0 or from >= hand.size() or to < 0 or to >= hand.size() or from == to:
		return false
	# Taking the card out first and inserting it at `to` gives the same result as dragging it there.
	var card := hand[from] #local variable
	hand.remove_at(from)
	hand.insert(to, card)
	changed.emit() #signal
	return true

# Randomize a hand again (ARRANGE phase only).
	#@param p -> int num of players
	#@return void
func shuffle_hand(p: int) -> void:
	if phase != Phase.ARRANGE:
		return
	_shuffle(players[p].hand)
	changed.emit() #signal

# Locks every hand's order and starts the first turn of the round.
	# @param none
	# @return void
func finish_arranging() -> void:
	if phase != Phase.ARRANGE:
		return
	_log("Hands are locked. Play begins!")
	_begin_turn()

# compares players score
	# @param a -> BlandPlayer a player b -> BlandPlayer a player
	# @return boolean
func player_score(a: BlandPlayer, b: BlandPlayer) -> bool: 
	return a.total_score > b.total_score #total_score is defined in the bland_player scipt
	
# Call after round_over to continue (or to end the game).
# If that was the last round, the players are sorted by total score (highest first) and game_over is emitted.
	# @param none
	# @return void
func next_round() -> void:
	if round_number >= total_rounds:
		phase = Phase.GAME_OVER
		var standings := players.duplicate()
		standings.sort_custom(player_score) #-> bool means it is returning a boolean type + edited to not create the function in the function
		changed.emit() #signal
		game_over.emit(standings) #signal
	else:
		start_round()


# Builds an unshuffled deck: 40 pair cards (every rank in every suit), then the special cards
# (counts come from GameSettings.special_counts), then this round's Jokers.
	#@param jokers -> int the number of jokers
	#@return BlandCard -> Array of all of the game cards from bland_card script
func _build_deck(jokers: int) -> Array[BlandCard]:
	var deck: Array[BlandCard] = []
	for r in GameSettings.PAIR_RANKS:
		for s in BlandCard.SUITS:
			deck.append(BlandCard.make_pair(r, s))
	for sc in GameSettings.special_counts:
		for i in GameSettings.special_counts[sc]:
			deck.append(BlandCard.make_special(sc))
	for i in jokers:
		deck.append(BlandCard.make_joker())
	return deck

# Removes every pair a player was dealt. After one pair is removed the hand has changed, so the
# loop starts scanning again (`found` flag) until no matching cards remain. Handles a hand that holds all four of one rank.
	#@param p -> BlandPlayer type from bland_player script
	#@return void
func _discard_starting_pairs(p: BlandPlayer) -> void:
	var found := true
	while found:
		found = false
		for a in p.hand:
			var b := p.find_match_for(a)
			if b != null:
				_discard_pair(p, a, b)
				found = true
				break

# Moves a matched pair out of the hand into the discard pile and records its points immediately.
	#@param p -> BlandPlayer, a -> BlandCard (an object that represents a card in a pair), b -> BlandCard((an object that represents a card in a pair)
	#@return void
func _discard_pair(p: BlandPlayer, a: BlandCard, b: BlandCard) -> void:
	p.hand.erase(a)
	p.hand.erase(b)
	discard_pile.append(a)
	discard_pile.append(b)
	p.round_pairs += 1
	p.total_score += GameSettings.POINTS_PER_PAIR
	p.paired_ranks.append(a.rank)
	p.paired_cards.append([a, b])

# The round is over when no pair cards are left in anyone's hand. Only Jokers (and specials) may remain.
	#@param none
	#@return boolean
func _is_round_complete() -> bool:
	for p in players:
		if p.pair_card_count() > 0:
			return false
	return true

# Ends the round and works out the scores: +1 point per pair, minus 4 per Joker still held.
# Builds a summary (one entry per player) that the table shows on the round-over screen.
	#@param none
	#@return void
func _finish_round() -> void:
	phase = Phase.ROUND_OVER
	var summary: Array = []
	for p in players:
		var jokers := p.joker_count()
		p.round_penalty = jokers * GameSettings.JOKER_PENALTY
		var gained := p.round_pairs * GameSettings.POINTS_PER_PAIR - p.round_penalty
		p.total_score -= p.round_penalty
		summary.append({
			"name": p.display_name, "pairs": p.round_pairs, "jokers": jokers,
			"penalty": p.round_penalty, "round_points": gained, "total": p.total_score,
		})
		if jokers > 0:
			_log("[color=#ff7070]%s is stuck with %d Joker%s: -%d points.[/color]" % [ # [/color] 
				p.display_name, jokers, "" if jokers == 1 else "s", p.round_penalty])
	_log("[b]Round %d over.[/b]" % round_number) #[/b]
	changed.emit() #signal
	round_over.emit(summary) #signal

# ---------------------------------------------------------------- turns
var draw_only: bool = false # after Skip/Reverse: you still draw, but can't play another special
var drawn_special: BlandCard = null # the special just drawn (SPECIAL_DRAWN phase)
var actions_this_turn: int = 0            # how many times the current player has gone again

# Starts the current player's turn. First, skip over players who can't act: anyone with an empty
# hand, and anyone who is frozen (each skipped turn uses up one of their frozen turns).
# `guard` stops the loop if every player were somehow unable to play.
	# @param none
	# @return void
func _begin_turn() -> void:
	# Skip anyone with no cards or who is frozen.
	var guard := 0
	while guard < 64:
		guard += 1
		var p := players[current]
		if p.hand.is_empty():
			current = _step(current)
			continue
		if p.frozen_turns > 0:
			p.frozen_turns -= 1
			_log("%s is frozen and misses this turn (%d left)." % [p.display_name, p.frozen_turns])
			current = _step(current)
			continue
		break

	# Count the turn, and bail out if the safety limit was passed.
	turns_this_round += 1
	if turns_this_round > SAFETY_TURN_LIMIT:
		_log("Turn limit reached, ending the round.")
		_finish_round()
		return

	# Reset the per-turn state, then wait for the player (or bot) to draw or play a special.
	drawn_special = null
	actions_this_turn = 0
	draw_only = false
	last_peek = {}
	phase = Phase.PLAY_OR_DRAW
	changed.emit()
	turn_started.emit(current)

var _skip_actor: int = -1

# Finishes the current player's turn. Checks whether anyone just ran out of cards or the round
# is over, then hands over to the next player who still has cards. A pending Skip is applied here:
# that player's turn is skipped and the one after them plays instead.
	# @param none
	# @return void
func _end_turn() -> void:
	turn_ended.emit(current)
	_update_finished()
	if _is_round_complete():
		_finish_round()
		return
	current = _next_with_cards(current)
	if skip_pending:
		skip_pending = false
		affected.emit(current, _skip_actor, "%s played Skip — you lose your turn!" % _n(_skip_actor))
		_log("%s is skipped!" % players[current].display_name)
		current = _next_with_cards(current)
	_begin_turn()

# One seat forward in the current direction. posmod makes the seat number wrap around
# correctly even when going backwards (a plain % can return a negative number in GDScript).
	# @param from -> int increments direction
	# @void int
func _step(from: int) -> int:
	return posmod(from + direction, players.size()) #posmod returns the integer mod of x divided by y that wraps equally in positive and negative.

# Who will play after the current player (for the turn indicator). -1 outside play.
# This takes a pending Skip into account, so the compass arrows point to the right player.
	# @param none
	# @return int
func upcoming_player() -> int:
	if phase == Phase.ARRANGE:
		return current
	if phase == Phase.ROUND_OVER or phase == Phase.GAME_OVER or phase == Phase.IDLE:
		return -1
	var n := _next_with_cards(current)
	if skip_pending:
		n = _next_with_cards(n)
	return n

# Next seat (in the current direction) that still holds cards.
# Players with empty hands are out for the round, so they are skipped over.
	# @param from -> int 
	# @return int
func _next_with_cards(from: int) -> int:
	var idx := from #idx is a dynamic variable in the fn
	for i in players.size():
		idx = _step(idx)
		if not players[idx].hand.is_empty():
			return idx
	return _step(from)

# Players that `p` may draw from: any other player who still has cards.
	# @param p -> int num of players
	# @return Array[int]
func draw_targets(p: int) -> Array[int]:
	var out: Array[int] = []
	for i in players.size():
		if i != p and not players[i].hand.is_empty():
			out.append(i)
	return out

# Small permission checks used by the UI (to enable/disable buttons) and by the bots:
# can_draw_from - is `src` a legal player to draw from?
	# @param p -> int, src -> int
	# @return boolean
func can_draw_from(p: int, src: int) -> bool:
	return draw_targets(p).has(src)

#   is_turn_of - is it `p`'s turn and are they free to act (not in the middle of a Vision peek)?
	# @param p -> int
	# @retun boolean
func is_turn_of(p: int) -> bool:
	return current == p and (phase == Phase.PLAY_OR_DRAW or phase == Phase.SPECIAL_DRAWN)

#   can_draw - may `p` draw a card right now?
	# @param p -> int
	# @return boolean
func can_draw(p: int) -> bool:
	return current == p and phase == Phase.PLAY_OR_DRAW

# May `p` play a special at all right now? Not after Skip/Reverse (draw_only), when they must draw first.
	# @param p -> int
	# @return boolean
func can_play_specials(p: int) -> bool:
	if phase == Phase.PLAY_OR_DRAW and draw_only:
		return false
	return is_turn_of(p)

# Whether this particular special card can be played right now.
# Also rejects specials that would have nobody to target (e.g. Give with only one card in hand).
	# @param p -> int, card -> BlandCard
	# @return boolean
func can_play(p: int, card: BlandCard) -> bool:
	if not can_play_specials(p) or not card.is_special() or not players[p].hand.has(card):
		return false
	if phase == Phase.SPECIAL_DRAWN and card != drawn_special:
		return false   # right after drawing a special, only that card can be played
	match card.special:
		BlandCard.Special.GIVE:
			return players[p].hand.size() >= 2 and not valid_targets(p, card).is_empty()
		BlandCard.Special.ANGEL, BlandCard.Special.VISION, BlandCard.Special.FREEZE:
			return not valid_targets(p, card).is_empty()
	return true

# Players that a special card can target.
# Excludes yourself and anyone who is out of cards, since they are safe for the rest of the round.
	# @param p -> int
	# @return Array[int]
func valid_targets(p: int, card: BlandCard) -> Array[int]:
	var out: Array[int] = []
	for i in players.size():
		if i == p or players[i].finished or players[i].hand.is_empty():
			continue   # players who are out of cards are safe and can't be targeted
		out.append(i)
	return out

# Each play_* function follows the same pattern: _consume() checks the play is legal and moves the
# card to the discard pile, then the effect is applied, messages are logged / sent to the UI,
# and finally the turn either continues (_draw_after_special) or ends (_after_action).

# ---------------------------------------------------------------- special cards
# Skip: the next player loses their turn (applied later in _end_turn). The player still draws a card.
	# @param p -> int, card -> BlandCard
	# @return void
func play_skip(p: int, card: BlandCard) -> void:
	if not _consume(p, card, BlandCard.Special.SKIP):
		return
	skip_pending = true
	_skip_actor = p
	_log("%s plays [b]Skip[/b] — the next player loses their turn." % _n(p))
	_draw_after_special()   # Skip and Reverse still let you take a card

# Reverse: flips the direction of play. The player still draws a card. Everyone else is notified.
	# @param p -> int, card -> BlandCard
	# @return void
func play_reverse(p: int, card: BlandCard) -> void:
	if not _consume(p, card, BlandCard.Special.REVERSE):
		return
	direction *= -1
	var dir_text := "clockwise" if direction == 1 else "counter-clockwise"
	_log("%s plays [b]Reverse[/b] — play now goes %s." % [_n(p), dir_text])
	for i in players.size():
		if i != p:
			affected.emit(i, p, "%s played Reverse — play now goes %s." % [_n(p), dir_text])
	_draw_after_special()

# Freeze: the target will miss their next FREEZE_TURNS turns (counted down in _begin_turn).
	# @param p -> int
	# @return void
func play_freeze(p: int, card: BlandCard, target: int) -> void:
	# Reject a self-target, or a play that isn't legal; _consume() also removes the card from the hand.
	if target == p or not _consume(p, card, BlandCard.Special.FREEZE):
		return
	players[target].frozen_turns += GameSettings.FREEZE_TURNS
	_log("%s plays [b]Freeze[/b] on %s (misses %d turns)." % [_n(p), _n(target), GameSettings.FREEZE_TURNS])
	affected.emit(target, p, "%s froze you! You miss your next %d turns." % [_n(p), GameSettings.FREEZE_TURNS])
	# `false` = the special itself is not a pair, so the turn ends.
	_after_action(false)

# Returns true if the target holds a Joker. Only the player who used it learns the answer.
	# @param p -> int, card -> BlandCard, target -> int
	# @return boolean
func play_angel(p: int, card: BlandCard, target: int) -> bool:
	if target == p or not _consume(p, card, BlandCard.Special.ANGEL):
		return false
	# Only the human sees the answer (private_info); bots just receive the return value.
	var has := players[target].has_joker()
	_log("%s plays [b]Angel[/b] on %s." % [_n(p), _n(target)])
	affected.emit(target, p, "%s used Angel to check whether you have a Joker." % _n(p))
	if players[p].is_human:
		private_info.emit("Angel: %s %s a Joker." % [_n(target), "HAS" if has else "does NOT have"])
	_after_action(false)
	return has

# Give: hand one card (`gift`) to another player. Can't give the Give card itself, and the gift
# must actually be in the giver's hand. Giving a Joker away is allowed (it is the main use).
	# @param p -> int, card -> BlandCard, gift -> BlandCard, target -> int
	# @return void
func play_give(p: int, card: BlandCard, gift: BlandCard, target: int) -> void:
	if target == p or gift == card or not players[p].hand.has(gift):
		return
	if not _consume(p, card, BlandCard.Special.GIVE):
		return
	players[p].hand.erase(gift)
	players[target].hand.append(gift)
	if gift.is_joker():
		joker_received.emit(target)
	_log("%s plays [b]Give[/b] and hands a card to %s." % [_n(p), _n(target)])
	if players[p].is_human:
		private_info.emit("You gave your %s to %s." % [gift.display_name(), _n(target)])
	elif players[target].is_human:
		private_info.emit("%s gave you the %s." % [_n(p), gift.display_name()])
	affected.emit(target, p, "%s gave you the %s!" % [_n(p), gift.display_name()])
	# The receiver might complete a pair with the gift.
	_check_new_pair(target, gift)   # the gift was added at the END of their hand
	_after_action(false)            # a pair made by the receiver doesn't extend YOUR turn

# Peek at one card. Phase becomes VISION_DECIDE until resolve_vision() is called.
# `index` is the card's position in the target's hand (the numbers under their cards).
	# @param
	# @return
func play_vision(p: int, card: BlandCard, target: int, index: int) -> BlandCard:
	if target == p or index < 0 or index >= players[target].hand.size():
		return null
	if not _consume(p, card, BlandCard.Special.VISION):
		return null
	var seen := players[target].hand[index]
	last_peek = {"player": p, "target": target, "index": index, "card": seen}
	_log("%s plays [b]Vision[/b] and peeks at card #%d in %s's hand." % [_n(p), index + 1, _n(target)])
	affected.emit(target, p, "%s used Vision to peek at card #%d in your hand." % [_n(p), index + 1])
	phase = Phase.VISION_DECIDE
	changed.emit()
	return seen

# take = true: take the peeked card. If it makes a pair you keep going, otherwise your turn ends.
# take = false: leave it. Vision was used without making a pair, so your turn ends.
	# @param
	# @return
func resolve_vision(take: bool) -> void:
	if phase != Phase.VISION_DECIDE or last_peek.is_empty():
		return
	if take:
		_log("%s takes the card." % _n(current))
		_take_card(current, last_peek["target"], last_peek["index"], true)
	else:
		_log("%s leaves the card where it is." % _n(current))
		_after_action(false)

# Plays the card: only if allowed and it is the right kind of special. Then it is
# removed from the hand and placed on the discard pile. Every play_* function starts with this.
	# @param
	# @return
func _consume(p: int, card: BlandCard, expected: BlandCard.Special) -> bool:
	if not can_play(p, card) or card.special != expected:
		return false
	players[p].hand.erase(card)
	discard_pile.append(card)
	drawn_special = null
	return true

# Keep the special you just drew without playing it. Ends your turn.
	# @param
	# @return
func pass_turn(p: int) -> void:
	if current != p or phase != Phase.SPECIAL_DRAWN:
		return
	_log("%s keeps the card for later." % _n(p))
	_after_action(false)

# After Skip or Reverse the player still takes a card (but can't play another special first).
# draw_only enforces that. If nobody can be drawn from, the turn just ends.
	# @param
	# @return
func _draw_after_special() -> void:
	_update_finished()
	if _is_round_complete():
		_finish_round()
		return
	if players[current].finished or draw_targets(current).is_empty():
		_end_turn()
		return
	draw_only = true
	phase = Phase.PLAY_OR_DRAW
	changed.emit()

# Called after every draw / special. Making a pair = go again. Anything else ends the turn.
# Going again is only allowed if the player still has cards and someone to draw from.
	# @param
	# @return
func _after_action(made_pair: bool) -> void:
	_update_finished()
	if _is_round_complete():
		_finish_round()
		return
	drawn_special = null
	last_peek = {}
	var me := players[current]
	if made_pair and not me.finished and not draw_targets(current).is_empty() \
			and actions_this_turn < SAFETY_TURN_LIMIT:
		actions_this_turn += 1
		draw_only = false
		phase = Phase.PLAY_OR_DRAW
		_log("%s made a pair and %s again!" % [_n(current), "go" if me.is_human else "goes"])
		changed.emit()
		turn_continued.emit(current)
		return
	_end_turn()
# ---------------------------------------------------------------- drawing
# Draw the card at `index` from player `src`'s hand.
# The drawer may pick ANY other player who still has cards.
# Pair -> go again. Drew a special -> may play it now. Otherwise the turn ends.
	# @param
	# @return
func draw_card(p: int, src: int, index: int) -> void:
	if not can_draw(p):
		return
	if draw_targets(p).is_empty():
		_end_turn()
		return
	if not can_draw_from(p, src) or index < 0 or index >= players[src].hand.size():
		return
	_take_card(p, src, index)

# Does the actual card transfer: remove from `src`, append to the end of `p`'s hand, log and
# notify (private_info tells the human exactly which card moved), then check for a pair.
# If the card is a special that can be played, wait in SPECIAL_DRAWN so the player may use it
# right away. A card taken through Vision never triggers that: the Vision turn ends instead.
	# @param
	# @return
func _take_card(p: int, src: int, index: int, via_vision: bool = false) -> void:
	var card := players[src].hand[index]
	players[src].hand.remove_at(index)
	players[p].hand.append(card)
	if card.is_joker():
		joker_received.emit(p)
	_log("%s draws a card from %s." % [_n(p), _n(src)])
	if players[p].is_human:
		private_info.emit("You drew the %s." % card.display_name())
	elif players[src].is_human:
		private_info.emit("%s took your %s." % [_n(p), card.display_name()])
	affected.emit(src, p, "%s took your %s!" % [_n(p), card.display_name()])
	var paired := _check_new_pair(p, card)   # the new card was added at the END of the hand
	if card.is_special() and not via_vision:
		drawn_special = card
		phase = Phase.SPECIAL_DRAWN
		if can_play(p, card):
			if players[p].is_human:
				private_info.emit("You drew %s — you can play it right now." % card.special_name())
			changed.emit()
			special_drawn.emit(p, card)
			return
	_after_action(paired)

# If the new card matches something in the hand, discard the pair. Returns true if a pair was made.
	# @param
	# @return
func _check_new_pair(p: int, card: BlandCard) -> bool:
	var other := players[p].find_match_for(card)
	if other != null:
		_discard_pair(players[p], card, other)
		pair_made.emit(p, card, other)
		return true
	return false

# ---------------------------------------------------------------- helpers

# Fisher-Yates shuffle: walk backwards, swapping each card with a random earlier one.
# This gives every ordering an equal chance, unlike naive shuffles.
	# @param
	# @return
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# Anyone whose hand just became empty is out for the round: safe from the Joker, and
# they can never receive cards again this round (no draws, no Give, no turns).
	# @param
	# @return
func _update_finished() -> void:
	for pl in players:
		if not pl.finished and pl.hand.is_empty():
			pl.finished = true
			pl.frozen_turns = 0
			_log("[color=#8fe08f]%s %s out of cards and safe from the Joker![/color]" % [
				pl.display_name, "are" if pl.is_human else "is"])
			player_finished.emit(pl.index)

# Text helpers: _poss gives "your" / "Bot 1's"; _n gives a player's name.
	# @param
	# @return
func _poss(p: int) -> String:
	return "your" if players[p].is_human else _n(p) + "'s"
	
	# @param
	# @return
func _n(p: int) -> String:
	return players[p].display_name

# All log lines go through here so the "You" grammar is fixed in one place.
	# @param
	# @return
func _log(text: String) -> void:
	log_message.emit(_you_grammar(text))

# "You plays Skip" -> "You play Skip" (the human is called "You" in the log).
# Messages are written as if the subject were a third person, then corrected here.
	# @param
	# @return
static func _you_grammar(text: String) -> String:
	for verb in ["plays", "draws", "makes", "starts", "takes", "leaves", "gives"]:
		text = text.replace("You " + verb, "You " + verb.trim_suffix("s"))
	text = text.replace("You is ", "You are ")
	return text

# For the card tracker: how many of each rank have been paired (0, 2 or 4 of the 4 cards).
	# @param
	# @return
func paired_count_by_rank() -> Dictionary:
	var out := {}
	for r in GameSettings.PAIR_RANKS:
		out[r] = 0
	for p in players:
		for r in p.paired_ranks:
			out[r] += 2
	return out

# Number of pairs still to be made (each pair needs two cards, hence the division by 2).
	# @param
	# @return
func pairs_left() -> int:
	var n := 0
	for p in players:
		n += p.pair_card_count()
	return n / 2
