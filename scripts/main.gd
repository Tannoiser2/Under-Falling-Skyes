## Interfaccia: menu, partita singola, campagna e schermata di gioco con il tabellone 3D.
extends Control

const ALFABETO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const SALVA_LOCALE := "user://ufs_salvataggio.json"
const C_FONDO := Color(0.03, 0.05, 0.11)
const C_PANNELLO := Color(0.06, 0.09, 0.18, 0.94)
const C_MAGENTA := Color(0.9, 0.12, 0.42)
const C_CIANO := Color(0.3, 0.82, 0.95)
const C_ORO := Color(1.0, 0.78, 0.25)
const C_TESTO := Color(0.88, 0.92, 1.0)
const C_TENUE := Color(0.6, 0.68, 0.85)
const NOMI_EFFETTO := {"energia": "Energetica", "ricerca": "Ricerca", "caccia": "Caccia", "robot": "Robot",
	"comando": "Comando", "aa": "Cannone antiaereo"}

var font_testo: FontFile
var font_grassetto: FontFile
var font_titolo: FontFile
var tema: Theme
var net: Node

var schermo: Control
var m: Motore
var camp: Campagna
var tipo := ""          # "singola" o "campagna"
var codice := ""
var ultimo_cfg := {}

# schermata di gioco
var tav: Tavolo
var sv_cielo: SubViewport
var sv_base: SubViewport
var cam_cielo: Camera3D
var cam_base: Camera3D
var zoom := {"cielo": 1.0, "base": 1.0}
var spost := {"cielo": Vector3.ZERO, "base": Vector3.ZERO}
var lbl_stato: RichTextLabel
var lbl_info: Label
var lbl_hover: Label
var log_box: RichTextLabel
var vassoio: HBoxContainer
var box_azioni: HBoxContainer
var box_pers: VBoxContainer
var lbl_codice: Label
var dado_sel := -1
var selezione := {}
var storia: Array = []
var libero: Control
var cam_libera: Camera3D
var orbita := Vector3(0.0, -55.0, 34.0)   # yaw, pitch, distanza
var centro_libero := Vector3.ZERO
var trascina := ""
var finestra: Control

func _ready() -> void:
	randomize()
	font_testo = load("res://assets/font/ChakraPetch-Regular.ttf")
	font_grassetto = load("res://assets/font/ChakraPetch-Bold.ttf")
	font_titolo = load("res://assets/font/SairaCondensed-ExtraBold.ttf")
	_crea_tema()
	theme = tema
	net = load("res://scripts/net.gd").new()
	add_child(net)
	var bg := ColorRect.new()
	bg.color = C_FONDO
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if OS.get_environment("UFS_PROVA") != "":
		return
	menu()

# ---------------------------------------------------------------- tema

func _stile(col: Color, bordo := Color(0, 0, 0, 0), r := 6, b := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = r
	s.corner_radius_top_right = r
	s.corner_radius_bottom_left = r
	s.corner_radius_bottom_right = r
	if b > 0:
		s.border_color = bordo
		s.border_width_left = b
		s.border_width_right = b
		s.border_width_top = b
		s.border_width_bottom = b
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _crea_tema() -> void:
	tema = Theme.new()
	tema.default_font = font_testo
	tema.default_font_size = 18
	tema.set_color("font_color", "Label", C_TESTO)
	tema.set_color("default_color", "RichTextLabel", C_TESTO)
	tema.set_font("bold_font", "RichTextLabel", font_grassetto)
	tema.set_font("normal_font", "RichTextLabel", font_testo)
	tema.set_stylebox("normal", "Button", _stile(Color(0.1, 0.16, 0.32), C_CIANO.darkened(0.3), 6, 1))
	tema.set_stylebox("hover", "Button", _stile(Color(0.16, 0.24, 0.45), C_CIANO, 6, 2))
	tema.set_stylebox("pressed", "Button", _stile(Color(0.5, 0.06, 0.24), C_MAGENTA, 6, 2))
	tema.set_stylebox("disabled", "Button", _stile(Color(0.08, 0.1, 0.16), Color(0.2, 0.24, 0.32), 6, 1))
	tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	tema.set_color("font_color", "Button", C_TESTO)
	tema.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.6))
	tema.set_font("font", "Button", font_grassetto)
	tema.set_stylebox("panel", "PanelContainer", _stile(C_PANNELLO, Color(0.25, 0.4, 0.7, 0.6), 8, 1))
	tema.set_stylebox("normal", "LineEdit", _stile(Color(0.02, 0.03, 0.08), C_CIANO.darkened(0.4), 4, 1))
	tema.set_stylebox("normal", "OptionButton", _stile(Color(0.1, 0.16, 0.32), C_CIANO.darkened(0.3), 6, 1))
	tema.set_stylebox("hover", "OptionButton", _stile(Color(0.16, 0.24, 0.45), C_CIANO, 6, 2))
	tema.set_font("font", "OptionButton", font_testo)
	tema.set_stylebox("panel", "PopupMenu", _stile(Color(0.05, 0.08, 0.17), C_CIANO.darkened(0.2), 6, 2))
	tema.set_font("font", "PopupMenu", font_testo)
	tema.set_font_size("font_size", "PopupMenu", 18)
	tema.set_color("font_color", "PopupMenu", C_TESTO)
	tema.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	tema.set_stylebox("hover", "PopupMenu", _stile(Color(0.5, 0.06, 0.24), Color(0, 0, 0, 0), 4))
	tema.set_stylebox("normal", "TooltipPanel", _stile(Color(0.02, 0.03, 0.08), C_CIANO, 4, 1))
	tema.set_stylebox("panel", "TooltipPanel", _stile(Color(0.02, 0.03, 0.08), C_CIANO, 4, 1))
	tema.set_font("font", "TooltipLabel", font_testo)
	tema.set_color("font_color", "TooltipLabel", C_TESTO)

func _lbl(testo: String, dim := 18, col := C_TESTO, f: Font = null) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", col)
	if f != null:
		l.add_theme_font_override("font", f)
	if testo.length() > 40:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 260
	return l

func _titolo(testo: String, dim := 40) -> Label:
	var l := _lbl(testo, dim, C_ORO, font_titolo)
	l.add_theme_color_override("font_outline_color", Color(0.4, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _btn(testo: String, cb: Callable, dim := 20) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", dim)
	b.pressed.connect(cb)
	return b

func _rich(testo: String, dim := 18) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = testo
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", dim)
	r.add_theme_font_size_override("bold_font_size", dim)
	return r

func _immagine(path: String, w: float, h: float = -1) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if h < 0 and t.texture != null:
		h = w * t.texture.get_height() / t.texture.get_width()
	t.custom_minimum_size = Vector2(w, h)
	return t

func _nuovo_schermo() -> Control:
	if schermo != null:
		schermo.queue_free()
	for ch in get_children():
		if ch is PopupMenu:
			ch.queue_free()
	finestra = null
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schermo)
	tav = null
	return schermo

func _centrato(larg := 760.0) -> VBoxContainer:
	var sc := _nuovo_schermo()
	var art := _immagine("res://assets/ui/copertina.webp", 600)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.28, 0.3, 0.4)
	sc.add_child(art)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(scroll)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cc)
	var pan := PanelContainer.new()
	pan.custom_minimum_size = Vector2(larg, 0)
	cc.add_child(pan)
	var mg := MarginContainer.new()
	for k in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + k, 22)
	pan.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	mg.add_child(v)
	return v

# ---------------------------------------------------------------- menu

