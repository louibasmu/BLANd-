class_name BotBrain
extends RefCounted
## Bot decision making. Two styles for now (picked on the main menu):
##   RANDOM - every choice is a coin flip (answers "should bots be random?")
##   BASIC  - a few simple rules of thumb (a starting point for smarter bots)
## A turn is a series of steps (the table pauses between them). step() picks the
## right decision for the current phase:
##   PLAY_OR_DRAW  -> maybe play a special from hand, otherwise draw
##   SPECIAL_DRAWN -> play the special just drawn, or keep it (ends the turn)
##   VISION_DECIDE -> take or leave the peeked card
## Making a pair puts the bot back in PLAY_OR_DRAW, so it simply steps again.


static func try_play_special(game: BlandGame, p: int, style: int) -> String:
	if not game.can_play_specials(p):
		return "none"
	var me := game.players[p]
	var playable: Array[BlandCard] = []
	for c in me.specials():
		if game.can_play(p, c):
			playable.append(c)
	if playable.is_empty():
		return "none"

	var plan: Dictionary
	if style == GameSettings.BotStyle.RANDOM:
		plan = _random_plan(game, p, playable)
	else:
		plan = _basic_plan(game, p, playable)
	if plan.is_empty():
		return "none"
	return _execute(game, p, plan)


## Called after a Vision peek. Returns whether the bot took the card.
static func decide_vision(game: BlandGame, p: int, style: int) -> bool:
	if game.last_peek.is_empty():
		return false
	var seen: BlandCard = game.last_peek["card"]
	var take: bool
	if style == GameSettings.BotStyle.RANDOM:
		take = randf() < 0.5
	else:
		take = not seen.is_joker()
	game.resolve_vision(take)
	return take


## Picks who to draw from and which card. Returns {"src", "index"} or {} if nobody has cards.
static func choose_draw(game: BlandGame, p: int, style: int) -> Dictionary:
	var targets := game.draw_targets(p)
	if targets.is_empty():
		return {}
	var src: int = targets.pick_random()
	var idx := randi() % game.players[src].hand.size()
	if style == GameSettings.BotStyle.BASIC and not game.last_peek.is_empty():
		var peek_src: int = game.last_peek["target"]
		var peek_i: int = game.last_peek["index"]
		var seen: BlandCard = game.last_peek["card"]
		if targets.has(peek_src):
			if game.players[p].find_match_for(seen) != null:
				return {"src": peek_src, "index": peek_i}   # grab the card we know makes a pair
			if seen.is_joker():
				# Avoid the Joker we just saw: draw from someone else, or a different card.
				var others := targets.filter(func(t: int) -> bool: return t != peek_src)
				if not others.is_empty():
					src = others.pick_random()
					idx = randi() % game.players[src].hand.size()
				elif game.players[src].hand.size() > 1:
					while idx == peek_i:
						idx = randi() % game.players[src].hand.size()
	return {"src": src, "index": idx}


static func draw(game: BlandGame, p: int, style: int) -> void:
	var pick := choose_draw(game, p, style)
	if pick.is_empty():
		game.draw_card(p, -1, -1)   # nobody to draw from: the game ends the turn
		return
	game.draw_card(p, pick["src"], pick["index"])


## Plays a whole turn instantly (used by tools/simulate.gd).
static func play_full_turn(game: BlandGame, p: int, style: int) -> void:
	var guard := 0
	while guard < 100 and game.current == p and is_acting(game, p):
		guard += 1
		step(game, p, style)


static func is_acting(game: BlandGame, p: int) -> bool:
	return game.current == p and (game.is_turn_of(p) or game.phase == BlandGame.Phase.VISION_DECIDE)


## One decision. (The table splits PLAY_OR_DRAW draws into aim + take so the
## player can see which card is about to be taken; see game_table.gd.)
static func step(game: BlandGame, p: int, style: int) -> void:
	match game.phase:
		BlandGame.Phase.VISION_DECIDE:
			decide_vision(game, p, style)
		BlandGame.Phase.SPECIAL_DRAWN:
			if try_play_special(game, p, style) == "none":
				game.pass_turn(p)
		BlandGame.Phase.PLAY_OR_DRAW:
			if try_play_special(game, p, style) == "none":
				draw(game, p, style)


