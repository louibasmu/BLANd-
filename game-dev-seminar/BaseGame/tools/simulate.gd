extends SceneTree
## Plays many all-bot games with no graphics, for balancing / probability work.
##
## How it works: instead of a scene, this script extends SceneTree, so Godot runs _init()
## directly and exits via quit(). It creates BlandGame objects (pure rules, no UI) and lets
## BotBrain play every seat, then prints averages. The command-line options are:
##   --games=N   how many full games to simulate (default 200)
##   --rounds=N  rounds per game (default 5)
##   --style=random|basic   which bot behaviour to use for all four seats
## Run from the game-dev-seminar folder:
##   godot --headless -s res://BaseGame/tools/simulate.gd -- --games=500 --rounds=5 --style=basic

# Totals collected across all games, filled in by _on_round_over().
var total_turns := 0
var total_rounds := 0
var joker_holders := 0
# The game currently being simulated (so the signal handler can read its turn counter).
var _game: BlandGame

# Connected to the game's round_over signal: counts the round, adds up how many turns it
# took, and counts how many players ended holding at least one Joker.
# PSEUDO:
#   FUNCTION _on_round_over(summary):
#       total_rounds = total_rounds + 1                        # one more round finished
#       total_turns  = total_turns + _game.turns_this_round    # add this round's length
#       FOR each row in summary:                               # one row per player
#           IF row.jokers > 0:                                 # player ended holding a Joker
#               joker_holders = joker_holders + 1
func _on_round_over(summary: Array) -> void:
	total_rounds += 1
	total_turns += _game.turns_this_round
	for row in summary:
		if row["jokers"] > 0:
			joker_holders += 1


# Entry point. Godot runs this automatically because the script extends SceneTree.
func _init() -> void:
	# --- Step 1: ---------------------------------------
	# PSEUDO:
	#   games = 200, rounds = 5, style = BASIC          # defaults
	#   FOR each arg in command-line user args:
	#       IF arg starts with "--games=":    games  = number after the "="
	#       ELSE IF arg starts with "--rounds=": rounds = number after the "="
	#       ELSE IF arg starts with "--style=":
	#           IF arg ends with "random": style = RANDOM
	#           ELSE:                      style = BASIC
	var games := 200
	var rounds := 5
	var style := GameSettings.BotStyle.BASIC
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.split("=")[1])
		elif arg.begins_with("--rounds="):
			rounds = int(arg.split("=")[1])
		elif arg.begins_with("--style="):
			style = GameSettings.BotStyle.RANDOM if arg.ends_with("random") else GameSettings.BotStyle.BASIC
	# --- Step 2: prepare the results  ---------------------------------------
	# final_scores collects every player's final score (for the average);
	# wins[seat] counts how many games each seat won.
	var final_scores: Array[int] = []
	var wins := [0, 0, 0, 0]
	# --- Step 3: play one full game per loop iteration -------------------------------
	for g in games:
		# PSEUDO:
		#   game = new BlandGame(rounds)
		#   _game = game
		#   CONNECT game.round_over -> _on_round_over
		#   game.start_round()
		var game := BlandGame.new(rounds)
		_game = game
		game.round_over.connect(_on_round_over)
		game.start_round()
		# `guard` is a safety net: if a bug ever stops the game from finishing, we stop after
		# 100000 steps instead of looping forever.
		# PSEUDO:
		#   guard = 0
		#   WHILE game.phase != GAME_OVER AND guard < 100000:
		#       guard = guard + 1
		#       IF phase == ROUND_OVER:  game.next_round()         # start the next round
		#       ELSE IF phase == ARRANGE: game.finish_arranging()  # skip the human's step
		#       ELSE: BotBrain plays a full turn for game.current  # a bot plays its turn
		#   IF guard >= 100000: report error "Game g did not finish!"
		var guard := 0
		while game.phase != BlandGame.Phase.GAME_OVER and guard < 100000:
			guard += 1
			if game.phase == BlandGame.Phase.ROUND_OVER:
				game.next_round()
			elif game.phase == BlandGame.Phase.ARRANGE:
				game.finish_arranging()
			else:
				BotBrain.play_full_turn(game, game.current, style)
		if guard >= 100000:
			push_error("Game %d did not finish!" % g)
		# --- Step 4: work out who won this game --------------------------------------
		# The seat with the highest total score wins (the first one wins a tie).
		# PSEUDO:
		#   best = -9999, winner = 0
		#   FOR each player p in game.players:
		#       add p.total_score to final_scores
		#       IF p.total_score > best:           # strictly greater, so ties keep the earlier seat
		#           best = p.total_score
		#           winner = p.index
		#   wins[winner] = wins[winner] + 1
		var best := -9999
		var winner := 0
		for p in game.players:
			final_scores.append(p.total_score)
			if p.total_score > best:
				best = p.total_score
				winner = p.index
		wins[winner] += 1
	# Clear the reference so the last game can be freed.
	# PSEUDO:
	#   _game = none
	_game = null

	# --- Step 5: print the summary and quit ------------------------------------------
	# "seat 0 = human" just means seat 0 is the seat the human would occupy in the
	# real game; here it is a bot like the rest.
	# PSEUDO:
	#   avg_score = sum of final_scores / max(1, count of final_scores)   # max() avoids dividing by 0
	#   PRINT "Simulated N games x R rounds (style ...)"
	#   PRINT average turns per round      = total_turns / total_rounds
	#   PRINT average Joker holders/round  = joker_holders / total_rounds
	#   PRINT average final score          = avg_score
	#   PRINT wins by seat                 = wins
	#   quit()                             # exit Godot, otherwise it keeps running
	var avg_score := 0.0
	for s in final_scores:
		avg_score += s
	avg_score /= max(1, final_scores.size())
	print("Simulated %d games x %d rounds (style %s)" % [games, rounds, "random" if style == 0 else "basic"])
	print("  average turns per round:       %.1f" % (float(total_turns) / max(1, total_rounds)))
	print("  average Joker holders / round: %.2f" % (float(joker_holders) / max(1, total_rounds)))
	print("  average final score:           %.1f" % avg_score)
	print("  wins by seat (seat 0 = human): %s" % str(wins))
	quit()