func menu() -> void:
	m = null
	var sc := _nuovo_schermo()
	var art := _immagine("res://assets/ui/copertina.webp", 600)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.anchor_left = 0.36
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sc.add_child(art)
	var sfum := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, C_FONDO)
	g.set_color(1, Color(C_FONDO.r, C_FONDO.g, C_FONDO.b, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	sfum.texture = gt
	sfum.set_anchors_preset(Control.PRESET_FULL_RECT)
	sfum.anchor_left = 0.36
	sfum.anchor_right = 0.52
	sc.add_child(sfum)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	v.offset_left = 50
	v.offset_right = 470
	v.offset_top = 60
	v.add_theme_constant_override("separation", 14)
	sc.add_child(v)
	v.add_child(_titolo("UNDER FALLING SKIES", 54))
	v.add_child(_lbl("Difendi la tua città dall'invasione aliena: piazza i dadi nella base, abbatti le navi e completa la ricerca prima che la nave madre ti raggiunga.", 18, C_TENUE))
	var spazio := Control.new()
	spazio.custom_minimum_size = Vector2(0, 10)
	v.add_child(spazio)
	var sal := _leggi_locale()
	if not sal.is_empty():
		var desc := "Continua"
		if sal.get("tipo", "") == "campagna":
			desc = "Continua la campagna «%s»" % sal.get("campagna", {}).get("nome", "")
		else:
			desc = "Continua la partita"
		v.add_child(_btn(desc, func(): _riprendi(sal), 22))
	v.add_child(_btn("Nuova campagna", schermo_nuova_campagna, 22))
	v.add_child(_btn("Riprendi con un codice", schermo_codice, 22))
	v.add_child(_btn("Partita singola", schermo_singola, 22))
	v.add_child(_btn("Prima partita (Roswell, facile)", func(): _avvia_singola(_cfg_prima()), 22))
	v.add_child(_btn("Regole", schermo_regole, 22))
	var piede := _lbl("Versione digitale per uso personale. Under Falling Skies è un gioco di Tomáš Uhlíř, © Czech Games Edition; edizione italiana Cranio Creations.", 13, C_TENUE)
	piede.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	piede.offset_left = 50
	piede.offset_top = -60
	piede.offset_right = 520
	sc.add_child(piede)

func _cfg_prima() -> Dictionary:
	return {"citta": "roswell", "danneggiata": false, "scenario": "", "personaggi": [],
		"cielo": [{"t": "1", "lato": 0}, {"t": "2", "lato": 0}, {"t": "3", "lato": 0}, {"t": "4", "lato": 0}], "seme": 0}

func schermo_regole() -> void:
	var v := _centrato(900)
	v.add_child(_titolo("Regole in breve"))
	v.add_child(_rich(Testi.REGOLE, 18))
	v.add_child(_btn("Indietro", _indietro_da_regole))

var _regole_da_gioco := false
func _indietro_da_regole() -> void:
	menu()

# ---------------------------------------------------------------- codici e salvataggi

func _nuovo_codice() -> String:
	var s := ""
	for i in 6:
		s += ALFABETO[randi() % ALFABETO.length()]
	return s

func _leggi_locale() -> Dictionary:
	if not FileAccess.file_exists(SALVA_LOCALE):
		return {}
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.READ)
	var x = JSON.parse_string(f.get_as_text())
	return x if x is Dictionary else {}

func _dati_salvataggio() -> Dictionary:
	var d := {"tipo": tipo, "codice": codice, "data": int(Time.get_unix_time_from_system())}
	if tipo == "campagna":
		if m != null and not m.finita():
			camp.c["stato_partita"] = m.s
		d["campagna"] = camp.c
	elif m != null:
		d["partita"] = m.s
	return d

func salva(cloud := false) -> void:
	if tipo == "":
		return
	var d := _dati_salvataggio()
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()
	if cloud and codice != "":
		var ramo := "campagne" if tipo == "campagna" else "partite"
		var nome: String = camp.c["nome"] if tipo == "campagna" else "Partita singola"
		var ok: bool = await net.salva(ramo, codice, d, nome)
		if lbl_codice != null and is_instance_valid(lbl_codice):
			lbl_codice.text = "Codice: %s  %s" % [codice, "· salvato online" if ok else "· salvataggio online non riuscito"]

func _riprendi(d: Dictionary) -> void:
	codice = d.get("codice", "")
	tipo = d.get("tipo", "")
	if tipo == "campagna":
		camp = Campagna.new()
		camp.carica(d["campagna"])
		if camp.c.get("stato_partita") is Dictionary:
			m = Motore.new()
			m.carica(camp.c["stato_partita"])
			schermo_gioco()
		else:
			schermo_campagna()
	elif d.has("partita"):
		m = Motore.new()
		m.carica(d["partita"])
		ultimo_cfg = m.s["cfg"]
		schermo_gioco()
	else:
		menu()

func schermo_codice() -> void:
	var v := _centrato(560)
	v.add_child(_titolo("Riprendi con un codice"))
	v.add_child(_lbl("Il codice di 6 caratteri compare nella schermata di gioco. Le campagne e le partite si salvano online alla fine di ogni turno, così puoi riprenderle da un altro dispositivo.", 17, C_TENUE))
	var le := LineEdit.new()
	le.max_length = 6
	le.placeholder_text = "ABC123"
	le.add_theme_font_size_override("font_size", 30)
	v.add_child(le)
	var esito := _lbl("", 17, C_MAGENTA)
	v.add_child(esito)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(_btn("Campagna", func(): _carica_codice("campagne", le.text.strip_edges().to_upper(), esito)))
	h.add_child(_btn("Partita singola", func(): _carica_codice("partite", le.text.strip_edges().to_upper(), esito)))
	h.add_child(_btn("Indietro", menu))

func _carica_codice(ramo: String, cod: String, esito: Label) -> void:
	if cod.length() != 6:
		esito.text = "Il codice ha 6 caratteri."
		return
	esito.text = "Caricamento..."
	var d = await net.carica(ramo, cod)
	if d == null:
		esito.text = "Nessun salvataggio con questo codice (o rete non raggiungibile)."
		return
	d["codice"] = cod
	_riprendi(d)

# ---------------------------------------------------------------- partita singola

var _form := {}

func schermo_singola() -> void:
	var v := _centrato(900)
	v.add_child(_titolo("Partita singola"))
	var D := Motore.dati()
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	_form = {}
	g.add_child(_lbl("Città", 18))
	var hc := HBoxContainer.new()
	var oc := OptionButton.new()
	for ct in D["citta"]:
		oc.add_item("%s  (cap. %s)" % [ct["nome"], "base" if int(ct["cap"]) == 0 else str(ct["cap"])])
	oc.custom_minimum_size = Vector2(320, 0)
	hc.add_child(oc)
	var cd := CheckBox.new()
	cd.text = "danneggiata"
	hc.add_child(cd)
	g.add_child(hc)
	_form["citta"] = oc
	_form["danneggiata"] = cd
	g.add_child(_lbl("Scenario", 18))
	var os := OptionButton.new()
	os.add_item("Nessuno")
	for x in D["scenari"]:
		os.add_item("%s  (cap. %d)" % [x["nome"], x["cap"]])
	g.add_child(os)
	_form["scenario"] = os
	var pers_opt: Array = []
	for k in 3:
		g.add_child(_lbl("Personaggio %d" % (k + 1), 18))
		var hp := HBoxContainer.new()
		var op := OptionButton.new()
		op.add_item("Nessuno")
		for x in D["personaggi"]:
			op.add_item(x["nome"])
		op.custom_minimum_size = Vector2(320, 0)
		hp.add_child(op)
		var pp := CheckBox.new()
		pp.text = "promosso"
		hp.add_child(pp)
		g.add_child(hp)
		pers_opt.append([op, pp])
	_form["pers"] = pers_opt
	var nomi_t := {"1": "Base 1 (in alto)", "2": "Base 2", "3": "Base 3", "4": "Base 4 (in basso)", "c2": "Avanzata cap. 2 (cielo ridotto)",
		"c3a": "Avanzata cap. 3 (A)", "c3b": "Avanzata cap. 3 (B)", "c4": "Avanzata cap. 4 (esplosioni rosse)"}
	var tess: Array = []
	var predef := ["1", "2", "3", "4"]
	for k in 4:
		g.add_child(_lbl("Tessera cielo %d" % (k + 1), 18))
		var ht := HBoxContainer.new()
		var ot := OptionButton.new()
		var ids: Array = []
		for t in ["1", "2", "3", "4", "c2", "c3a", "c3b", "c4"]:
			ot.add_item(nomi_t[t])
			ids.append(t)
		ot.select(ids.find(predef[k]))
		ot.set_meta("ids", ids)
		ot.custom_minimum_size = Vector2(320, 0)
		ht.add_child(ot)
		var lm := CheckBox.new()
		lm.text = "lato minaccioso"
		ht.add_child(lm)
		g.add_child(ht)
		tess.append([ot, lm])
	_form["cielo"] = tess
	var hm := HBoxContainer.new()
	hm.add_child(_lbl("Livello di minaccia casuale:", 18))
	for k in 5:
		hm.add_child(_btn(str(k), func(): _minaccia_casuale(k)))
	v.add_child(hm)
	var diff := _lbl("", 20, C_ORO, font_grassetto)
	v.add_child(diff)
	_form["diff"] = diff
	for o in [oc, os]:
		o.item_selected.connect(func(_i): _aggiorna_diff())
	cd.toggled.connect(func(_b): _aggiorna_diff())
	for pp in pers_opt:
		pp[0].item_selected.connect(func(_i): _aggiorna_diff())
		pp[1].toggled.connect(func(_b): _aggiorna_diff())
	for t in tess:
		t[0].item_selected.connect(func(_i): _aggiorna_diff())
		t[1].toggled.connect(func(_b): _aggiorna_diff())
	_aggiorna_diff()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	hb.add_child(_btn("Gioca", func(): _avvia_singola(_cfg_form()), 24))
	hb.add_child(_btn("Indietro", menu, 20))

func _minaccia_casuale(k: int) -> void:
	var pos := [0, 1, 2, 3]
	pos.shuffle()
	for i in 4:
		_form["cielo"][i][1].button_pressed = i in pos.slice(0, k)
	_aggiorna_diff()

func _cfg_form() -> Dictionary:
	var D := Motore.dati()
	var cfg := {"citta": D["citta"][_form["citta"].selected]["id"], "danneggiata": _form["danneggiata"].button_pressed,
		"scenario": "" if _form["scenario"].selected == 0 else D["scenari"][_form["scenario"].selected - 1]["id"],
		"personaggi": [], "cielo": [], "seme": 0}
	var visti := {}
	for pp in _form["pers"]:
		if pp[0].selected > 0:
			var id: String = D["personaggi"][pp[0].selected - 1]["id"]
			if not visti.has(id):
				visti[id] = true
				cfg["personaggi"].append({"id": id, "promosso": pp[1].button_pressed})
	for t in _form["cielo"]:
		cfg["cielo"].append({"t": t[0].get_meta("ids")[t[0].selected], "lato": 1 if t[1].button_pressed else 0})
	if cfg["scenario"] == "finale":
		cfg["satellite"] = true
	return cfg

func _aggiorna_diff() -> void:
	var cfg := _cfg_form()
	var d := Motore.difficolta(cfg)
	var txt := "Livello di difficoltà: %s" % (str(int(d)) if d == floor(d) else "%.1f" % d)
	_form["diff"].text = txt

func _avvia_singola(cfg: Dictionary) -> void:
	tipo = "singola"
	codice = _nuovo_codice()
	ultimo_cfg = cfg.duplicate(true)
	m = Motore.new()
	m.nuova(cfg)
	schermo_gioco()
	salva(true)

# ---------------------------------------------------------------- campagna

func schermo_nuova_campagna() -> void:
	var v := _centrato(640)
	v.add_child(_titolo("Nuova campagna"))
	v.add_child(_lbl("Quattro capitoli, una decina di partite. Inventa un nome per il diario della campagna e scegli il livello di minaccia (il numero di tessere cielo girate sul lato più minaccioso). Potrai cambiarlo fra una battaglia e l'altra.", 17, C_TENUE))
	var le := LineEdit.new()
	le.placeholder_text = "Per aspera ad astra"
	le.add_theme_font_size_override("font_size", 24)
	v.add_child(le)
	var hm := HBoxContainer.new()
	hm.add_child(_lbl("Livello di minaccia:", 18))
	var sb := SpinBox.new()
	sb.min_value = 0
	sb.max_value = 4
	sb.value = 1
	hm.add_child(sb)
	hm.add_child(_lbl("(1 = difficoltà normale)", 16, C_TENUE))
	v.add_child(hm)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(_btn("Inizia", func():
		tipo = "campagna"
		codice = _nuovo_codice()
		camp = Campagna.new()
		var nome := le.text.strip_edges()
		camp.nuova(nome if nome != "" else "Per aspera ad astra", int(sb.value), codice)
		schermo_campagna()
		salva(true), 22))
	h.add_child(_btn("Indietro", menu))

func _riga_registro(b: Dictionary) -> String:
	var ct := Motore.citta(b["citta"])
	var sc := Motore.scenario(b["scenario"])
	var esiti: Array = []
	for e in b["esiti"]:
		esiti.append("[color=#ff4f8a]X[/color]" if str(e) == "X" else "[color=#7dff8a]%s[/color]" % str(e))
	var pers := ""
	if b.get("pers", "") != "":
		pers = Motore.personaggio(b["pers"])["nome"]
	for p in b.get("promossi", []):
		pers += (", " if pers != "" else "") + Motore.personaggio(p)["nome"] + " (promosso)"
	return "[b]%s[/b] · %s · %s   %s" % [ct["nome"], sc.get("nome", ""), pers, "  ".join(esiti)]

func _registro_testo() -> String:
	var t := ""
	var cap := 0
	for b in camp.c["registro"]:
		if int(b["cap"]) != cap:
			cap = int(b["cap"])
			t += "\n[color=#ffc840][b]Capitolo %d[/b][/color]\n" % cap
		t += _riga_registro(b) + "\n"
	for tt in camp.c["finale"].get("tentativi", []):
		t += "[color=#ffc840][b]Battaglia finale[/b][/color] · %s  %s\n" % [Motore.citta(tt["citta"])["nome"], "X" if str(tt["esito"]) == "X" else str(tt["esito"])]
	if t == "":
		t = "[i]Il diario è ancora vuoto.[/i]"
	elif t.begins_with("\n"):
		t = t.substr(1)
	return t

func schermo_campagna() -> void:
	tipo = "campagna"
	var c: Dictionary = camp.c
	var v := _centrato(980)
	var cap: int = c["capitolo"]
	v.add_child(_lbl("Campagna «%s» · codice %s · minaccia %d" % [c["nome"], codice, c["minaccia"]], 16, C_TENUE))
	match c["passo"]:
		"intro":
			v.add_child(_titolo(Campagna.TITOLI[cap]))
			v.add_child(_lbl(Campagna.INTRO[cap], 19, C_TESTO))
			v.add_child(_rich("[color=#4fd0f0][b]Novità del capitolo[/b][/color]\n" + Campagna.NOVITA[cap], 17))
			v.add_child(_btn("Prepara la prima battaglia", func():
				camp.genera_pile()
				schermo_campagna()
				salva(true), 22))
		"scegli_pila":
			v.add_child(_titolo(Campagna.TITOLI[cap]))
			v.add_child(_lbl("Due città sono sotto attacco. Scegli quale difendere: l'altra sarà annientata, insieme allo scenario e al personaggio della sua pila.", 18))
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 16)
			v.add_child(h)
			for i in c["pile"].size():
				h.add_child(_carta_pila(c["pile"][i], i))
		"scegli_promossi":
			_scegli_promossi(v)
		"pronta", "seconda":
			var cor: Dictionary = c["corrente"]
			if c["passo"] == "seconda":
				v.add_child(_titolo("Seconda partita"))
				v.add_child(_lbl("Hai perso la prima partita, ma i cittadini resistono: si gioca una seconda partita sul lato danneggiato della città, con lo stesso scenario e gli stessi personaggi. Le tessere cielo minacciose vengono estratte di nuovo.", 18))
			else:
				v.add_child(_titolo("Battaglia pronta"))
			v.add_child(_riepilogo_battaglia(cor))
			_regola_minaccia(v)
			v.add_child(_btn("Combatti!", func():
				var cfg := camp.avvia_partita()
				m = Motore.new()
				m.nuova(cfg)
				schermo_gioco()
				salva(true), 24))
		"fine_battaglia":
			var ult: Dictionary = c["registro"][c["registro"].size() - 1]
			var salvata := not str(ult["esiti"][ult["esiti"].size() - 1]) == "X"
			v.add_child(_titolo("Città salvata!" if salvata else "Città perduta"))
			v.add_child(_rich(_riga_registro(ult), 18))
			v.add_child(_lbl("%s ha combattuto al tuo fianco: tornerà promosso nei prossimi capitoli." % Motore.personaggio(ult["pers"])["nome"], 17, C_TENUE))
			_regola_minaccia(v)
			v.add_child(_btn("Prossimo capitolo" if int(c["battaglia"]) >= 2 else "Prossima battaglia", func():
				camp.prosegui()
				schermo_campagna()
				salva(true), 22))
		"finale_citta":
			v.add_child(_titolo(Campagna.TITOLI[4]))
			v.add_child(_lbl(Campagna.INTRO[4], 18))
			v.add_child(_rich("[color=#4fd0f0][b]La Battaglia Finale[/b][/color]\n" + Campagna.NOVITA[4], 17))
			v.add_child(_lbl("Scegli la città che ospiterà la battaglia (lato danneggiato):", 18, C_ORO))
			var g := GridContainer.new()
			g.columns = 2
			v.add_child(g)
			for id in c["salvate"]:
				var b := VBoxContainer.new()
				b.add_child(_immagine("res://assets/citta/%s_d.webp" % id, 430))
				b.add_child(_btn(Motore.citta(id)["nome"], func():
					camp.scegli_citta_finale(id)
					schermo_campagna()
					salva(true)))
				g.add_child(b)
			_regola_minaccia(v)
		"finita":
			v.add_child(_titolo("Il pianeta è salvo!" if c["vinta"] else "La Terra è caduta"))
			v.add_child(_lbl("Hai distrutto il satellite dell'intelligenza artificiale e liberato gli alieni." if c["vinta"] else "Nessuna città è rimasta in piedi per la battaglia finale.", 19))
			v.add_child(_lbl("Punteggio finale: %d" % camp.punteggio(), 30, C_ORO, font_titolo))
			if c["finale"].has("squadra"):
				var nomi: Array = []
				for p in c["finale"]["squadra"]:
					nomi.append(Motore.personaggio(p)["nome"])
				v.add_child(_lbl("Squadra: " + ", ".join(nomi), 17, C_TENUE))
	v.add_child(_rich("[color=#4fd0f0][b]Diario della campagna[/b][/color]\n" + _registro_testo(), 16))
	var hb := HBoxContainer.new()
	hb.add_child(_btn("Menu", menu))
	v.add_child(hb)

