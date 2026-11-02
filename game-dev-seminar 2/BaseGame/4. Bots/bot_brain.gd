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
##
## Everything here is static: BotBrain holds no state of its own. It reads the BlandGame it
## is given and acts by calling the same public functions the human's buttons call.
## `p` is always the bot's seat number and `style` is a GameSettings.BotStyle.


## Tries to play a special card from the bot's hand, if it wants to. Returns "none" if it
## played nothing (so the caller should draw or keep the card), "vision" if it peeked at a
## card (a take-or-leave decision is now pending), or "played" for any other special.
static func try_play_special(game: BlandGame, p: int, style: int) -> String:
	# Not allowed to play right now (wrong phase, or just used Skip/Reverse): do nothing.
	if not game.can_play_specials(p): 
		return "none" # If I'm not allowed to play specials right now → return "none"
	var me := game.players[p] 
	# Only consider specials that can legally be played this turn.
	var playable: Array[BlandCard] = [] # Collect my special cards that are legal to play right now (playable)
	for c in me.specials():
		if game.can_play(p, c):
			playable.append(c)
	if playable.is_empty():
		return "none" # If there are none → return "none"

	# Decide WHAT to play and on WHOM ("the plan"), then carry it out. Splitting planning
	# from doing keeps the two bot styles easy to tell apart.
	var plan: Dictionary
	# Make a plan: random style → _random_plan, otherwise → _basic_plan
	if style == GameSettings.BotStyle.RANDOM:
		plan = _random_plan(game, p, playable)
	else:
		plan = _basic_plan(game, p, playable)
	if plan.is_empty():
		return "none" # If the plan is empty → return "none"
	return _execute(game, p, plan) # Carry out the plan and return what happened


## Called after a Vision peek. Returns whether the bot took the card.
## RANDOM flips a coin. BASIC takes everything except a Joker (nobody wants the Joker).
static func decide_vision(game: BlandGame, p: int, style: int) -> bool:
	if game.last_peek.is_empty():
		return false # If no card was peeked → return false
	var seen: BlandCard = game.last_peek["card"] # seen = the peeked card
	var take: bool
	if style == GameSettings.BotStyle.RANDOM:
		take = randf() < 0.5 # If random style → take it with a 50% chance
		# randf() gives a random decimal from 0 to 1
	else:
		take = not seen.is_joker() # Otherwise → take it unless it is the Joker
	game.resolve_vision(take) # Tell the game my decision
	return take # Return whether I took it


## Picks who to draw from and which card. Returns {"src", "index"} or {} if nobody has cards.
## By default it is random; BASIC then uses what a Vision peek revealed this turn:
## grab the peeked card if it makes a pair, and steer away from it if it was the Joker.
static func choose_draw(game: BlandGame, p: int, style: int) -> Dictionary:
	# Default choice: a random opponent and a random card in their hand.
	var targets := game.draw_targets(p) # targets = opponents who still have cards
	if targets.is_empty():
		return {} # If none → return {}
	var src: int = targets.pick_random() # Pick a random opponent (src) and a random card position in their hand (idx)
	var idx := randi() % game.players[src].hand.size()
	if style == GameSettings.BotStyle.BASIC and not game.last_peek.is_empty(): # If BASIC style AND I peeked at a card this turn
		var peek_src: int = game.last_peek["target"] # If the peeked player is still a valid target
		var peek_i: int = game.last_peek["index"]
		var seen: BlandCard = game.last_peek["card"]
		if targets.has(peek_src):
			if game.players[p].find_match_for(seen) != null: # If the peeked card would make a pair with something I hold
				return {"src": peek_src, "index": peek_i}   # grab the card we know makes a pair
			if seen.is_joker(): #  If the peeked card is the Joker
				# Avoid the Joker we just saw: draw from someone else, or a different card.
				var others := targets.filter(func(t: int) -> bool: return t != peek_src)
				if not others.is_empty():  # If there is no other opponent: keep re-picking until I land on a different card
					src = others.pick_random()
					idx = randi() % game.players[src].hand.size()
				elif game.players[src].hand.size() > 1: # when hand has more than one card
					while idx == peek_i: # loop re-rolls until different card
						idx = randi() % game.players[src].hand.size()
	return {"src": src, "index": idx}


