extends SceneTree
## Plays many all-bot games with no graphics, for balancing / probability work.
## Run from the game-dev-seminar folder:
##   godot --headless -s res://BaseGame/tools/simulate.gd -- --games=500 --rounds=5 --style=basic

var total_turns := 0
var total_rounds := 0
var joker_holders := 0
var _game: BlandGame


func _on_round_over(summary: Array) -> void:
	total_rounds += 1
	total_turns += _game.turns_this_round
	for row in summary:
		if row["jokers"] > 0:
			joker_holders += 1


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

	var final_scores: Array[int] = []
	var wins := [0, 0, 0, 0]

	for g in games:
		var game := BlandGame.new(rounds)
		_game = game
		game.round_over.connect(_on_round_over)
		game.start_round()
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
		var best := -9999
		var winner := 0
		for p in game.players:
			final_scores.append(p.total_score)
			if p.total_score > best:
				best = p.total_score
				winner = p.index
		wins[winner] += 1
	_game = null

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