func _regola_minaccia(v: VBoxContainer) -> void:
	var hm := HBoxContainer.new()
	hm.add_child(_lbl("Livello di minaccia:", 17))
	var sb := SpinBox.new()
	sb.min_value = 0
	sb.max_value = 4
	sb.value = int(camp.c["minaccia"])
	sb.value_changed.connect(func(x):
		camp.c["minaccia"] = int(x)
		if camp.c["corrente"] is Dictionary and not camp.c["corrente"].is_empty():
			camp.c["corrente"]["minaccia"] = int(x))
	hm.add_child(sb)
	v.add_child(hm)

func _carta_pila(p: Dictionary, i: int) -> Control:
	var pan := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pan.add_child(v)
	var ct := Motore.citta(p["citta"])
	v.add_child(_lbl(ct["nome"], 26, C_ORO, font_titolo))
	v.add_child(_immagine("res://assets/citta/%s.webp" % p["citta"], 430))
	var sc := Motore.scenario(p["scenario"])
	v.add_child(_rich("[b]Scenario: %s[/b]\n[i]%s[/i]" % [sc["nome"], sc["intro"]], 15))
	var h := HBoxContainer.new()
	h.add_child(_immagine("res://assets/personaggi/%s.webp" % p["pers"], 130))
	var pe := Motore.personaggio(p["pers"])
	h.add_child(_rich("[b]%s[/b]\n%s\n%s" % [pe["nome"], pe["ruolo"], pe["testo"]], 15))
	h.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.get_child(1).custom_minimum_size = Vector2(280, 0)
	v.add_child(h)
	v.add_child(_btn("Difendi %s" % ct["nome"], func():
		camp.scegli_pila(i)
		schermo_campagna()
		salva(true), 20))
	return pan

func _riepilogo_battaglia(cor: Dictionary) -> Control:
	var v := VBoxContainer.new()
	var dan: bool = int(cor.get("partita", 1)) == 2 or int(camp.c["capitolo"]) == 4
	var ct := Motore.citta(cor["citta"])
	v.add_child(_immagine("res://assets/citta/%s%s.webp" % [cor["citta"], "_d" if dan else ""], 600))
	var sc := Motore.scenario(cor["scenario"])
	v.add_child(_rich("[b]%s[/b]%s\n[b]Scenario: %s[/b] – %s" % [ct["nome"], " (danneggiata)" if dan else "", sc["nome"], sc["intro"]], 16))
	var h := HBoxContainer.new()
	if cor.get("pers", "") != "":
		h.add_child(_immagine("res://assets/personaggi/%s.webp" % cor["pers"], 120))
	for p in cor.get("promossi", []):
		h.add_child(_immagine("res://assets/personaggi/%s_p.webp" % p, 120))
	v.add_child(h)
	return v

func _scegli_promossi(v: VBoxContainer) -> void:
	var c: Dictionary = camp.c
	var n := camp.numero_promossi()
	var obblig := camp.promossi_obbligati()
	if not obblig.is_empty():
		camp.scegli_promossi(obblig)
		schermo_campagna()
		return
	v.add_child(_titolo("Personaggi promossi"))
	if int(c["capitolo"]) == 4:
		v.add_child(_lbl("Forma la squadra: scegli 3 personaggi promossi fra quelli che hanno combattuto al tuo fianco.", 18))
	else:
		v.add_child(_lbl("Scegli %s fra quelli che hanno combattuto al tuo fianco: %s nella prossima battaglia." % ["un personaggio promosso" if n == 1 else "%d personaggi promossi" % n, "gli altri combatteranno"], 18))
	var scelti: Array = []
	var g := GridContainer.new()
	g.columns = 4
	v.add_child(g)
	var conferma := _btn("Conferma", func():
		camp.scegli_promossi(scelti)
		schermo_campagna()
		salva(true), 22)
	conferma.disabled = true
	for id in camp.promovibili():
		var b := VBoxContainer.new()
		b.add_child(_immagine("res://assets/personaggi/%s_p.webp" % id, 200))
		var cb := CheckBox.new()
		cb.text = Motore.personaggio(id)["nome"]
		cb.toggled.connect(func(on):
			if on:
				scelti.append(id)
			else:
				scelti.erase(id)
			conferma.disabled = scelti.size() != min(n, camp.promovibili().size()))
		b.add_child(cb)
		g.add_child(b)
	v.add_child(conferma)

