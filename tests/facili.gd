extends SceneTree
func _init() -> void:
	var v := 0
	var ric := 0.0
	var dan := 0
	for k in 30:
		var m := Motore.new()
		m.nuova({"citta":"roswell","danneggiata":false,"scenario":"","personaggi":[],"cielo":[{"t":"1","lato":0},{"t":"2","lato":0},{"t":"3","lato":0},{"t":"4","lato":0}],"seme":100+k})
		var ia := IA.new(m)
		var g := 0
		while not m.finita() and g < 40:
			g += 1
			ia.turno()
		if m.s["esito"] == "vittoria": v += 1
		ric += float(m.s["ricerca"])
		if m.s["motivo"].begins_with("La base"): dan += 1
	print("facili: vinte %d/30, ricerca media %.1f, perse per danni %d" % [v, ric / 30.0, dan])
	# vittoria forzata: la ricerca arriva in cima
	var m2 := Motore.new()
	m2.nuova({"citta":"newyork","danneggiata":true,"scenario":"finale","personaggi":[],"cielo":[{"t":"c3a","lato":0},{"t":"c3b","lato":0},{"t":"c4","lato":0},{"t":"4","lato":0}],"seme":3})
	m2.s["ricerca"] = m2.s["traccia"].size() - 2
	m2._avanza_ricerca(1)
	print("vittoria forzata: ", m2.s["esito"], " - ", m2.s["motivo"])
	quit()