# ---------------------------------------------------------------- planning

static func _random_plan(game: BlandGame, p: int, playable: Array[BlandCard]) -> Dictionary:
	if randf() < (0.5 if game.phase == BlandGame.Phase.SPECIAL_DRAWN else 0.3):
		return {}
	var card: BlandCard = playable.pick_random()
	var targets := game.valid_targets(p, card)
	var plan := {"card": card, "target": targets.pick_random() if not targets.is_empty() else -1}
	if card.special == BlandCard.Special.GIVE:
		plan["gift"] = _random_other_card(game.players[p], card)
	return plan


static func _basic_plan(game: BlandGame, p: int, playable: Array[BlandCard]) -> Dictionary:
	var me := game.players[p]
	var by_type := {}
	for c in playable:
		by_type[c.special] = c

	# Holding a Joker? Give it away to whoever is winning.
	if by_type.has(BlandCard.Special.GIVE):
		for c in me.hand:
			if c.is_joker():
				var give_to := _leader(game, game.valid_targets(p, by_type[BlandCard.Special.GIVE]))
				if give_to >= 0:
					return {"card": by_type[BlandCard.Special.GIVE], "gift": c, "target": give_to}

	var targets := game.draw_targets(p)
	var src: int = targets.pick_random() if not targets.is_empty() else -1
	if by_type.has(BlandCard.Special.VISION) and src != -1 and randf() < 0.6:
		return {"card": by_type[BlandCard.Special.VISION], "target": src}
	if by_type.has(BlandCard.Special.FREEZE) and randf() < 0.35:
		var freeze_who := _leader(game, game.valid_targets(p, by_type[BlandCard.Special.FREEZE]))
		if freeze_who >= 0:
			return {"card": by_type[BlandCard.Special.FREEZE], "target": freeze_who}
	if by_type.has(BlandCard.Special.ANGEL) and src != -1 and randf() < 0.25:
		return {"card": by_type[BlandCard.Special.ANGEL], "target": src}
	if by_type.has(BlandCard.Special.SKIP) and randf() < 0.3:
		return {"card": by_type[BlandCard.Special.SKIP]}
	if by_type.has(BlandCard.Special.REVERSE) and randf() < 0.2:
		return {"card": by_type[BlandCard.Special.REVERSE]}
	return {}


static func _execute(game: BlandGame, p: int, plan: Dictionary) -> String:
	var card: BlandCard = plan["card"]
	var target: int = plan.get("target", -1)
	match card.special:
		BlandCard.Special.SKIP:
			game.play_skip(p, card)
		BlandCard.Special.REVERSE:
			game.play_reverse(p, card)
		BlandCard.Special.FREEZE:
			game.play_freeze(p, card, target)
		BlandCard.Special.ANGEL:
			game.play_angel(p, card, target)
		BlandCard.Special.GIVE:
			var gift: BlandCard = plan.get("gift", null)
			if gift == null:
				return "none"
			game.play_give(p, card, gift, target)
		BlandCard.Special.VISION:
			var n := game.players[target].hand.size()
			if game.play_vision(p, card, target, randi() % n) != null:
				return "vision"
			return "none"
	return "played"


static func _random_other_card(me: BlandPlayer, exclude: BlandCard) -> BlandCard:
	var options: Array[BlandCard] = []
	for c in me.hand:
		if c != exclude:
			options.append(c)
	return null if options.is_empty() else options.pick_random()


## Highest-scoring player among `candidates` (ties broken randomly). -1 if none.
static func _leader(game: BlandGame, candidates: Array[int]) -> int:
	var best: Array[int] = []
	var best_score := -999999
	for i in candidates:
		var pl := game.players[i]
		if pl.total_score > best_score:
			best_score = pl.total_score
			best = [pl.index]
		elif pl.total_score == best_score:
			best.append(pl.index)
	return -1 if best.is_empty() else best.pick_random()
