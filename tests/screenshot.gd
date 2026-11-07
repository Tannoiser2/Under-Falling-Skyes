## Screenshot di prova: xvfb-run godot --path . --script res://tests/screenshot.gd
extends SceneTree

var main
var n := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(int(OS.get_environment("W")) if OS.get_environment("W") != "" else 1440, int(OS.get_environment("H")) if OS.get_environment("H") != "" else 900)

func _scatta(nome: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("/tmp/shot_%s.png" % nome)
	print("screenshot ", nome)

func _process(_d: float) -> bool:
	n += 1
	var cfg := {"citta": OS.get_environment("CITTA") if OS.get_environment("CITTA") != "" else "roswell", "danneggiata": false,
		"scenario": OS.get_environment("SCEN"), "personaggi": [{"id": "harper", "promosso": false}, {"id": "moss", "promosso": true}],
		"cielo": [{"t": "1", "lato": 0}, {"t": "2", "lato": 1}, {"t": "3", "lato": 0}, {"t": "4", "lato": 0}], "seme": 42}
	if OS.get_environment("CIELO") == "c3":
		cfg["cielo"] = [{"t": "c3a", "lato": 0}, {"t": "c3b", "lato": 1}, {"t": "c4", "lato": 0}, {"t": "4", "lato": 0}]
	if n == 6: _scatta("menu")
	if n == 8: main.prova_avvia(cfg)
	if n == 30: _scatta("turno1")
	if n == 32:
		var ia := IA.new(main.m)
		for i in 3:
			var mv := ia.mossa_dadi()
			main.m.piazza(mv[0], mv[1], mv[2])
		main.dado_sel = main.m.dadi_in_mano()[0]["id"]
		main.aggiorna(false)
	if n == 46:
		var best := []
		var bv := -1
		for cc in main.m.celle_legali(main.dado_sel):
			var pr := Motore.new()
			pr.carica(JSON.parse_string(JSON.stringify(main.m.s)))
			pr.piazza(main.dado_sel, cc[0], cc[1])
			if pr.eventi.size() > bv and main.m.scavata(cc[0], cc[1]):
				bv = pr.eventi.size()
				best = cc
		main._hover({"zona": "base", "r": best[0], "c": best[1]}, "base")
	if n == 50: _scatta("piazzati")
	if n == 52:
		var ia := IA.new(main.m)
		ia.turno()
		ia.turno()
		ia.turno()
		main.aggiorna(false)
	if n == 70: _scatta("turno4")
	if n == 72:
		main._mostra_regole()
	if n == 90: _scatta("regole")
	if n == 92:
		main.schermo_singola()
	if n == 100: _scatta("singola")
	if n == 102:
		main.prova_avvia({"citta": "mosca", "danneggiata": false, "scenario": "tempesta", "personaggi": [{"id": "almasi", "promosso": false}],
			"cielo": [{"t": "c3a", "lato": 0}, {"t": "c3b", "lato": 1}, {"t": "3", "lato": 0}, {"t": "4", "lato": 0}], "seme": 9})
	if n == 120:
		var ia := IA.new(main.m)
		while main.m.s["fase"] == "dadi":
			var mv := ia.mossa_veloce()
			main.m.piazza(mv[0], mv[1], mv[2])
		main.aggiorna(false)
		for d in main.m.s["dadi"]:
			if d["st"] == "piazzato" and not d["scavo"] and main.m.stanza_di(d["r"], d["c"]) >= 0:
				main._menu_stanze(d["r"], d["c"], Vector2(1000, 400))
				break
	if n == 135: _scatta("stanze")
	if n == 137:
		var cp := Campagna.new()
		cp.nuova("Prova", 1, "XYZ123")
		cp.genera_pile()
		main.camp = cp
		main.codice = "XYZ123"
		main.schermo_campagna()
	if n == 145: _scatta("campagna")
	if n == 147:
		main.camp.scegli_pila(0)
		main.camp.c["capitolo"] = 3
		main.camp.c["alleati"] = [{"id": "moss", "cap": 1}, {"id": "harper", "cap": 1}, {"id": "aumann", "cap": 2}, {"id": "bell", "cap": 2}]
		main.camp.c["passo"] = "scegli_promossi"
		main.schermo_campagna()
	if n == 155: _scatta("promossi")
	if n == 157: return true
	return false
