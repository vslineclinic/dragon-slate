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
	## --standard: 기본 원정(20웨이브) 값으로 잰다.
	if args.has("--standard") and not demo:
		data = Build.for_length(data, "standard")
	## --stage N: N번째 지역(1부터). --carry 종id: 앞 지역에서 데려온 용.
	var stage_arg: int = int(_arg(args, "--stage", "0"))
	if stage_arg > 0 and not demo:
		data = Build.for_stage(data, stage_arg - 1)
	var carry: Dictionary = {}
	if not _arg(args, "--carry", "").is_empty():
		carry = {"speciesId": _arg(args, "--carry", ""), "traits": []}
	## --set waves.basePower=190 처럼 자료 값을 바꿔 가며 잰다(여러 번 쓸 수 있다). 배열 칸은 숫자로: battle.field.crossLanePct.1=80
	for i: int in range(args.size() - 1):
		if args[i] == "--set":
			_override(data, args[i + 1])
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
	var wave_first: Dictionary = {}
	var level_sum: Dictionary = {}
	var margin_sum: Dictionary = {}
	var margin_n: Dictionary = {}
	var want_margin: bool = args.has("--margin")
	for i: int in range(runs):
		var start: String = ""
		## --start: 그 판에 나온 첫째 시작 묶음으로. --start-index N: N번째 묶음으로(같은 씨앗에서 선택만 바꿔 견줄 때).
		if args.has("--start") or args.has("--start-index"):
			var options: Array = Run.start_options(data, first_seed + i)
			var pick: int = int(_arg(args, "--start-index", "0"))
			start = "" if options.is_empty() else options[pick % options.size()]["id"]
		var state: Dictionary = Run.create_run(data, first_seed + i, calamity, start, carry)["state"]
		var seen_waves: Dictionary = {}
		for step: int in range(COMMAND_LIMIT):
			if state["phase"] in ["victory", "gameOver"]:
				break
			var wave: int = state["wave"]
			var command: Dictionary = Bot.choose(data, state)
			if want_margin and command.get("type") == "startBattle" and not seen_waves.has(wave):
				margin_sum[wave] = int(margin_sum.get(wave, 0)) + _margin(data, state)
				margin_n[wave] = int(margin_n.get(wave, 0)) + 1
			var result: Dictionary = Run.apply_command(data, state, command)
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
						var tally: Array = wave_first.get(wave, [0, 0])
						tally[0] += 1
						tally[1] += 1 if won else 0
						wave_first[wave] = tally
						var top: int = 0
						for inst: Variant in state["nest"]:
							if inst != null:
								top = maxi(top, int(inst.get("level", 1)))
						level_sum[wave] = int(level_sum.get(wave, 0)) + top
						if wave == 1 and won:
							wave1_wins += 1
						if Waves.is_boss(data["waves"], wave):
							var rec: Array = boss_first.get(wave, [0, 0])
							rec[0] += 1
							rec[1] += 1 if won else 0
							boss_first[wave] = rec
		waves_reached += int(state["wave"])
		## --each: 판마다 한 줄(씨앗, 시작 묶음, 결과, 남은 생명, 둥지의 용).
		if args.has("--each"):
			var roost: PackedStringArray = PackedStringArray()
			for inst: Variant in state["nest"]:
				if inst != null:
					roost.append("%s(%s)" % [inst["speciesId"], data["dragons"][inst["speciesId"]].get("role", "")])
			print("RUN seed=%d start=%s %s wave=%d lives=%d roost=%s" % [first_seed + i, start, state["phase"], int(state["wave"]), int(state["lives"]), ",".join(roost)])
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
	if want_margin:
		var cells: Array = []
		var margin_waves: Array = margin_sum.keys()
		margin_waves.sort()
		for wave: int in margin_waves:
			cells.append("%d:%d" % [wave, Rng.fdiv(int(margin_sum[wave]), int(margin_n[wave]))])
		print("marginPct(이길 수 있는 적 전투력 배율): " + " ".join(cells))
	if args.has("--waves"):
		var rows: Array = []
		var all_waves: Array = wave_first.keys()
		all_waves.sort()
		for wave: int in all_waves:
			rows.append("%d:%d%%/L%d" % [wave, Rng.fdiv(wave_first[wave][1] * 100, maxi(1, wave_first[wave][0])), Rng.fdiv(int(level_sum[wave]), maxi(1, wave_first[wave][0]))])
		print("firstTryByWave(win/topLevel): " + " ".join(rows))
	var losses: Array = []
	var wave_keys: Array = game_over_wave.keys()
	wave_keys.sort()
	for wave: int in wave_keys:
		losses.append("%d:%d" % [wave, game_over_wave[wave]])
	print("gameOverWave: " + " ".join(losses))
	quit()


static func _override(data: Dictionary, spec: String) -> void:
	var parts: PackedStringArray = spec.split("=")
	var keys: PackedStringArray = parts[0].split(".")
	var node: Variant = data
	for i: int in range(keys.size() - 1):
		node = node[int(keys[i])] if node is Array else node[keys[i]]
	var last: String = keys[keys.size() - 1]
	if node is Array:
		node[int(last)] = int(parts[1])
	else:
		node[last] = int(parts[1])
	print("set %s" % spec)


## 지금 편성으로 이길 수 있는 가장 큰 적 전투력 배율(%). 100이면 딱 맞는 난이도.
static func _margin(data: Dictionary, state: Dictionary) -> int:
	var wave: int = state["wave"]
	var relics: Dictionary = Run.relic_bonus(data, state)
	var allies: Array = Battle.team(data, state["nest"], state["nestOpen"], relics)
	var rules: Dictionary = {}
	for boss: Dictionary in data["bosses"]:
		if boss["wave"] == wave and Waves.is_boss(data["waves"], wave):
			rules = boss.get("rules", {}).duplicate()
	if relics.has("strongAddPct"):
		rules["strongAddPct"] = relics["strongAddPct"]
	if relics.has("backRowNoLane"):
		rules["backRowNoLane"] = true
	var best: int = 25
	var pct: int = 35
	while pct <= 900:
		var mods: Dictionary = Calamity.mods(data, 0).duplicate()
		mods["enemyPowerPct"] = pct - 100
		var enemies: Array = Waves.generate_enemies(data, wave, Rng.new(int(state["seed"]) + wave * 31), state["seed"], mods)
		if Battle.simulate_battle(data["battle"], allies, enemies, rules)["winner"] != "ally":
			break
		best = pct
		pct = Rng.fdiv(pct * 130, 100)
	return best


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