## Performs a draw using choose_draw(). If there is nobody to draw from, passing -1 lets the game end the turn.
static func draw(game: BlandGame, p: int, style: int) -> void:
	var pick := choose_draw(game, p, style)
	if pick.is_empty():
		game.draw_card(p, -1, -1)   # nobody to draw from: the game ends the turn
		return
	game.draw_card(p, pick["src"], pick["index"]) # tell the game to draw card #index from player src


## Plays a whole turn instantly (used by tools/simulate.gd).
## Keeps taking steps while it is still this bot's turn (making a pair gives it another go).
## `guard` prevents an endless loop if something goes wrong.
static func play_full_turn(game: BlandGame, p: int, style: int) -> void:
	var guard := 0 # counter - 0
	while guard < 100 and game.current == p and is_acting(game, p): # While the counter is under 100 AND it's still my turn AND the game is waiting on me
		guard += 1 # Add 1 to the counter
		step(game, p, style) # Take one step


## True while the game is waiting on this bot: either its turn to draw/play, or a Vision take-or-leave decision.
static func is_acting(game: BlandGame, p: int) -> bool:
	# True if it's my seat's turn AND (it's my turn to draw or play, OR I'm deciding on a peeked card)
	return game.current == p and (game.is_turn_of(p) or game.phase == BlandGame.Phase.VISION_DECIDE)


## One decision. (The table splits PLAY_OR_DRAW draws into aim + take so the
## player can see which card is about to be taken; see game_table.gd.)
## What it does depends on the phase: decide on a peeked card; or try to play a special
## and otherwise keep it (SPECIAL_DRAWN) / draw a card (PLAY_OR_DRAW).
static func step(game: BlandGame, p: int, style: int) -> void:
	match game.phase: # Look at the phase:
		BlandGame.Phase.VISION_DECIDE:
			decide_vision(game, p, style) # deciding on a peek     → take or leave it
		BlandGame.Phase.SPECIAL_DRAWN:
			if try_play_special(game, p, style) == "none": # just drew a special    → try to play it; if I chose not to, keep it and end my turn
				game.pass_turn(p)
		BlandGame.Phase.PLAY_OR_DRAW:
			if try_play_special(game, p, style) == "none": # start of turn          → try to play a special; if I chose not to, draw a card
				draw(game, p, style)


# ---------------------------------------------------------------- planning
# A "plan" is a Dictionary: {"card": the special to play, "target": a seat number (optional),
# "gift": the card to give away (only for Give)}. An empty Dictionary means "play nothing".

# RANDOM style: usually (70% / 50% right after drawing a special) plays something, picking a random
# playable special and a random legal target. Never uses information; good as a baseline to compare against.
static func _random_plan(game: BlandGame, p: int, playable: Array[BlandCard]) -> Dictionary:
	if randf() < (0.5 if game.phase == BlandGame.Phase.SPECIAL_DRAWN else 0.3): # if just drew a special, do nothing 50% of the time; otherwise 30% of the time
		return {}
	var card: BlandCard = playable.pick_random() # Pick a random playable special (card)
	var targets := game.valid_targets(p, card) # targets = legal targets for that card
	var plan := {"card": card, "target": targets.pick_random() if not targets.is_empty() else -1} # plan = {card, target = random target, or -1 if none}
	if card.special == BlandCard.Special.GIVE:
		plan["gift"] = _random_other_card(game.players[p], card) # If the card is Give: also pick a random other card from my hand as the gift
	return plan