# ---------------------------------------------------------------- schermata di gioco

func schermo_gioco() -> void:
	var sc := _nuovo_schermo()
	storia.clear()
	dado_sel = -1
	selezione = {}
	var radice := HBoxContainer.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_theme_constant_override("separation", 0)
	sc.add_child(radice)
	# --- pannello sinistro
	var sin := PanelContainer.new()
	sin.custom_minimum_size = Vector2(300, 0)
	radice.add_child(sin)
	var ssc := ScrollContainer.new()
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sin.add_child(ssc)
	var vs := VBoxContainer.new()
	vs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs.add_theme_constant_override("separation", 8)
	ssc.add_child(vs)
	vs.add_child(_titolo("UNDER FALLING SKIES", 28))
	lbl_stato = _rich("", 17)
	vs.add_child(lbl_stato)
	var ct := Motore.citta(m.citta_id())
	var img_c := _immagine("res://assets/citta/%s%s.webp" % [m.citta_id(), "_d" if m.danneggiata() else ""], 276)
	img_c.mouse_filter = Control.MOUSE_FILTER_STOP
	img_c.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _mostra_citta())
	img_c.tooltip_text = ct["testo_d"] if m.danneggiata() else ct["testo"]
	vs.add_child(img_c)
	if m.scen() != "":
		vs.add_child(_btn("Scenario: " + Motore.scenario(m.scen())["nome"], _mostra_scenario, 17))
	box_pers = VBoxContainer.new()
	vs.add_child(box_pers)
	var hb := HBoxContainer.new()
	hb.add_child(_btn("Regole", _mostra_regole, 16))
	hb.add_child(_btn("Vista 3D", _apri_libera, 16))
	hb.add_child(_btn("Menu", _esci, 16))
	vs.add_child(hb)
	lbl_codice = _lbl("Codice: %s" % codice, 14, C_TENUE)
	vs.add_child(lbl_codice)
	# --- cielo
	tav = Tavolo.new()
	var zona_cielo := Control.new()
	zona_cielo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zona_cielo.size_flags_stretch_ratio = 0.75
	radice.add_child(zona_cielo)
	var cont_cielo := SubViewportContainer.new()
	cont_cielo.stretch = true
	cont_cielo.set_anchors_preset(Control.PRESET_FULL_RECT)
	zona_cielo.add_child(cont_cielo)
	sv_cielo = SubViewport.new()
	sv_cielo.msaa_3d = Viewport.MSAA_2X
	cont_cielo.add_child(sv_cielo)
	sv_cielo.add_child(tav)
	tav.costruisci(m)
	cam_cielo = Camera3D.new()
	cam_cielo.fov = 42
	cam_cielo.cull_mask = Tavolo.STRATO_CIELO
	sv_cielo.add_child(cam_cielo)
	cont_cielo.gui_input.connect(func(e): _input_vista(e, "cielo", cont_cielo))
	# --- colonna destra
	var des := VBoxContainer.new()
	des.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	des.size_flags_stretch_ratio = 1.0
	des.add_theme_constant_override("separation", 0)
	radice.add_child(des)
	var zona_base := Control.new()
	zona_base.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zona_base.size_flags_stretch_ratio = 1.5
	des.add_child(zona_base)
	var cont_base := SubViewportContainer.new()
	cont_base.stretch = true
	cont_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	zona_base.add_child(cont_base)
	sv_base = SubViewport.new()
	sv_base.msaa_3d = Viewport.MSAA_2X
	sv_base.world_3d = sv_cielo.find_world_3d()
	cont_base.add_child(sv_base)
	cam_base = Camera3D.new()
	cam_base.fov = 40
	cam_base.cull_mask = Tavolo.STRATO_BASE
	sv_base.add_child(cam_base)
	cont_base.gui_input.connect(func(e): _input_vista(e, "base", cont_base))
	lbl_hover = _lbl("", 16, C_TESTO)
	lbl_hover.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_hover.add_theme_constant_override("outline_size", 6)
	lbl_hover.position = Vector2(12, 8)
	lbl_hover.size = Vector2(900, 30)
	lbl_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zona_base.add_child(lbl_hover)
	var basso := PanelContainer.new()
	basso.size_flags_vertical = Control.SIZE_EXPAND_FILL
	basso.size_flags_stretch_ratio = 1.0
	des.add_child(basso)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	basso.add_child(vb)
	lbl_info = _lbl("", 18, C_ORO, font_grassetto)
	vb.add_child(lbl_info)
	vassoio = HBoxContainer.new()
	vassoio.add_theme_constant_override("separation", 10)
	vassoio.custom_minimum_size = Vector2(0, 74)
	vb.add_child(vassoio)
	box_azioni = HBoxContainer.new()
	box_azioni.add_theme_constant_override("separation", 8)
	vb.add_child(box_azioni)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 15)
	vb.add_child(log_box)
	await get_tree().process_frame
	_inquadra(false)
	aggiorna(false)

func _inquadra(anim := true) -> void:
	if tav == null:
		return
	_imposta_cam(cam_cielo, tav.aabb_cielo(), sv_cielo.size, zoom["cielo"], spost["cielo"], 72.0, anim)
	_imposta_cam(cam_base, tav.aabb_base(), sv_base.size, zoom["base"], spost["base"], 68.0, anim)

func _imposta_cam(cam: Camera3D, box: AABB, vp: Vector2i, z: float, sp: Vector3, pitch: float, anim: bool) -> void:
	var asp := float(max(vp.x, 1)) / float(max(vp.y, 1))
	var fv := deg_to_rad(cam.fov)
	var fh := 2.0 * atan(tan(fv / 2.0) * asp)
	var cen := box.get_center() + sp
	var d: float = max((box.size.z * 0.5 * sin(deg_to_rad(pitch))) / tan(fv / 2.0), (box.size.x * 0.5) / tan(fh / 2.0)) * 1.04 / z
	var dir := Vector3(0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch)))
	var pos := cen + dir * d
	var xf := Transform3D(Basis(), pos).looking_at(cen, Vector3.UP)
	if anim:
		var tw := create_tween()
		tw.tween_property(cam, "global_transform", xf, 0.5)
	else:
		cam.global_transform = xf

func _raggio(e: InputEvent, cam: Camera3D, cont: Control) -> Vector3:
	var p: Vector2 = e.position
	var o := cam.project_ray_origin(p)
	var n := cam.project_ray_normal(p)
	if abs(n.y) < 0.0001:
		return Vector3(INF, 0, 0)
	var t := -o.y / n.y
	return o + n * t

func _input_vista(e: InputEvent, quale: String, cont: Control) -> void:
	var cam := cam_cielo if quale == "cielo" else cam_base
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom[quale] = min(zoom[quale] * 1.12, 4.0)
			_inquadra(false)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom[quale] = max(zoom[quale] / 1.12, 0.6)
			_inquadra(false)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			trascina = quale if e.pressed else ""
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if e.double_click:
				zoom[quale] = 1.0
				spost[quale] = Vector3.ZERO
				_inquadra()
				return
			var p := _raggio(e, cam, cont)
			var cella := tav.cella_da_punto(p)
			if not cella.is_empty():
				_click_cella(cella, e.global_position)
	elif e is InputEventMouseMotion:
		if trascina == quale:
			var k: float = 0.04 / zoom[quale]
			spost[quale] += Vector3(-e.relative.x * k, 0, -e.relative.y * k)
			_inquadra(false)
		else:
			var p := _raggio(e, cam, cont)
			_hover(tav.cella_da_punto(p), quale)

# ---------------------------------------------------------------- informazioni al passaggio del mouse

func _hover(cella: Dictionary, quale: String) -> void:
	if lbl_hover == null or m == null:
		return
	var t := ""
	if cella.get("zona", "") == "base":
		var r: int = cella["r"]
		var c: int = cella["c"]
		var i := m.stanza_di(r, c)
		if not m.scavata(r, c):
			var dist := m.indice_percorso(r, c) - int(m.s["esc"])
			t = "Non scavato" + (" · %d spazi dall'escavatore" % dist if dist > 0 else " · escavatore")
		elif i < 0:
			t = "Cunicolo scavato"
		else:
			t = _desc_stanza(i)
	elif cella.get("zona", "") == "cielo":
		var r: int = cella["r"]
		var c: int = cella["c"]
		if r >= 0 and r < m.righe_cielo():
			var x := m.cella_cielo(r, c)
			t = _desc_spazio(x)
			var az: String = m.s["cielo"][r]["azione"]
			if az != "":
				t += " · azione della nave madre: " + _desc_azione(az)
			var n := m.nave_in(r, c)
			if not n.is_empty():
				t = "Nave %s · %s" % [n["col"], t]
	lbl_hover.text = t

func _desc_stanza(i: int) -> String:
	var st: Dictionary = m.s["stanze"][i]
	var nomi: Array = []
	for t in st["t"]:
		nomi.append(NOMI_EFFETTO.get(t, t))
	var t := "/".join(nomi)
	if st["celle"].size() > 1:
		t += " (%d spazi)" % st["celle"].size()
	if int(st["costo"]) > 0:
		t += " · costo %d" % st["costo"]
	if int(st["mod"]) != 0:
		t += " · modificatore %+d" % st["mod"]
	if m.stanza_piena(i) and not m.effetti(i).is_empty():
		t += " · valore %d" % m.valore_stanza(i)
	return t

func _desc_spazio(x: String) -> String:
	if x == "":
		return "Spazio vuoto"
	match x:
		">":
			return "Freccia: sposta la nave a destra"
		"<":
			return "Freccia: sposta la nave a sinistra"
		"M":
			return "Nave madre: scende di una riga"
		"Pp", "Pc":
			return "Teletrasporto"
		"V":
			return "Cielo vuoto: la nave colpisce la città"
	if x[0] == "E":
		return "Esplosione %s" % x.substr(1)
	if x[0] == "X":
		return "Esplosione rossa %s" % x.substr(1)
	return x

