extends SceneTree
## 밸런스 시뮬레이터(화면 없음).
## godot --headless --path . --script res://godot/tools/sim.gd -- --runs 1000 --seed 1 [--demo] [--calamity 0]

const Bot = preload("res://godot/tools/bot.gd")
const Build = preload("res://godot/ui/build.gd")
const COMMAND_LIMIT: int = 3000


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(_arg(args, "--runs", "500"))
	var first_seed: int = int(_arg(args, "--seed", "1"))
	var calamity: int = int(_arg(args, "--calamity", "0"))
	var demo: bool = args.has("--demo")
	var data: Dictionary = Build.apply(GameData.load_all(), demo)
	if args.has("--solo"):
		_solo_first_wave(data, runs, first_seed)
		quit()
		return
	var max_wave: int = data["waves"]["maxWave"]

	var clears: int = 0
	var wave1_wins: int = 0
	var waves_reached: int = 0
	var lives_on_clear: int = 0
	var ticks_total: int = 0
	var battles: int = 0
	var max_units: int = 0
	var timeouts: int = 0
	var game_over_wave: Dictionary = {}
	var boss_first: Dictionary = {}
	for i: int in range(runs):
		var state: Dictionary = Run.create_run(data, first_seed + i, calamity)["state"]
		var seen_waves: Dictionary = {}
		for step: int in range(COMMAND_LIMIT):
			if state["phase"] in ["victory", "gameOver"]:
				break
			var wave: int = state["wave"]
			var result: Dictionary = Run.apply_command(data, state, Bot.choose(data, state))
			state = result["state"]
			if state.has("log"):
				state["log"].clear()
			for event: Dictionary in result["events"]:
				if event["t"] == "rejected":
					push_error("rejected seed %d wave %d: %s" % [first_seed + i, wave, event["reason"]])
					state["phase"] = "gameOver"
				elif event["t"] == "battle":
					var battle: Dictionary = event["result"]
					battles += 1
					ticks_total += int(battle["ticks"])
					max_units = maxi(max_units, battle["units"].size())
					if battle["winner"] == "enemy" and int(battle["ticks"]) >= int(data["battle"]["maxTicks"]):
						timeouts += 1
					var won: bool = battle["winner"] == "ally"
					if not seen_waves.has(wave):
						seen_waves[wave] = true
						if wave == 1 and won:
							wave1_wins += 1
						if Waves.is_boss(data["waves"], wave):
							var rec: Array = boss_first.get(wave, [0, 0])
							rec[0] += 1
							rec[1] += 1 if won else 0
							boss_first[wave] = rec
		waves_reached += int(state["wave"])
		if state["phase"] == "victory":
			clears += 1
			lives_on_clear += int(state["lives"])
		else:
			game_over_wave[state["wave"]] = game_over_wave.get(state["wave"], 0) + 1

	var bosses: Array = []
	var keys: Array = boss_first.keys()
	keys.sort()
	for wave: int in keys:
		bosses.append("w%d %d%%" % [wave, Rng.fdiv(boss_first[wave][1] * 100, maxi(1, boss_first[wave][0]))])
	print("runs=%d maxWave=%d calamity=%d clear=%d%% wave1Win=%d%% avgWave=%.1f livesOnClear=%.1f avgTicks=%d timeouts=%d maxUnits=%d" % [
		runs, max_wave, calamity, Rng.fdiv(clears * 100, maxi(1, runs)), Rng.fdiv(wave1_wins * 100, maxi(1, runs)),
		float(waves_reached) / maxi(1, runs), float(lives_on_clear) / maxi(1, clears),
		Rng.fdiv(ticks_total, maxi(1, battles)), timeouts, max_units,
	])
	print("bossFirstTry: " + ", ".join(bosses))
	var losses: Array = []
	var wave_keys: Array = game_over_wave.keys()
	wave_keys.sort()
	for wave: int in wave_keys:
		losses.append("%d:%d" % [wave, game_over_wave[wave]])
	print("gameOverWave: " + " ".join(losses))
	quit()


## 기본 드래곤 1마리(호위 포함)를 전열 가운데에 두고 1웨이브만 싸운다. 설계 목표: 승률 90% 이상.
static func _solo_first_wave(data: Dictionary, runs: int, first_seed: int) -> void:
	var bases: Array = []
	for spec: Dictionary in data["dragons"].values():
		if spec["tier"] == "base":
			bases.append(spec["id"])
	bases.sort()
	var wins: int = 0
	var worst: Dictionary = {}
	for i: int in range(runs):
		var run_seed: int = first_seed + i
		var rng: Rng = Rng.new(run_seed)
		var species: String = bases[i % bases.size()]
		var nest: Array = [null, null, null, null, null, null]
		nest[1] = Battle.to_unit(data, {"uid": 1, "speciesId": species, "traits": [], "bonusPct": 0})
		var enemies: Array = Waves.generate_enemies(data, 1, rng, run_seed)
		var won: bool = Battle.simulate_battle(data["battle"], nest, enemies)["winner"] == "ally"
		wins += 1 if won else 0
		if not won:
			worst[species] = worst.get(species, 0) + 1
	print("soloWave1 runs=%d win=%d%% losses=%s" % [runs, Rng.fdiv(wins * 100, maxi(1, runs)), str(worst)])


static func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