# BASIC style: a handful of rules of thumb, checked in priority order. `by_type` maps each
# playable special type to a card, so we can ask "do I have a Freeze?".
#   1. Holding a Joker and a Give card -> give the Joker to whoever leads on score.
#   2. Vision (60%)  - peek at a random opponent.
#   3. Freeze (35%)  - freeze the leader.
#   4. Angel  (25%)  - check a random opponent for the Joker.
#   5. Skip   (30%)  and  6. Reverse (20%) - used occasionally.
# The percentages are just tuning numbers so bots don't spend all their specials at once.
static func _basic_plan(game: BlandGame, p: int, playable: Array[BlandCard]) -> Dictionary:
	var me := game.players[p]
	var by_type := {}
	for c in playable:
		by_type[c.special] = c

	# Holding a Joker? Give it away to whoever is winning.
	if by_type.has(BlandCard.Special.GIVE): # by_type = lookup of playable special type → card
		for c in me.hand:
			if c.is_joker(): # If I have Give AND I'm holding a Joker:
				var give_to := _leader(game, game.valid_targets(p, by_type[BlandCard.Special.GIVE])) #  give the Joker to the score leader
				if give_to >= 0:
					return {"card": by_type[BlandCard.Special.GIVE], "gift": c, "target": give_to}

	var targets := game.draw_targets(p)
	var src: int = targets.pick_random() if not targets.is_empty() else -1 #  src = random opponent (or -1 if none)
	if by_type.has(BlandCard.Special.VISION) and src != -1 and randf() < 0.6: # If I have Vision and a target exists → 60% chance: peek at src
		return {"card": by_type[BlandCard.Special.VISION], "target": src}
	if by_type.has(BlandCard.Special.FREEZE) and randf() < 0.35: #If I have Freeze → 35% chance: freeze the leader
		var freeze_who := _leader(game, game.valid_targets(p, by_type[BlandCard.Special.FREEZE]))
		if freeze_who >= 0:
			return {"card": by_type[BlandCard.Special.FREEZE], "target": freeze_who}
	if by_type.has(BlandCard.Special.ANGEL) and src != -1 and randf() < 0.25: # If I have Angel and a target exists → 25% chance: check src for the Joker
		return {"card": by_type[BlandCard.Special.ANGEL], "target": src}
	if by_type.has(BlandCard.Special.SKIP) and randf() < 0.3: #  If I have Skip → 30% chance: play it
		return {"card": by_type[BlandCard.Special.SKIP]}
	if by_type.has(BlandCard.Special.REVERSE) and randf() < 0.2: # If I have Reverse → 20% chance: play it
		return {"card": by_type[BlandCard.Special.REVERSE]}
	return {} # Otherwise → {} (do nothing)


# Carries out a plan by calling the matching play_* function. Returns "played", "vision"
# (a peek happened, so a decision is pending) or "none" (the play was impossible).
static func _execute(game: BlandGame, p: int, plan: Dictionary) -> String:
	# card = the special from the plan; target = plan's target, or -1 if missing
	var card: BlandCard = plan["card"]
	var target: int = plan.get("target", -1)
	match card.special: # Based on the card's type, call the matching game function
		BlandCard.Special.SKIP:
			game.play_skip(p, card)
		BlandCard.Special.REVERSE:
			game.play_reverse(p, card)
			# Skip / Reverse → play it
		BlandCard.Special.FREEZE:
			game.play_freeze(p, card, target)
		BlandCard.Special.ANGEL:
			game.play_angel(p, card, target)
			# Freeze / Angel → play it on the target
		BlandCard.Special.GIVE:
			var gift: BlandCard = plan.get("gift", null)
			if gift == null:
				return "none"
			game.play_give(p, card, gift, target)
			# Give   → needs a gift; if there isn't one, return "none"; otherwise give it to the target
		BlandCard.Special.VISION:
			var n := game.players[target].hand.size()
			if game.play_vision(p, card, target, randi() % n) != null:
				# Vision → peek at a random card in the target's hand; if it worked return "vision", else "none"
				return "vision"
			return "none"
	return "played"


# Picks a random card from the bot's hand other than `exclude` (so Give can't try to give itself away).
static func _random_other_card(me: BlandPlayer, exclude: BlandCard) -> BlandCard:
	var options: Array[BlandCard] = []
	for c in me.hand:
		if c != exclude: # options = every card in my hand except the one I'm excluding
			options.append(c)
	return null if options.is_empty() else options.pick_random() # If options is empty → null, Otherwise → a random one


## Highest-scoring player among `candidates` (ties broken randomly). -1 if none.
## The bots treat the score leader as the biggest threat, so Freeze and Joker gifts go there.
static func _leader(game: BlandGame, candidates: Array[int]) -> int:
	# best = empty list; best_score = a number lower than any real score
	var best: Array[int] = []
	var best_score := -999999
	for i in candidates: # For each candidate seat:
		var pl := game.players[i]
		if pl.total_score > best_score:
			best_score = pl.total_score
			best = [pl.index] # If their total score beats best_score → they become the only entry; update best_score
		elif pl.total_score == best_score: 
			best.append(pl.index) #  Else if it equals best_score → add them to the tied list
	return -1 if best.is_empty() else best.pick_random() # If nobody → return -1, otherwise returna random one from tied list 