func _desc_azione(az: String) -> String:
	var k := az.substr(1)
	match az[0]:
		"W":
			return "%s nav%s bianc%s" % [k, "e" if k == "1" else "i", "a" if k == "1" else "he"]
		"X":
			return "escavatore %s" % k
		"S":
			return "ricerca %s" % k
		"D":
			return "1 danno"
		"G":
			return "tutte le navi scendono di %s" % k
		"K":
			return "teschio"
	return az

# ---------------------------------------------------------------- aggiornamento

func aggiorna(anim := true) -> void:
	if m == null or tav == null:
		return
	if anim:
		tav.eventi(m.eventi)
	m.eventi.clear()
	tav.aggiorna(anim)
	_inquadra(anim)
	_stato()
	_vassoio()
	_azioni()
	_personaggi()
	_evidenze()
	var t := ""
	for l in m.s["log"].slice(-40):
		t += l + "\n"
	log_box.text = t
	if m.finita():
		_fine_partita()

func _stato() -> void:
	var s := m.s
	var fase := {"dadi": "Fase dei Dadi", "stanze": "Fase delle Stanze", "madre": "Fase della Nave Madre", "fine": "Partita finita"}
	var tr: Array = s["traccia"]
	var t := "[b]Turno %d[/b] · %s\n" % [s["turno"], fase.get(s["fase"], "")]
	t += "[color=#ffd23f]Energia[/color] %d / %d\n" % [s["energia"], s["energia_max"]]
	t += "[color=#ff4f8a]Danni[/color] %d / %d\n" % [s["danni"], m.soglia_danni()]
	t += "[color=#7dff8a]Ricerca[/color] %d / %d" % [s["ricerca"], tr.size() - 1]
	if int(s["ricerca"]) + 1 < tr.size():
		t += " (prossimo spazio: %d)" % int(tr[int(s["ricerca"]) + 1]["v"])
	t += "\n[color=#4fd0f0]Navi in attesa[/color] %d" % m.navi_in_attesa().size()
	var riserva := 0
	for n in s["navi"]:
		if n["st"] == "riserva":
			riserva += 1
	t += " · bianche in riserva %d\n" % riserva
	var M: int = s["M"]
	var teschio := -1
	for r in range(max(M + 1, 0), m.righe_cielo()):
		if s["cielo"][r]["azione"] == "K":
			teschio = r
			break
	if teschio >= 0:
		t += "Nave madre: %d righe dal teschio\n" % (teschio - M)
	var sc: Dictionary = s["sc"]
	match m.scen():
		"rinforzi":
			if int(s["t"]["rinforzi"]) > 0:
				t += "Rinforzi: segnalino %d, %d nella pila\n" % [s["t"]["rinforzi"], sc["pila"].size()]
		"evacuazione":
			t += "Civili in città: %s\n" % (", ".join(sc["citta"].map(func(x): return str(x))) if not sc["citta"].is_empty() else "nessuno")
		"reattore":
			t += "Segnalini reattore: %d\n" % sc["k"]
		"riparazione":
			t += "Segnalini riparazione: %s\n" % ", ".join(sc["gettoni"].map(func(x): return str(x)))
		"sabotatore":
			if int(sc.get("col", -1)) >= 0:
				t += "Colonna sabotata: %d\n" % (int(sc["col"]) + 1)
		"contaminazione":
			t += "Pila contaminazione: %s\n" % (", ".join(sc["pila"].map(func(x): return str(x))) if not sc["pila"].is_empty() else "vuota")
		"tempesta":
			t += "Segnalini tempesta sulla nave madre: %d\n" % sc["madre"]
		"satelliti":
			t += "Satelliti in orbita: %d\n" % sc["sat"].size()
	if tipo == "campagna":
		t += "[color=#9aa8d8]%s · battaglia %d[/color]" % [Campagna.TITOLI[int(camp.c["capitolo"])], int(camp.c["battaglia"]) + 1]
	lbl_stato.text = t

func _vassoio() -> void:
	for ch in vassoio.get_children():
		ch.queue_free()
	if m.s["fase"] != "dadi":
		return
	for d in m.s["dadi"]:
		if d["st"] != "mano" and d["st"] != "bloccato":
			continue
		var b := DadoUI.new()
		b.valore = int(d["v"])
		b.colore = d["col"]
		b.fisso = d.get("fisso", false)
		b.bloccato = d["st"] == "bloccato"
		b.scelto = d["id"] == dado_sel
		var id: int = d["id"]
		if not b.bloccato:
			b.premuto.connect(func(): _scegli_dado(id))
		vassoio.add_child(b)

func _scegli_dado(id: int) -> void:
	if not selezione.is_empty() and selezione.get("tipo", "") == "dado":
		var cb: Callable = selezione["fatto"]
		selezione = {}
		cb.call(id)
		return
	dado_sel = -1 if dado_sel == id else id
	_vassoio()
	_evidenze()
	_info()

func _info() -> void:
	if not selezione.is_empty():
		lbl_info.text = selezione.get("testo", "")
		return
	match m.s["fase"]:
		"dadi":
			if dado_sel < 0:
				lbl_info.text = "Scegli un dado e poi uno spazio della base. Ogni dado va in una colonna diversa."
			else:
				lbl_info.text = "Clicca uno spazio evidenziato della base per piazzare il dado."
		"stanze":
			lbl_info.text = "Clicca un dado sulla base per risolverlo, poi termina la fase."
		_:
			lbl_info.text = ""

func _azioni() -> void:
	for ch in box_azioni.get_children():
		ch.queue_free()
	_info()
	if m.finita():
		return
	if not selezione.is_empty():
		if selezione.has("conferma"):
			box_azioni.add_child(_btn("Conferma", func():
				var cb: Callable = selezione["conferma"]
				var sc: Array = selezione.get("scelti", [])
				selezione = {}
				cb.call(sc), 17))
		box_azioni.add_child(_btn("Annulla scelta", func():
			selezione = {}
			aggiorna(false), 17))
		return
	if not storia.is_empty():
		box_azioni.add_child(_btn("Annulla", _annulla, 17))
	if m.s["fase"] == "dadi":
		if m.citta_id() == "washington" and m.danneggiata() and not m.s["t"]["lavati"] and m.dadi_in_mano().size() == m._dadi_attivi():
			box_azioni.add_child(_btn("Washington: un dado a 6", func():
				_seleziona({"tipo": "dado", "testo": "Clicca il dado da impostare su 6.", "fatto": func(id):
					_azione_motore(func(): m.washington(id))}), 17))
		if m.citta_id() == "singapore" and not m.danneggiata() and not m.s["robot"].is_empty() and m.dadi_in_mano().size() == m._dadi_attivi():
			box_azioni.add_child(_btn("Singapore: sposta un robot", func(): _scegli_robot_da_spostare(), 17))
	elif m.s["fase"] == "stanze":
		box_azioni.add_child(_btn("Fine Fase delle Stanze", _fine_stanze, 18))
		if m.citta_id() == "rio" and not m.s["t"]["rio"] and not m.s["t"]["stanze_iniziate"] and not m.navi_rio().is_empty():
			box_azioni.add_child(_btn("Rio: rimanda la nave più bassa", _rio, 17))
	if m.citta_id() == "singapore" and m.danneggiata() and not m.s["robot"].is_empty() and m.s["fase"] in ["dadi", "stanze"]:
		box_azioni.add_child(_btn("Singapore: sposta un robot", func(): _scegli_robot_da_spostare(), 17))

func _personaggi() -> void:
	for ch in box_pers.get_children():
		ch.queue_free()
	for i in m.s["personaggi"].size():
		var p: Dictionary = m.s["personaggi"][i]
		var pe := Motore.personaggio(p["id"])
		var h := HBoxContainer.new()
		var img := _immagine("res://assets/personaggi/%s%s.webp" % [p["id"], "_p" if p["promosso"] else ""], 70)
		img.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx: int = i
		img.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _mostra_personaggio(idx))
		h.add_child(img)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl(pe["nome"], 16, C_ORO, font_grassetto))
		v.add_child(_lbl(pe["ruolo_p"] if p["promosso"] else pe["ruolo"], 13, C_TENUE))
		var b := _btn("Usata" if p["usato"] else "Usa", func(): _usa_personaggio(idx), 15)
		var perche := m.puo_usare(i)
		b.disabled = perche != "" or not selezione.is_empty()
		b.tooltip_text = (pe["testo_p"] if p["promosso"] else pe["testo"]) + ("\n\n" + perche if perche != "" and not p["usato"] else "")
		v.add_child(b)
		h.add_child(v)
		box_pers.add_child(h)

func _evidenze() -> void:
	if tav == null:
		return
	tav.pulisci_evidenza()
	if not selezione.is_empty():
		if selezione.get("tipo", "") == "base":
			tav.evidenzia_base(selezione["candidati"], C_CIANO)
			tav.evidenzia_base(selezione.get("scelti", []), C_MAGENTA)
		elif selezione.get("tipo", "") == "nave":
			var cc: Array = []
			for id in selezione["candidati"]:
				var n := m.nave(id)
				cc.append([n["r"], n["c"]])
			tav.evidenzia_cielo(cc, C_CIANO)
			var sc: Array = []
			for id in selezione.get("scelti", []):
				var n := m.nave(id)
				sc.append([n["r"], n["c"]])
			tav.evidenzia_cielo(sc, C_MAGENTA)
		return
	if m.s["fase"] == "dadi" and dado_sel >= 0:
		tav.evidenzia_base(m.celle_legali(dado_sel), C_CIANO)
	elif m.s["fase"] == "stanze":
		var cc: Array = []
		for d in m.s["dadi"]:
			if d["st"] == "piazzato":
				cc.append([d["r"], d["c"]])
		tav.evidenzia_base(cc, C_ORO)

# ---------------------------------------------------------------- azioni

func _istantanea() -> void:
	storia.append(JSON.stringify(m.s))
	if storia.size() > 30:
		storia.pop_front()

func _annulla() -> void:
	if storia.is_empty():
		return
	var st = JSON.parse_string(storia.pop_back())
	m.carica(st)
	dado_sel = -1
	tav.costruisci(m)
	aggiorna(false)

