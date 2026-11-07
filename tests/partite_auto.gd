## Partite automatiche: godot --headless --path . -s tests/partite_auto.gd
extends SceneTree

func _init() -> void:
	var D := Motore.dati()
	var vinte := 0
	var perse := 0
	var turni := 0
	var per_scen := {}
	var motivi := {}
	var ric := 0.0
	var n := int(OS.get_environment("PARTITE")) if OS.get_environment("PARTITE") != "" else 300
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var k0 := int(OS.get_environment("DA")) if OS.get_environment("DA") != "" else 0
	for k in range(k0, k0 + n):
		var cfg := _cfg_casuale(rng, D, k)
		var m := Motore.new()
		m.nuova(cfg)
		var ia := IA.new(m)
		var g := 0
		while not m.finita() and g < 80:
			g += 1
			ia.turno()
			_verifica(m)
			# salvataggio e ricarica a metà partita
			if g == 3:
				var testo := JSON.stringify(m.s)
				var m2 := Motore.new()
				m2.carica(JSON.parse_string(testo))
				m = m2
				ia = IA.new(m)
		if not m.finita():
			push_error("Partita %d non finita dopo 80 turni: %s fase %s M %d" % [k, JSON.stringify(cfg), m.s["fase"], m.s["M"]])
			for l in m.s["log"].slice(-15): print(l)
		var sc: String = cfg["scenario"]
		if not per_scen.has(sc):
			per_scen[sc] = [0, 0]
		if m.s["esito"] == "vittoria":
			vinte += 1
			per_scen[sc][0] += 1
		else:
			perse += 1
		per_scen[sc][1] += 1
		turni += int(m.s["turno"])
		motivi[m.s["motivo"]] = motivi.get(m.s["motivo"], 0) + 1
		ric += float(m.s["ricerca"]) / float(m.s["traccia"].size() - 1)
	print("Partite: %d  vinte: %d  perse: %d  turni medi: %.1f" % [n, vinte, perse, float(turni) / n])
	print(motivi, "  ricerca media %.2f" % (ric / n))
	for sc in per_scen:
		print("  %-15s %d/%d" % [sc if sc != "" else "(nessuno)", per_scen[sc][0], per_scen[sc][1]])
	quit()

func _cfg_casuale(rng: RandomNumberGenerator, D: Dictionary, k: int) -> Dictionary:
	var citta: Array = D["citta"]
	var scen: Array = D["scenari"]
	var pers: Array = D["personaggi"]
	var ct: Dictionary = citta[k % citta.size()]
	var sc := ""
	if k % 3 != 0:
		sc = scen[rng.randi_range(0, scen.size() - 1)]["id"]
	var ps: Array = []
	for i in rng.randi_range(0, 3):
		ps.append({"id": pers[rng.randi_range(0, pers.size() - 1)]["id"], "promosso": rng.randf() < 0.5})
	var cielo := []
	for pos in ["1", "2", "3", "4"]:
		cielo.append({"t": pos, "lato": 1 if rng.randf() < 0.3 else 0})
	match k % 5:
		1:
			cielo[3] = {"t": "c2", "lato": rng.randi_range(0, 1)}
		2:
			cielo[0] = {"t": "c3a", "lato": rng.randi_range(0, 1)}
			cielo[1] = {"t": "c3b", "lato": rng.randi_range(0, 1)}
		3:
			cielo[0] = {"t": "c3a", "lato": 0}
			cielo[1] = {"t": "c3b", "lato": 0}
			cielo[2] = {"t": "c4", "lato": rng.randi_range(0, 1)}
	return {"citta": ct["id"], "danneggiata": rng.randf() < 0.4, "scenario": sc, "personaggi": ps,
		"cielo": cielo, "seme": 1000 + k}

func _verifica(m: Motore) -> void:
	var s := m.s
	var occ := {}
	for n in s["navi"]:
		if n["st"] == "cielo":
			var key := "%d,%d" % [n["r"], n["c"]]
			if occ.has(key) and int(n["r"]) > int(s["M"]):
				push_error("Due navi nello stesso spazio %s (turno %d) %s" % [key, s["turno"], JSON.stringify(s["cfg"])])
				for l in s["log"].slice(-12): print("   ", l)
			occ[key] = true
			if int(n["r"]) < int(s["M"]):
				push_error("Nave sopra la nave madre")
	if int(s["energia"]) < 0 or int(s["energia"]) > int(s["energia_max"]):
		push_error("Energia fuori scala: %d" % s["energia"])
	if s["robot"].size() > 2:
		push_error("Troppi robot")
