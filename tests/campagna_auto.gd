## Campagne automatiche complete: godot --headless --path . -s tests/campagna_auto.gd
extends SceneTree

func _init() -> void:
	var n := int(OS.get_environment("CAMPAGNE")) if OS.get_environment("CAMPAGNE") != "" else 3
	for k in n:
		var cp := Campagna.new()
		cp.nuova("Prova %d" % k, 0, "ABCDEF")
		cp.rng.seed = 50 + k
		var guardia := 0
		var partite := 0
		while cp.c["passo"] != "finita" and guardia < 200:
			guardia += 1
			# salvataggio e ricarica ad ogni passo
			var cp2 := Campagna.new()
			cp2.carica(JSON.parse_string(JSON.stringify(cp.c)))
			cp2.rng.seed = 50 + k + guardia
			cp = cp2
			match cp.c["passo"]:
				"intro":
					cp.genera_pile()
				"scegli_pila":
					cp.scegli_pila(0)
				"scegli_promossi":
					var p := cp.promovibili()
					var ob := cp.promossi_obbligati()
					cp.scegli_promossi(ob if not ob.is_empty() else p.slice(0, cp.numero_promossi()))
				"pronta", "seconda":
					var m := Motore.new()
					m.nuova(cp.avvia_partita())
					var ia := IA.new(m)
					var g := 0
					while not m.finita() and g < 60:
						g += 1
						ia.turno()
					partite += 1
					# per provare entrambi i rami, ogni tanto si forza la vittoria
					var vinta: bool = m.s["esito"] == "vittoria" or (partite % 3 == 0)
					cp.esito(vinta)
				"fine_battaglia":
					cp.prosegui()
				"finale_citta":
					cp.scegli_citta_finale(cp.c["salvate"][0])
				_:
					push_error("passo sconosciuto " + str(cp.c["passo"]))
					break
		print("Campagna %d: %s, %d partite, punteggio %d, salvate %s, distrutte %s" % [k, "vinta" if cp.c["vinta"] else "persa", partite, cp.punteggio(), cp.c["salvate"], cp.c["distrutte"]])
		for b in cp.c["registro"]:
			print("   cap %d %s %s %s %s promossi %s" % [b["cap"], b["citta"], b["scenario"], b["pers"], b["esiti"], b["promossi"]])
		print("   finale ", cp.c["finale"])
	quit()