## Esegue un'azione del motore con possibilità di annullarla.
func _azione_motore(f: Callable, annullabile := true) -> void:
	if annullabile:
		_istantanea()
	var turno: int = m.s["turno"]
	f.call()
	if int(m.s["turno"]) != turno or m.finita():
		storia.clear()
	aggiorna()
	salva(int(m.s["turno"]) != turno or m.finita())

func _click_cella(cella: Dictionary, gpos: Vector2) -> void:
	if m.finita():
		return
	if not selezione.is_empty():
		_click_selezione(cella)
		return
	if cella["zona"] != "base":
		return
	var r: int = cella["r"]
	var c: int = cella["c"]
	if m.s["fase"] == "dadi":
		if dado_sel < 0:
			return
		var perche := m.perche_no(dado_sel, r, c)
		if perche != "":
			lbl_info.text = perche
			return
		var d := m.dado(dado_sel)
		var id := dado_sel
		if d.get("fisso", false) and m.valori_pechino().size() > 1:
			var menu_p := _popup(gpos)
			for v in m.valori_pechino():
				menu_p.add_item("Pechino: valore %d" % v)
			menu_p.id_pressed.connect(func(k): _piazza(id, r, c, m.valori_pechino()[k]))
			menu_p.popup()
			return
		_piazza(id, r, c, 0)
	elif m.s["fase"] == "stanze":
		_menu_stanze(r, c, gpos)

func _piazza(id: int, r: int, c: int, pech: int) -> void:
	var bianco: bool = m.dado(id)["col"] == "bianco"
	dado_sel = -1
	_azione_motore(func(): m.piazza(id, r, c, pech), not bianco)
	if bianco:
		storia.clear()
		_azioni()

func _popup(gpos: Vector2) -> PopupMenu:
	var pm := PopupMenu.new()
	add_child(pm)
	pm.position = Vector2i(gpos)
	pm.popup_hide.connect(func(): pm.queue_free.call_deferred())
	return pm

func _menu_stanze(r: int, c: int, gpos: Vector2) -> void:
	var w := m.lavoratore_in(r, c)
	var ro := m.robot_in(r, c)
	var i := m.stanza_di(r, c)
	var voci: Array = []   # [testo, Callable, abilitata]
	if i >= 0 and not m.effetti(i).is_empty() and (not w.is_empty() or not ro.is_empty()):
		var perche := m.attivabile(i)
		var ef := m.effetti(i)
		if ef.size() == 2:
			for ordine in [[ef[0], ef[1]], [ef[1], ef[0]]]:
				voci.append(["Risolvi: prima %s, poi %s" % [NOMI_EFFETTO[ordine[0]].to_lower(), NOMI_EFFETTO[ordine[1]].to_lower()], func(): _risolvi(i, ordine), perche == ""])
		else:
			var testo := "Risolvi la stanza %s" % NOMI_EFFETTO[ef[0]].to_lower()
			if perche == "":
				testo += " (valore %d%s)" % [m.valore_effetto(i, ef[0]), ", costo %d" % m.s["stanze"][i]["costo"] if int(m.s["stanze"][i]["costo"]) > 0 else ""]
			else:
				testo += " – " + perche
			voci.append([testo, func(): _risolvi(i, ef), perche == ""])
		if m.citta_id() == "montreal" and perche == "":
			voci.append(["Montreal: risolvi insieme ad altre stanze", func(): _montreal(i), true])
	if not w.is_empty():
		var id: int = w["id"]
		if w["scavo"]:
			var p := m.puo_scavare(id)
			voci.append(["Fai avanzare l'escavatore (1 energia)" + ("" if p == "" else " – " + p), func(): _azione_motore(func(): m.scava(id)), p == ""])
		if m.scen() == "riparazione":
			var p2 := m.puo_riparare(id)
			if p2 != "x":
				voci.append(["Ripara la base" + ("" if p2 == "" else " – " + p2), func(): _azione_motore(func(): m.ripara(id)), p2 == ""])
		if m.citta_id() == "avana" and not w["scavo"] and i >= 0 and not "comando" in m.tipi_stanza(i) and m.s["robot"].size() < m.max_robot():
			voci.append(["Rimuovi e assembla un robot esaurito (L'Avana)", func(): _azione_motore(func(): m.rimuovi(id, {"avana": true})), true])
		voci.append(["Rimuovi il dado senza effetto", func(): _azione_motore(func(): m.rimuovi(id)), true])
		if m.citta_id() in ["cairo", "sydney"]:
			voci.append(["Trasferisci il dado (%s)" % Motore.citta(m.citta_id())["nome"], func(): _trasferimento_citta(id), true])
	if voci.is_empty():
		lbl_info.text = _desc_stanza(i) if i >= 0 else "Nessun dado qui."
		return
	var pm := _popup(gpos)
	for k in voci.size():
		pm.add_item(voci[k][0], k)
		pm.set_item_disabled(k, not voci[k][2])
	pm.id_pressed.connect(func(k): voci[k][1].call())
	pm.popup()

func _risolvi(i: int, ordine: Array) -> void:
	var opz := {"ordine": ordine}
	var passi_dopo := func(o: Dictionary):
		if "comando" in ordine:
			_dialogo_comando(i, o)
		else:
			_azione_motore(func(): m.risolvi(i, o))
	var dopo_robot := func(o: Dictionary):
		if "robot" in ordine:
			var cand := m.celle_robot_libere()
			if not "comando" in m.tipi_stanza(i):
				for cc in m.s["stanze"][i]["celle"]:
					if not m.lavoratore_in(cc[0], cc[1]).is_empty() and not cc in cand:
						cand.append(cc)
			if cand.is_empty():
				passi_dopo.call(o)
				return
			_seleziona({"tipo": "base", "candidati": cand, "testo": "Scegli lo spazio dove assemblare il robot.", "fatto": func(sc):
				o["robot_dest"] = sc[0]
				passi_dopo.call(o)})
		else:
			passi_dopo.call(o)
	if "ricerca" in ordine and m.scen() == "pericolosa":
		var v := m.valore_effetto(i, "ricerca")
		var p := m.passi_ricerca(v)
		if p > 1:
			_finestra("Ricerca pericolosa", _lbl("Puoi avanzare di %d spazi subendo 1 danno, oppure di 1 solo spazio senza danni." % p, 18), [
				["Avanza di %d (1 danno)" % p, func():
					opz["passi"] = p
					dopo_robot.call(opz)],
				["Avanza di 1", func():
					opz["passi"] = 1
					dopo_robot.call(opz)]])
			return
	dopo_robot.call(opz)

func _dialogo_comando(i: int, opz: Dictionary) -> void:
	var v := m.valore_effetto(i, "comando")
	var box := VBoxContainer.new()
	var testa := _lbl("Distribuisci %d punti fra i dadi lavoratore (massimo 6 per dado)." % v, 18)
	box.add_child(testa)
	var spin := {}
	var celle_stanza: Array = m.s["stanze"][i]["celle"]
	for d in m.s["dadi"]:
		if d["st"] != "piazzato" or d["scavo"] or [d["r"], d["c"]] in celle_stanza or m.sabotata(d["c"]):
			continue
		var h := HBoxContainer.new()
		var st := m.stanza_di(d["r"], d["c"])
		h.add_child(_lbl("Dado %s %d · colonna %d · %s" % [d["col"], d["v"], int(d["c"]) + 1, _desc_stanza(st) if st >= 0 else "cunicolo"], 16))
		var sb := SpinBox.new()
		sb.min_value = 0
		sb.max_value = 6 - int(d["v"])
		h.add_child(sb)
		spin[d["id"]] = sb
		box.add_child(h)
	if spin.is_empty():
		box.add_child(_lbl("Nessun altro dado lavoratore da aumentare.", 16, C_TENUE))
	_finestra("Stanza comando", box, [["Conferma", func():
		var dist := {}
		var tot := 0
		for k in spin:
			if spin[k].value > 0:
				dist[k] = int(spin[k].value)
				tot += int(spin[k].value)
		if tot > v:
			lbl_info.text = "Hai distribuito più punti del valore della stanza."
			return
		opz["comando"] = dist if not dist.is_empty() else {-1: 0}
		_azione_motore(func(): m.risolvi(i, opz))]])

func _montreal(i: int) -> void:
	var cand: Array = []
	for k in m.stanze_attivabili():
		if k == i:
			continue
		for t in m.effetti(k):
			if t in m.effetti(i):
				for cc in m.s["stanze"][k]["celle"]:
					cand.append(cc)
				break
	if cand.is_empty():
		lbl_info.text = "Nessun'altra stanza dello stesso tipo pronta."
		return
	_seleziona({"tipo": "base", "candidati": cand, "multi": true, "testo": "Montreal: scegli le altre stanze da risolvere insieme, poi Conferma.",
		"conferma": func(sc):
			var lista := [i]
			for cc in sc:
				var k := m.stanza_di(cc[0], cc[1])
				if not k in lista:
					lista.append(k)
			var comuni: Array = m.effetti(i).duplicate()
			for k in lista:
				comuni = comuni.filter(func(t): return t in m.effetti(k))
			if comuni.is_empty() or lista.size() < 2:
				lbl_info.text = "Le stanze devono avere un tipo in comune."
				aggiorna(false)
				return
			var esegui := func(tipo_c: String):
				var o := {}
				if tipo_c == "comando":
					o["comando"] = {}
				_azione_motore(func(): m.risolvi_insieme(lista, tipo_c, o))
			if comuni.size() == 1:
				esegui.call(comuni[0])
			else:
				var bt: Array = []
				for t in comuni:
					bt.append([NOMI_EFFETTO[t], func(): esegui.call(t)])
				_finestra("Montreal", _lbl("Quale effetto vuoi sommare?", 18), bt)})

func _trasferimento_citta(id: int) -> void:
	var d := m.dado(id)
	var cand: Array = []
	for r in Motore.RIGHE_BASE:
		for c in Motore.COLONNE:
			if not m.puo_trasferire(id, r, c):
				continue
			match m.citta_id():
				"cairo":
					if c == int(d["c"]) and m.stanza_di(r, c) != m.stanza_di(d["r"], d["c"]):
						cand.append([r, c])
				"sydney":
					if "ricerca" in m.tipi_stanza(m.stanza_di(r, c)):
						cand.append([r, c])
	if cand.is_empty():
		lbl_info.text = "Nessuno spazio disponibile."
		return
	_seleziona({"tipo": "base", "candidati": cand, "testo": "Scegli lo spazio di arrivo.", "fatto": func(sc):
		_azione_motore(func():
			if not m.trasferisci_citta(id, sc[0][0], sc[0][1]):
				m._log("Trasferimento non permesso in questo momento."))})

