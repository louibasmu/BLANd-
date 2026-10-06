class_name BlandGame
extends RefCounted
## All of the rules, with no UI. The table scene and the bots both drive the
## game only through the public functions below, so the rules can be changed
## (or simulated headless, see tools/simulate.gd) without touching the UI.

signal changed                              # anything on the table changed
signal log_message(text: String)            # public event, everyone sees it
signal private_info(text: String)           # only the human should see this
signal turn_started(player_index: int)
signal turn_continued(player_index: int)                 # made a pair, so the same player goes again
signal special_drawn(player_index: int, card: BlandCard) # drew a special: may play it right away
signal player_finished(player_index: int)                # emptied their hand: safe for the rest of the round
signal affected(target: int, actor: int, text: String)   # someone's move hit `target` (used for pop-up alerts)
signal round_over(summary: Array)           # Array of Dictionaries, one per player
signal game_over(standings: Array)          # players sorted by score

## PLAY_OR_DRAW  - current player may draw, or play a special from their hand
## SPECIAL_DRAWN - they just drew a special: play it now, or keep it (ends the turn)
## VISION_DECIDE - they peeked with Vision and must take or leave the card
enum Phase { IDLE, ARRANGE, PLAY_OR_DRAW, SPECIAL_DRAWN, VISION_DECIDE, ROUND_OVER, GAME_OVER }

const SAFETY_TURN_LIMIT := 2000   # ends a round if something ever loops forever

var players: Array[BlandPlayer] = []
var total_rounds: int = 5
var round_number: int = 0
var jokers_this_round: int = 1
var current: int = 0
var direction: int = 1                     # 1 = clockwise, -1 = counter-clockwise
var skip_pending: bool = false
var _skip_actor: int = -1
var phase: Phase = Phase.IDLE
var drawn_special: BlandCard = null       # the special just drawn (SPECIAL_DRAWN phase)
var actions_this_turn: int = 0            # how many times the current player has gone again
var draw_only: bool = false               # after Skip/Reverse: you still draw, but can't play another special
var turns_this_round: int = 0
var discard_pile: Array[BlandCard] = []
var last_peek: Dictionary = {}             # {player, target, index, card} from Vision this turn
var _round_starter: int = 0
var _rng := RandomNumberGenerator.new()


func _init(p_total_rounds: int = 5, names: Array = ["You", "Bot 1", "Bot 2", "Bot 3"]) -> void:
	total_rounds = clampi(p_total_rounds, GameSettings.MIN_ROUNDS, GameSettings.MAX_ROUNDS)
	_rng.randomize()
	for i in GameSettings.NUM_PLAYERS:
		players.append(BlandPlayer.new(i, names[i], i == 0))


# ---------------------------------------------------------------- rounds

func start_round() -> void:
	round_number += 1
	jokers_this_round = GameSettings.jokers_for_round(total_rounds, round_number)
	direction = 1
	skip_pending = false
	turns_this_round = 0
	discard_pile.clear()
	last_peek = {}
	for p in players:
		p.reset_for_round()

	var deck := _build_deck(jokers_this_round)
	_shuffle(deck)
	var seat := _round_starter
	for card in deck:
		players[seat].hand.append(card)
		seat = (seat + 1) % players.size()

	_log("[b]Round %d of %d[/b] — %d cards dealt, %d Joker%s in the deck." % [
		round_number, total_rounds, deck.size(), jokers_this_round,
		"" if jokers_this_round == 1 else "s"])
	for p in players:
		_discard_starting_pairs(p)   # hands stay in their random dealt order
	_update_finished()

	current = _round_starter
	_round_starter = (_round_starter + 1) % players.size()
	if _is_round_complete():
		changed.emit()
		_finish_round()
		return
	# Before play starts, players may arrange their hands. Once play begins the order is locked.
	phase = Phase.ARRANGE
	_log("Arrange your hand, then start the round. After that, card order is locked.")
	changed.emit()


