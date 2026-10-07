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
func _on_round_over(summary: Array) -> void:
	total_rounds += 1
	total_turns += _game.turns_this_round
	for row in summary:
		if row["jokers"] > 0:
			joker_holders += 1


# Entry point. Godot runs this automatically because the script extends SceneTree.
# First read the options (anything not given keeps its default value).
func _init() -> void:
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

	# final_scores collects every player's final score (for the average);
	# wins[seat] counts how many games each seat won.
	var final_scores: Array[int] = []
	var wins := [0, 0, 0, 0]

	# Play one full game per loop iteration.
	for g in games:
		var game := BlandGame.new(rounds)
		_game = game
		game.round_over.connect(_on_round_over)
		game.start_round()
		# `guard` is a safety net: if a bug ever stops the game from finishing, we stop after
		# 100000 steps instead of looping forever.
		var guard := 0
		while game.phase != BlandGame.Phase.GAME_OVER and guard < 100000:
			# Drive the game's phases: between rounds start the next one, skip the human's
			# arranging step (no human here), otherwise let the bot whose turn it is play a full turn.
			guard += 1
			if game.phase == BlandGame.Phase.ROUND_OVER:
				game.next_round()
			elif game.phase == BlandGame.Phase.ARRANGE:
				game.finish_arranging()
			else:
				BotBrain.play_full_turn(game, game.current, style)
		if guard >= 100000:
			push_error("Game %d did not finish!" % g)
		# Work out who won: the seat with the highest total score (the first one wins a tie).
		var best := -9999
		var winner := 0
		for p in game.players:
			final_scores.append(p.total_score)
			if p.total_score > best:
				best = p.total_score
				winner = p.index
		wins[winner] += 1
	# Clear the reference so the last game can be freed.
	_game = null

	# Print the summary. "seat 0 = human" just means seat 0 is the seat the human would
	# occupy in the real game; here it is a bot like the rest.
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