func _scegli_robot_da_spostare() -> void:
	var cand: Array = []
	for ro in m.s["robot"]:
		if m.danneggiata() and ro["esausto"]:
			continue
		cand.append([ro["r"], ro["c"]])
	_seleziona({"tipo": "base", "candidati": cand, "testo": "Scegli il robot da spostare.", "fatto": func(sc):
		var ro := m.robot_in(sc[0][0], sc[0][1])
		var dest: Array = []
		for r in Motore.RIGHE_BASE:
			for c in Motore.COLONNE:
				if m.puo_trasferire(ro["id"], r, c):
					dest.append([r, c])
		_seleziona({"tipo": "base", "candidati": dest, "testo": "Scegli dove spostarlo.", "fatto": func(sc2):
			_azione_motore(func(): m.trasferisci_citta(ro["id"], sc2[0][0], sc2[0][1]))})})

func _rio() -> void:
	var cand := m.navi_rio()
	if cand.size() == 1:
		_azione_motore(func(): m.rio(cand[0]["id"]))
		return
	var ids: Array = cand.map(func(n): return n["id"])
	_seleziona({"tipo": "nave", "candidati": ids, "testo": "Rio: scegli quale nave rimandare.", "fatto": func(sc):
		_azione_motore(func(): m.rio(sc[0]))})

func _fine_stanze() -> void:
	var resti := 0
	for d in m.s["dadi"]:
		if d["st"] == "piazzato":
			resti += 1
	var esegui := func():
		storia.clear()
		_azione_motore(func(): m.fine_stanze(), false)
	if resti > 0:
		_finestra("Fine della Fase delle Stanze", _lbl("Ci sono ancora %d dadi sulla base: verranno rimossi senza effetto." % resti, 18), [["Termina la fase", esegui], ["Torna alla base", func(): pass]])
	else:
		esegui.call()

# ---------------------------------------------------------------- modalità di selezione

func _seleziona(sel: Dictionary) -> void:
	sel["scelti"] = []
	selezione = sel
	dado_sel = -1
	aggiorna(false)

func _click_selezione(cella: Dictionary) -> void:
	var t: String = selezione.get("tipo", "")
	var scelta = null
	if t == "base" and cella["zona"] == "base":
		var cc := [cella["r"], cella["c"]]
		if cc in selezione["candidati"]:
			scelta = cc
	elif t == "nave" and cella["zona"] == "cielo":
		var n := m.nave_in(cella["r"], cella["c"])
		if not n.is_empty() and n["id"] in selezione["candidati"]:
			scelta = n["id"]
	if scelta == null:
		return
	var sc: Array = selezione["scelti"]
	if scelta in sc:
		sc.erase(scelta)
	else:
		sc.append(scelta)
	var maxs: int = selezione.get("max", 1)
	if not selezione.get("multi", false) and sc.size() >= maxs:
		var cb: Callable = selezione["fatto"]
		selezione = {}
		cb.call(sc)
		return
	_evidenze()
	_azioni()

# ---------------------------------------------------------------- finestre

func _finestra(titolo: String, contenuto: Control, bottoni: Array) -> void:
	if finestra != null and is_instance_valid(finestra):
		finestra.queue_free()
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(velo)
	finestra = velo
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.add_child(cc)
	var pan := PanelContainer.new()
	pan.custom_minimum_size = Vector2(560, 0)
	cc.add_child(pan)
	var mg := MarginContainer.new()
	for k in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + k, 18)
	pan.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	mg.add_child(v)
	v.add_child(_titolo(titolo, 30))
	var scr := ScrollContainer.new()
	scr.custom_minimum_size = Vector2(0, min(620, max(80, contenuto.get_combined_minimum_size().y + 20)))
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenuto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scr.add_child(contenuto)
	v.add_child(scr)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	for b in bottoni:
		var cb: Callable = b[1]
		h.add_child(_btn(b[0], func():
			velo.queue_free()
			finestra = null
			cb.call(), 18))
	if bottoni.is_empty():
		h.add_child(_btn("Chiudi", func():
			velo.queue_free()
			finestra = null, 18))

func _mostra_regole() -> void:
	var r := _rich(Testi.REGOLE, 17)
	r.custom_minimum_size = Vector2(820, 0)
	_finestra("Regole in breve", r, [])

func _mostra_citta() -> void:
	var ct := Motore.citta(m.citta_id())
	var v := VBoxContainer.new()
	v.add_child(_immagine("res://assets/citta/%s%s.webp" % [m.citta_id(), "_d" if m.danneggiata() else ""], 820))
	v.add_child(_rich("[b]%s%s[/b]\n%s\n\nBase: %s (sopra) e %s (sotto)." % [ct["nome"], " (danneggiata)" if m.danneggiata() else "",
		ct["testo_d"] if m.danneggiata() else ct["testo"], ct["su"], ct["giu"]], 18))
	_finestra(ct["nome"], v, [])

func _mostra_scenario() -> void:
	var sc := Motore.scenario(m.scen())
	var r := _rich("[i]%s[/i]\n\n[color=#ffc840][b]Preparazione[/b][/color]\n%s\n\n[color=#ffc840][b]Regole[/b][/color]\n%s" % [sc["intro"], sc["prep"], sc["regole"]], 18)
	r.custom_minimum_size = Vector2(760, 0)
	_finestra(sc["nome"], r, [])

func _mostra_personaggio(i: int) -> void:
	var p: Dictionary = m.s["personaggi"][i]
	var pe := Motore.personaggio(p["id"])
	var h := HBoxContainer.new()
	h.add_child(_immagine("res://assets/personaggi/%s%s.webp" % [p["id"], "_p" if p["promosso"] else ""], 300))
	var r := _rich("[b]%s[/b]\n%s\n\n%s\n\n[i]Abilità utilizzabile una volta per partita.[/i]" % [pe["nome"], pe["ruolo_p"] if p["promosso"] else pe["ruolo"], pe["testo_p"] if p["promosso"] else pe["testo"]], 18)
	r.custom_minimum_size = Vector2(380, 0)
	h.add_child(r)
	_finestra(pe["nome"], h, [])

# ---------------------------------------------------------------- personaggi

func _usa_personaggio(i: int) -> void:
	var p: Dictionary = m.s["personaggi"][i]
	var pr: bool = p["promosso"]
	var esegui := func(opz: Dictionary):
		var esito := ""
		_istantanea()
		var turno: int = m.s["turno"]
		esito = m.usa(i, opz)
		if esito != "":
			storia.pop_back()
			lbl_info.text = esito
			aggiorna(false)
			lbl_info.text = esito
			return
		if int(m.s["turno"]) != turno or m.finita():
			storia.clear()
		aggiorna()
		salva()
	match p["id"]:
		"harper":
			var cand: Array = []
			for n in m.navi_cielo():
				var x := m.cella_cielo(n["r"], n["c"])
				if pr or (x.length() >= 2 and x[0] in ["E", "X"]):
					if int(n["r"]) >= 0:
						cand.append(n["id"])
			_seleziona({"tipo": "nave", "candidati": cand, "testo": "Clicca la nave da abbattere.", "fatto": func(sc): esegui.call({"nave": sc[0]})})
		"legrand", "bernstein", "izox" when not (p["id"] == "izox" and pr):
			var pe := Motore.personaggio(p["id"])
			if p["id"] == "bernstein":
				_finestra(pe["nome"], _lbl(pe["testo_p"] if pr else pe["testo"], 18), [
					["Energia e escavatore", func(): esegui.call({"scava": true})],
					["Solo energia", func(): esegui.call({"scava": false})], ["Annulla", func(): pass]])
			else:
				_finestra(pe["nome"], _lbl(pe["testo_p"] if pr else pe["testo"], 18), [["Usa", func(): esegui.call({})], ["Annulla", func(): pass]])
		"izox":
			var cand: Array = []
			for n in m.navi_cielo():
				if int(n["r"]) == int(m.s["M"]):
					cand.append(n["id"])
			if cand.is_empty():
				lbl_info.text = "Nessuna nave sui punti di sgancio."
				return
			_seleziona({"tipo": "nave", "candidati": cand, "testo": "Scegli la nave da togliere dal punto di sgancio.", "fatto": func(sc): esegui.call({"nave": sc[0]})})
		"moss", "aumann":
			_dialogo_dadi(i, pr, esegui)
		"ortego":
			var bt: Array = []
			for ro in m.s["robot"]:
				var rid: int = ro["id"]
				bt.append(["Robot %d: +%d" % [ro["v"], 2 if pr else 1], func(): esegui.call({"modo": "aumenta", "robot": rid})])
				if ro["esausto"] and not pr:
					bt.append(["Robot %d: non esaurito" % ro["v"], func(): esegui.call({"modo": "ricarica", "robot": rid})])
			if pr and not m.s["robot"].is_empty():
				bt.append(["Entrambi +1", func(): esegui.call({"modo": "entrambi"})])
				bt.append(["Tutti non esauriti", func(): esegui.call({"modo": "tutti"})])
			if bt.is_empty():
				lbl_info.text = "Non hai robot."
				return
			bt.append(["Annulla", func(): pass])
			_finestra("Lucía Ortego", _lbl("Cosa vuoi fare?", 18), bt)
		"ruzicka":
			if pr:
				_finestra("Jaroslav Růžička", _lbl("Tutti gli effetti delle stanze di questo turno avranno valore +1.", 18), [["Usa", func(): esegui.call({})], ["Annulla", func(): pass]])
			else:
				var bt: Array = []
				for t in Motore.TIPI_EFFETTO:
					bt.append([NOMI_EFFETTO[t], func(): esegui.call({"tipo": t})])
				_finestra("Jaroslav Růžička", _lbl("Scegli il tipo di stanza che avrà valore +1 in questo turno.", 18), bt)
		"almasi":
			_almasi(pr, [], esegui)
		"wanglin":
			var dopo := func(o: Dictionary):
				var cand: Array = []
				for cc in m.celle_robot_libere():
					if "ricerca" in m.tipi_stanza(m.stanza_di(cc[0], cc[1])):
						cand.append(cc)
				if cand.is_empty():
					esegui.call(o)
					return
				_seleziona({"tipo": "base", "candidati": cand, "testo": "Scegli lo spazio ricerca dove trasferire il dado.", "fatto": func(sc):
					o["dest"] = sc[0]
					esegui.call(o)})
			if pr:
				var cand: Array = []
				for k in m.stanze_attivabili():
					if "caccia" in m.effetti(k):
						for cc in m.s["stanze"][k]["celle"]:
							cand.append(cc)
				if cand.is_empty():
					lbl_info.text = "Serve una stanza dei caccia pronta da risolvere."
					return
				_seleziona({"tipo": "base", "candidati": cand, "testo": "Scegli la stanza dei caccia da risolvere con +3.", "fatto": func(sc):
					var st := m.stanza_di(sc[0][0], sc[0][1])
					var cand2: Array = []
					for cc in m.celle_robot_libere() + m.s["stanze"][st]["celle"]:
						if "ricerca" in m.tipi_stanza(m.stanza_di(cc[0], cc[1])) and not cc in cand2:
							cand2.append(cc)
					if cand2.is_empty():
						esegui.call({"stanza": st})
						return
					_seleziona({"tipo": "base", "candidati": cand2, "testo": "Scegli lo spazio ricerca dove trasferire il dado.", "fatto": func(sc2):
						esegui.call({"stanza": st, "dest": sc2[0]})})})
			else:
				dopo.call({})
		"jang":
			var cand: Array = []
			for n in m.navi_cielo():
				if int(n["r"]) >= int(m.s["M"]):
					cand.append(n["id"])
			_seleziona({"tipo": "nave", "candidati": cand, "multi": pr, "max": 1, "testo": "Scegli %s, poi la direzione." % ("fino a due navi e Conferma" if pr else "la nave"),
				"conferma": func(sc): _jang_dir(sc, pr, esegui), "fatto": func(sc): _jang_dir(sc, pr, esegui)})
		"bell":
			var cand := m.celle_robot_libere()
			_seleziona({"tipo": "base", "candidati": cand, "testo": "Scegli lo spazio del nuovo robot.", "fatto": func(sc): esegui.call({"robot_dest": sc[0]})})