## Move a card within a hand. Only allowed during the ARRANGE phase.
func move_card(p: int, from: int, to: int) -> bool:
	var hand := players[p].hand
	if phase != Phase.ARRANGE or from < 0 or from >= hand.size() or to < 0 or to >= hand.size() or from == to:
		return false
	var card := hand[from]
	hand.remove_at(from)
	hand.insert(to, card)
	changed.emit()
	return true


## Randomize a hand again (ARRANGE phase only).
func shuffle_hand(p: int) -> void:
	if phase != Phase.ARRANGE:
		return
	_shuffle(players[p].hand)
	changed.emit()


## Locks every hand's order and starts the first turn of the round.
func finish_arranging() -> void:
	if phase != Phase.ARRANGE:
		return
	_log("Hands are locked. Play begins!")
	_begin_turn()


## Call after round_over to continue (or to end the game).
func next_round() -> void:
	if round_number >= total_rounds:
		phase = Phase.GAME_OVER
		var standings := players.duplicate()
		standings.sort_custom(func(a: BlandPlayer, b: BlandPlayer) -> bool: return a.total_score > b.total_score)
		changed.emit()
		game_over.emit(standings)
	else:
		start_round()


func _build_deck(jokers: int) -> Array[BlandCard]:
	var deck: Array[BlandCard] = []
	for r in GameSettings.PAIR_RANKS:
		for s in BlandCard.SUITS:
			deck.append(BlandCard.make_pair(r, s))
	for sp in GameSettings.special_counts:
		for i in GameSettings.special_counts[sp]:
			deck.append(BlandCard.make_special(sp))
	for i in jokers:
		deck.append(BlandCard.make_joker())
	return deck


func _discard_starting_pairs(p: BlandPlayer) -> void:
	var found := true
	var made: PackedStringArray = []
	while found:
		found = false
		for a in p.hand:
			var b := p.find_match_for(a)
			if b != null:
				_discard_pair(p, a, b)
				made.append(a.rank_plural())
				found = true
				break
	if made.size() > 0:
		_log("%s starts with %d pair%s (%s)." % [p.display_name, made.size(),
			"" if made.size() == 1 else "s", ", ".join(made)])


func _discard_pair(p: BlandPlayer, a: BlandCard, b: BlandCard) -> void:
	p.hand.erase(a)
	p.hand.erase(b)
	discard_pile.append(a)
	discard_pile.append(b)
	p.round_pairs += 1
	p.paired_ranks.append(a.rank)
	p.paired_cards.append([a, b])


func _is_round_complete() -> bool:
	for p in players:
		if p.pair_card_count() > 0:
			return false
	return true


func _finish_round() -> void:
	phase = Phase.ROUND_OVER
	var summary: Array = []
	for p in players:
		var jokers := p.joker_count()
		p.round_penalty = jokers * GameSettings.JOKER_PENALTY
		var gained := p.round_pairs * GameSettings.POINTS_PER_PAIR - p.round_penalty
		p.total_score += gained
		summary.append({
			"name": p.display_name, "pairs": p.round_pairs, "jokers": jokers,
			"penalty": p.round_penalty, "round_points": gained, "total": p.total_score,
		})
		if jokers > 0:
			_log("[color=#ff7070]%s is stuck with %d Joker%s: -%d points.[/color]" % [
				p.display_name, jokers, "" if jokers == 1 else "s", p.round_penalty])
	_log("[b]Round %d over.[/b]" % round_number)
	changed.emit()
	round_over.emit(summary)


# ---------------------------------------------------------------- turns

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

	turns_this_round += 1
	if turns_this_round > SAFETY_TURN_LIMIT:
		_log("Turn limit reached, ending the round.")
		_finish_round()
		return

	drawn_special = null
	actions_this_turn = 0
	draw_only = false
	last_peek = {}
	phase = Phase.PLAY_OR_DRAW
	changed.emit()
	turn_started.emit(current)


func _end_turn() -> void:
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


func _step(from: int) -> int:
	return posmod(from + direction, players.size())


