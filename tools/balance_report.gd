extends SceneTree
## Prints how bots of different speeds do on every level and player count,
## averaged over a few seeds. Used to tune spawn rates, patience and stars.
##
##   godot --headless --path . --script res://tools/balance_report.gd [-- <level id filter>]
##
## Bot speed 1.0 plays like a fast, perfectly coordinated team; real players
## are slower, so star thresholds are set well below what the 1.0 bot gets.

const SPEEDS := [0.35, 0.5, 0.7, 1.0]
const SEEDS := [1, 2, 3]


func _initialize() -> void:
	var filter := ""
	if not OS.get_cmdline_user_args().is_empty():
		filter = OS.get_cmdline_user_args()[0]
	var db := ContentDB.load_dir()
	for level in LevelDef.load_dir():
		if filter and not level.id.contains(filter):
			continue
		print("\n%s (%s)" % [level.name, level.type])
		print("  players  speed   served   lost   score   stars  failed")
		for players in [1, 2, 3, 4]:
			for speed in SPEEDS:
				var totals := {"served": 0.0, "lost": 0.0, "score": 0.0, "stars": 0.0, "failed": 0.0}
				for seed in SEEDS:
					var shift := Shift.new(db, level, players, seed)
					var bot := KitchenBot.new()
					bot.speed = speed
					KitchenBot.play(shift, bot, 0.1, 900.0)
					totals.served += shift.stats.served
					totals.lost += shift.stats.lost
					totals.score += shift.score
					totals.stars += shift.outcome.get("stars", 0)
					totals.failed += 1.0 if shift.outcome.get("failed", false) else 0.0
				var n := float(SEEDS.size())
				print("  %7d  %5.2f  %7.1f  %5.1f  %6.0f  %6.1f  %6.0f%%" % [
					players, speed, totals.served / n, totals.lost / n, totals.score / n, totals.stars / n, 100.0 * totals.failed / n])
	quit()