func _jang_dir(sc: Array, pr: bool, esegui: Callable) -> void:
	if sc.is_empty() or sc.size() > 2:
		lbl_info.text = "Scegli una o due navi."
		aggiorna(false)
		return
	var bt: Array = [["Su", func(): esegui.call({"navi": sc, "dir": "su"})], ["Giù", func(): esegui.call({"navi": sc, "dir": "giu"})]]
	if pr:
		bt.append(["Sinistra", func(): esegui.call({"navi": sc, "dir": "sx"})])
		bt.append(["Destra", func(): esegui.call({"navi": sc, "dir": "dx"})])
	_finestra("Jang Chanwook", _lbl("In che direzione?", 18), bt)

func _almasi(pr: bool, fatti: Array, esegui: Callable) -> void:
	var cand: Array = []
	for d in m.s["dadi"]:
		if d["st"] == "piazzato" and not d["scavo"] and not m.sabotata(d["c"]):
			var gia := false
			for f in fatti:
				if f[0] == d["id"]:
					gia = true
			if not gia:
				cand.append([d["r"], d["c"]])
	_seleziona({"tipo": "base", "candidati": cand, "testo": "Scegli il dado da trasferire.", "fatto": func(sc):
		var d := m.lavoratore_in(sc[0][0], sc[0][1])
		var dest: Array = []
		for r in Motore.RIGHE_BASE:
			for c in Motore.COLONNE:
				if m.puo_trasferire(d["id"], r, c):
					var ok := true
					if not pr:
						ok = false
						for t in m.tipi_stanza(m.stanza_di(d["r"], d["c"])):
							if t in m.tipi_stanza(m.stanza_di(r, c)):
								ok = true
					for f in fatti:
						if f[1] == r and f[2] == c:
							ok = false
					if ok:
						dest.append([r, c])
		_seleziona({"tipo": "base", "candidati": dest, "testo": "Scegli lo spazio di arrivo.", "fatto": func(sc2):
			var tutti := fatti + [[d["id"], sc2[0][0], sc2[0][1]]]
			if pr and tutti.size() < 2:
				_finestra("Karima Almasi", _lbl("Vuoi trasferire un secondo dado?", 18), [
					["Sì", func(): _almasi(pr, tutti, esegui)], ["No, basta così", func(): esegui.call({"trasf": tutti})]])
			else:
				esegui.call({"trasf": tutti})})})

func _dialogo_dadi(i: int, pr: bool, esegui: Callable) -> void:
	var p: Dictionary = m.s["personaggi"][i]
	var box := VBoxContainer.new()
	var moss: bool = p["id"] == "moss"
	var pe := Motore.personaggio(p["id"])
	box.add_child(_lbl(pe["testo_p"] if pr else pe["testo"], 17, C_TENUE))
	var spin := {}
	for d in m.s["dadi"]:
		var ok: bool = d["st"] == "mano" or (moss and d["st"] == "piazzato" and not m.sabotata(d["c"]))
		if not ok:
			continue
		var h := HBoxContainer.new()
		h.add_child(_lbl("Dado %s %s %s" % [d["col"], "?" if d.get("fisso", false) else str(d["v"]), "(in mano)" if d["st"] == "mano" else "(colonna %d)" % (int(d["c"]) + 1)], 17))
		var sb := SpinBox.new()
		if moss:
			sb.min_value = 0
			sb.max_value = 2 if pr else 1
			sb.prefix = "+"
		else:
			sb.min_value = 0
			sb.max_value = 6
			sb.tooltip_text = "0 = non cambiare"
		h.add_child(sb)
		spin[d["id"]] = sb
		box.add_child(h)
	if not moss:
		box.add_child(_lbl("Scegli il nuovo valore (0 lascia il dado com'è).", 15, C_TENUE))
	_finestra(pe["nome"], box, [["Conferma", func():
		var o := {}
		if moss:
			var dist := {}
			for k in spin:
				if spin[k].value > 0:
					dist[k] = int(spin[k].value)
			o["dist"] = dist
		else:
			var vals := {}
			for k in spin:
				if spin[k].value > 0:
					vals[k] = int(spin[k].value)
			o["valori"] = vals
		esegui.call(o)], ["Annulla", func(): pass]])

# ---------------------------------------------------------------- vista 3D libera

func _apri_libera() -> void:
	libero = Control.new()
	libero.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(libero)
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	libero.add_child(cont)
	var sv := SubViewport.new()
	sv.msaa_3d = Viewport.MSAA_4X
	sv.world_3d = sv_cielo.find_world_3d()
	cont.add_child(sv)
	cam_libera = Camera3D.new()
	cam_libera.fov = 45
	sv.add_child(cam_libera)
	centro_libero = tav.aabb_tutto().get_center()
	orbita = Vector3(20.0, -48.0, 40.0)
	_aggiorna_orbita()
	cont.gui_input.connect(_input_libero)
	var b := _btn("Chiudi la vista 3D", func():
		libero.queue_free()
		libero = null, 18)
	b.position = Vector2(20, 20)
	libero.add_child(b)
	var l := _lbl("Trascina per ruotare · rotella per lo zoom · tasto destro per spostare", 16, C_TENUE)
	l.position = Vector2(20, 70)
	libero.add_child(l)

func _aggiorna_orbita() -> void:
	var yaw := deg_to_rad(orbita.x)
	var pitch := deg_to_rad(orbita.y)
	var off := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * orbita.z
	cam_libera.global_transform = Transform3D(Basis(), centro_libero + off).looking_at(centro_libero, Vector3.UP)

func _input_libero(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			orbita.z = max(6.0, orbita.z * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			orbita.z = min(90.0, orbita.z * 1.1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			trascina = "ruota" if e.pressed else ""
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			trascina = "sposta" if e.pressed else ""
		_aggiorna_orbita()
	elif e is InputEventMouseMotion:
		if trascina == "ruota":
			orbita.x -= e.relative.x * 0.3
			orbita.y = clamp(orbita.y - e.relative.y * 0.3, -88.0, -8.0)
		elif trascina == "sposta":
			var yaw := deg_to_rad(orbita.x)
			var dx := Vector3(cos(yaw), 0, -sin(yaw))
			var dz := Vector3(sin(yaw), 0, cos(yaw))
			centro_libero += (-dx * e.relative.x - dz * e.relative.y) * orbita.z * 0.002
		_aggiorna_orbita()
	elif e is InputEventMagnifyGesture:
		orbita.z = clamp(orbita.z / e.factor, 6.0, 90.0)
		_aggiorna_orbita()

# ---------------------------------------------------------------- fine partita

func _fine_partita() -> void:
	if finestra != null and is_instance_valid(finestra):
		return
	var vinta: bool = m.s["esito"] == "vittoria"
	var v := VBoxContainer.new()
	v.add_child(_lbl(m.s["motivo"], 20))
	v.add_child(_lbl("Turni giocati: %d · danni %d · ricerca %d/%d" % [m.s["turno"], m.s["danni"], m.s["ricerca"], m.s["traccia"].size() - 1], 17, C_TENUE))
	var bt: Array = []
	if tipo == "campagna":
		bt.append(["Continua la campagna", func():
			camp.esito(vinta)
			m = null
			schermo_campagna()
			salva(true)])
	else:
		bt.append(["Rigioca", func(): _avvia_singola(_cfg_rigioca())])
		bt.append(["Nuova partita", schermo_singola])
		bt.append(["Menu", menu])
		bt.append(["Guarda il tabellone", func(): pass])
	_finestra("Vittoria!" if vinta else "Sconfitta", v, bt)

func _cfg_rigioca() -> Dictionary:
	var c: Dictionary = m.s["cfg"].duplicate(true)
	c["seme"] = 0
	for p in c["personaggi"]:
		p.erase("usato")
	return c

func _esci() -> void:
	salva(true)
	menu()

# ---------------------------------------------------------------- prove automatiche (screenshot)

func prova_avvia(cfg: Dictionary) -> void:
	tipo = "singola"
	codice = "PROVA1"
	m = Motore.new()
	m.nuova(cfg)
	schermo_gioco()