## Who will play after the current player (for the turn indicator). -1 outside play.
func upcoming_player() -> int:
	if phase == Phase.ARRANGE:
		return current
	if phase == Phase.ROUND_OVER or phase == Phase.GAME_OVER or phase == Phase.IDLE:
		return -1
	var n := _next_with_cards(current)
	if skip_pending:
		n = _next_with_cards(n)
	return n


## Next seat (in the current direction) that still holds cards.
func _next_with_cards(from: int) -> int:
	var idx := from
	for i in players.size():
		idx = _step(idx)
		if not players[idx].hand.is_empty():
			return idx
	return _step(from)


## Players that `p` may draw from: any other player who still has cards.
func draw_targets(p: int) -> Array[int]:
	var out: Array[int] = []
	for i in players.size():
		if i != p and not players[i].hand.is_empty():
			out.append(i)
	return out


func can_draw_from(p: int, src: int) -> bool:
	return draw_targets(p).has(src)


func is_turn_of(p: int) -> bool:
	return current == p and (phase == Phase.PLAY_OR_DRAW or phase == Phase.SPECIAL_DRAWN)


func can_draw(p: int) -> bool:
	return current == p and phase == Phase.PLAY_OR_DRAW


func can_play_specials(p: int) -> bool:
	if phase == Phase.PLAY_OR_DRAW and draw_only:
		return false
	return is_turn_of(p)


## Whether this particular special card can be played right now.
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


## Players that a special card can target.
func valid_targets(p: int, card: BlandCard) -> Array[int]:
	var out: Array[int] = []
	for i in players.size():
		if i == p or players[i].finished or players[i].hand.is_empty():
			continue   # players who are out of cards are safe and can't be targeted
		out.append(i)
	return out


# ---------------------------------------------------------------- special cards

func play_skip(p: int, card: BlandCard) -> void:
	if not _consume(p, card, BlandCard.Special.SKIP):
		return
	skip_pending = true
	_skip_actor = p
	_log("%s plays [b]Skip[/b] — the next player loses their turn." % _n(p))
	_draw_after_special()   # Skip and Reverse still let you take a card


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


func play_freeze(p: int, card: BlandCard, target: int) -> void:
	if target == p or not _consume(p, card, BlandCard.Special.FREEZE):
		return
	players[target].frozen_turns += GameSettings.FREEZE_TURNS
	_log("%s plays [b]Freeze[/b] on %s (misses %d turns)." % [_n(p), _n(target), GameSettings.FREEZE_TURNS])
	affected.emit(target, p, "%s froze you! You miss your next %d turns." % [_n(p), GameSettings.FREEZE_TURNS])
	_after_action(false)


## Returns true if the target holds a Joker. Only the player who used it learns the answer.
func play_angel(p: int, card: BlandCard, target: int) -> bool:
	if target == p or not _consume(p, card, BlandCard.Special.ANGEL):
		return false
	var has := players[target].has_joker()
	_log("%s plays [b]Angel[/b] on %s." % [_n(p), _n(target)])
	affected.emit(target, p, "%s used Angel to check whether you have a Joker." % _n(p))
	if players[p].is_human:
		private_info.emit("Angel: %s %s a Joker." % [_n(target), "HAS" if has else "does NOT have"])
	_after_action(false)
	return has


func play_give(p: int, card: BlandCard, gift: BlandCard, target: int) -> void:
	if target == p or gift == card or not players[p].hand.has(gift):
		return
	if not _consume(p, card, BlandCard.Special.GIVE):
		return
	players[p].hand.erase(gift)
	players[target].hand.append(gift)
	_log("%s plays [b]Give[/b] and hands a card to %s." % [_n(p), _n(target)])
	if players[p].is_human:
		private_info.emit("You gave your %s to %s." % [gift.display_name(), _n(target)])
	elif players[target].is_human:
		private_info.emit("%s gave you the %s." % [_n(p), gift.display_name()])
	affected.emit(target, p, "%s gave you the %s!" % [_n(p), gift.display_name()])
	_check_new_pair(target, gift)   # the gift was added at the END of their hand
	_after_action(false)            # a pair made by the receiver doesn't extend YOUR turn


## Peek at one card. Phase becomes VISION_DECIDE until resolve_vision() is called.
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


## take = true: take the peeked card. If it makes a pair you keep going, otherwise your turn ends.
## take = false: leave it. Vision was used without making a pair, so your turn ends.
func resolve_vision(take: bool) -> void:
	if phase != Phase.VISION_DECIDE or last_peek.is_empty():
		return
	if take:
		_log("%s takes the card." % _n(current))
		_take_card(current, last_peek["target"], last_peek["index"], true)
	else:
		_log("%s leaves the card where it is." % _n(current))
		_after_action(false)


func _consume(p: int, card: BlandCard, expected: BlandCard.Special) -> bool:
	if not can_play(p, card) or card.special != expected:
		return false
	players[p].hand.erase(card)
	discard_pile.append(card)
	drawn_special = null
	return true


## Keep the special you just drew without playing it. Ends your turn.
func pass_turn(p: int) -> void:
	if current != p or phase != Phase.SPECIAL_DRAWN:
		return
	_log("%s keeps the card for later." % _n(p))
	_after_action(false)


## After Skip or Reverse the player still takes a card (but can't play another special first).
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


## Called after every draw / special. Making a pair = go again. Anything else ends the turn.
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

## Draw the card at `index` from player `src`'s hand.
## The drawer may pick ANY other player who still has cards.
## Pair -> go again. Drew a special -> may play it now. Otherwise the turn ends.
func draw_card(p: int, src: int, index: int) -> void:
	if not can_draw(p):
		return
	if draw_targets(p).is_empty():
		_end_turn()
		return
	if not can_draw_from(p, src) or index < 0 or index >= players[src].hand.size():
		return
	_take_card(p, src, index)


func _take_card(p: int, src: int, index: int, via_vision: bool = false) -> void:
	var card := players[src].hand[index]
	players[src].hand.remove_at(index)
	players[p].hand.append(card)
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


func _check_new_pair(p: int, card: BlandCard) -> bool:
	var other := players[p].find_match_for(card)
	if other != null:
		_discard_pair(players[p], card, other)
		_log("%s makes a pair of %s! (+%d)" % [_n(p), card.rank_plural(), GameSettings.POINTS_PER_PAIR])
		return true
	return false


# ---------------------------------------------------------------- helpers

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Anyone whose hand just became empty is out for the round: safe from the Joker, and
## they can never receive cards again this round (no draws, no Give, no turns).
func _update_finished() -> void:
	for pl in players:
		if not pl.finished and pl.hand.is_empty():
			pl.finished = true
			pl.frozen_turns = 0
			_log("[color=#8fe08f]%s %s out of cards and safe from the Joker![/color]" % [
				pl.display_name, "are" if pl.is_human else "is"])
			player_finished.emit(pl.index)


func _poss(p: int) -> String:
	return "your" if players[p].is_human else _n(p) + "'s"


func _n(p: int) -> String:
	return players[p].display_name


func _log(text: String) -> void:
	log_message.emit(_you_grammar(text))


## "You plays Skip" -> "You play Skip" (the human is called "You" in the log).
static func _you_grammar(text: String) -> String:
	for verb in ["plays", "draws", "makes", "starts", "takes", "leaves", "gives"]:
		text = text.replace("You " + verb, "You " + verb.trim_suffix("s"))
	text = text.replace("You is ", "You are ")
	return text


## For the card tracker: how many of each rank have been paired (0, 2 or 4 of the 4 cards).
func paired_count_by_rank() -> Dictionary:
	var out := {}
	for r in GameSettings.PAIR_RANKS:
		out[r] = 0
	for p in players:
		for r in p.paired_ranks:
			out[r] += 2
	return out


func pairs_left() -> int:
	var n := 0
	for p in players:
		n += p.pair_card_count()
	return n / 2
