## Motore delle regole di Under Falling Skies (gioco base + campagna).
## Nessuna grafica: lo stato è un dizionario serializzabile in JSON (salvataggi su Firebase),
## l'interfaccia chiama le azioni e legge `s` ed `eventi` per animare.
class_name Motore
extends RefCounted

const COLONNE := 5
const RIGHE_BASE := 6
const TIPI_EFFETTO := ["energia", "ricerca", "caccia", "robot", "comando"]
const NOMI_TIPO := {"energia": "energetica", "ricerca": "ricerca", "caccia": "caccia", "robot": "robot",
	"comando": "comando", "aa": "cannone antiaereo"}

static var _dati = null

var s: Dictionary = {}
var eventi: Array = []
var rng := RandomNumberGenerator.new()

static func dati() -> Dictionary:
	if _dati == null:
		var f := FileAccess.open("res://data/ufs.json", FileAccess.READ)
		_dati = JSON.parse_string(f.get_as_text())
	return _dati

static func trova(lista: Array, id: String) -> Dictionary:
	for x in lista:
		if x["id"] == id:
			return x
	return {}

static func citta(id: String) -> Dictionary:
	return trova(dati()["citta"], id)

static func scenario(id: String) -> Dictionary:
	return trova(dati()["scenari"], id)

static func personaggio(id: String) -> Dictionary:
	return trova(dati()["personaggi"], id)

# ---------------------------------------------------------------- preparazione

## cfg: {citta, danneggiata, scenario, personaggi:[{id, promosso}], cielo:[{t, lato} x4 dall'alto], satellite, seme}
func nuova(cfg: Dictionary) -> void:
	var D := dati()
	var seme: int = int(cfg.get("seme", 0))
	if seme == 0:
		seme = randi() % 2000000000 + 1
	rng.seed = seme
	s = {"cfg": cfg.duplicate(true), "turno": 1, "fase": "dadi", "esito": "", "motivo": "", "log": [],
		"M": 0, "navi": [], "dadi": [], "robot": [], "prossimo_id": 1}
	s["cfg"]["seme"] = seme
	var scen: String = cfg.get("scenario", "")
	var sat: bool = cfg.get("satellite", false) or scen == "finale"
	s["cfg"]["satellite"] = sat
	# --- cielo
	var righe: Array = []
	if sat:
		var S: Dictionary = D["satellite"]
		for r in 2:
			righe.append({"celle": S["righe"][r].duplicate(), "azione": S["azioni"][r], "ricerca": int(S["ricerca"][r]),
				"vuoto": false, "blocco": -1})
	for i in cfg["cielo"].size():
		var ti: Dictionary = cfg["cielo"][i]
		var lato: Dictionary = D["cielo"][ti["t"]][int(ti["lato"])]
		for r in 4:
			var celle: Array = lato["righe"][r].duplicate()
			righe.append({"celle": celle, "azione": lato["azioni"][r], "ricerca": int(lato["ricerca"][r]),
				"vuoto": celle[0] == "V", "blocco": i})
	s["cielo"] = righe
	# --- tracciato ricerca: partenza, spazio città, righe dal basso verso l'alto
	var ct := citta(cfg["citta"])
	var dan: bool = cfg.get("danneggiata", false)
	var num: int = int(ct["num_d"] if dan else ct["num"])
	var tr: Array = [{"tipo": "start", "v": 0}]
	if num > 0:
		tr.append({"tipo": "citta", "v": num})
	for r in range(righe.size() - 1, -1, -1):
		if scen == "satelliti" and r == righe.size() - 1:
			continue
		tr.append({"tipo": "cielo", "v": righe[r]["ricerca"], "r": r})
	s["traccia"] = tr
	s["ricerca"] = 0
	# --- base
	var su: Dictionary = D["basi"][ct["su"] + "_su"]
	var giu: Dictionary = D["basi"][ct["giu"] + "_giu"]
	var stanze: Array = []
	var griglia: Array = []
	for r in RIGHE_BASE:
		var riga: Array = []
		for c in COLONNE:
			riga.append(-1)
		griglia.append(riga)
	for meta in [[su, 0], [giu, 3]]:
		for st in meta[0]["rooms"]:
			var celle: Array = []
			for cc in st["cells"]:
				celle.append([int(cc[0]) + meta[1], int(cc[1])])
				griglia[int(cc[0]) + meta[1]][int(cc[1])] = stanze.size()
			stanze.append({"t": st["t"].duplicate(), "celle": celle, "costo": int(st["cost"]), "mod": int(st["mod"])})
	s["stanze"] = stanze
	s["griglia"] = griglia
	s["percorso"] = _percorso()
	s["esc"] = _indice_percorso(int(su["esc"][0]), int(su["esc"][1]))
	s["esc_inizio"] = s["esc"]
	var en: Array = su["energia"] + giu["energia"]
	s["energia_valori"] = en
	s["energia_max"] = int(en[en.size() - 1])
	s["energia"] = int(su["start"])
	s["danni_su"] = int(su["danni"])
	s["danni_giu"] = int(giu["danni"])
	s["danni_limite"] = int(su["danni"]) + int(giu["danni"]) + 1
	s["danni"] = 4 if scen == "riparazione" else 0
	# --- personaggi
	var pers: Array = []
	for p in cfg.get("personaggi", []):
		pers.append({"id": p["id"], "promosso": bool(p.get("promosso", false)), "usato": false})
	s["personaggi"] = pers
	# --- navi
	for i in 5:
		_nuova_nave("viola", "cielo", 0, i)
	for i in 4:
		_nuova_nave("bianca", "riserva", -1, -1)
	if scen in ["ammiraglia", "kamikaze"]:
		var col := rng.randi_range(0, 4)
		for n in s["navi"]:
			if n["col"] == "viola" and n["c"] == col:
				n["col"] = "arancione"
	elif scen == "battaglia":
		_nuova_nave("arancione", "madre", -1, -1)
		_bianca_dalla_riserva(1)
	elif scen == "finale":
		# le navi viola partono dai punti di sgancio della nave madre, sopra il satellite
		s["M"] = -1
		for n in s["navi"]:
			if n["col"] == "viola":
				n["r"] = -1
		var cols := [0, 1, 2, 3, 4]
		for n in s["navi"]:
			if n["col"] == "bianca":
				var c: int = cols.pop_front()
				n["st"] = "cielo"; n["r"] = 0; n["c"] = c
		_nuova_nave("arancione", "cielo", 0, cols.pop_front())
	# --- dadi: 3 grigi e 2 bianchi
	for col in ["grigio", "grigio", "grigio", "bianco", "bianco"]:
		s["dadi"].append({"id": _id(), "col": col, "v": 1, "st": "mano", "r": -1, "c": -1, "scavo": false})
	# --- scenari
	var sc := {}
	match scen:
		"rinforzi":
			sc["pila"] = _mescolati([1, 2, 3, 4, 5, 6])
		"satelliti":
			var nums := _mescolati([1, 2, 3, 4, 5])
			var sats: Array = []
			for c in 5:
				sats.append([righe.size() - nums[c], c])
			sc["sat"] = sats
		"evacuazione":
			var t := _mescolati([1, 2, 3, 4, 5, 6])
			sc["citta"] = [t.pop_back()]
			var righe_t := {}
			for k in t.size():
				righe_t[str(k * 2 + 1)] = t[k]
			sc["righe"] = righe_t
		"reattore":
			sc["k"] = 0
		"riparazione":
			sc["gettoni"] = [3, 4, 5, 6]
			sc["usati"] = []
		"contaminazione":
			sc["pila"] = [6, 5, 4, 3, 2, 1]
			sc["celle"] = []
		"tempesta":
			sc["coperte"] = _tempesta_iniziale()
			sc["madre"] = 0
		"sabotatore":
			sc["pila"] = _mescolati([1, 2, 3, 4, 5])
			sc["col"] = -1
	s["sc"] = sc
	_log("Turno 1. Difendi %s%s." % [ct["nome"], " (danneggiata)" if dan else ""])
	_inizio_turno()

func _id() -> int:
	var i: int = s["prossimo_id"]
	s["prossimo_id"] = i + 1
	return i

func _nuova_nave(col: String, st: String, r: int, c: int) -> Dictionary:
	var n := {"id": _id(), "col": col, "st": st, "r": r, "c": c}
	s["navi"].append(n)
	return n

func _mescolati(a: Array) -> Array:
	var b := a.duplicate()
	for i in range(b.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = b[i]
		b[i] = b[j]
		b[j] = t
	return b

func _log(t: String) -> void:
	s["log"].append(t)
	if s["log"].size() > 400:
		s["log"].pop_front()
	eventi.append({"t": "log", "testo": t})

func carica(stato: Dictionary) -> void:
	s = stato
	rng.seed = int(s["cfg"]["seme"]) + int(s.get("tiri", 0))
	_normalizza(s)

## JSON trasforma gli interi in float: li riportiamo a interi dove servono.
static func _normalizza(x) -> void:
	if x is Dictionary:
		for k in x.keys():
			var v = x[k]
			if v is float and v == floor(v):
				x[k] = int(v)
			else:
				_normalizza(v)
	elif x is Array:
		for i in x.size():
			var v = x[i]
			if v is float and v == floor(v):
				x[i] = int(v)
			else:
				_normalizza(v)

func _d6() -> int:
	s["tiri"] = int(s.get("tiri", 0)) + 1
	return rng.randi_range(1, 6)

# ---------------------------------------------------------------- utilità di stato

func scen() -> String:
	return s["cfg"].get("scenario", "")

func citta_id() -> String:
	return s["cfg"]["citta"]

func danneggiata() -> bool:
	return s["cfg"].get("danneggiata", false)

func righe_cielo() -> int:
	return s["cielo"].size()

func finita() -> bool:
	return s["esito"] != ""

func _percorso() -> Array:
	var p: Array = []
	for r in RIGHE_BASE:
		if r % 2 == 0:
			for c in range(COLONNE - 1, -1, -1):
				p.append([r, c])
		else:
			for c in COLONNE:
				p.append([r, c])
	return p

func _indice_percorso(r: int, c: int) -> int:
	return r * COLONNE + (COLONNE - 1 - c if r % 2 == 0 else c)

func indice_percorso(r: int, c: int) -> int:
	return _indice_percorso(r, c)

func scavata(r: int, c: int) -> bool:
	return _indice_percorso(r, c) < int(s["esc"])

func stanza_di(r: int, c: int) -> int:
	return int(s["griglia"][r][c])

func tipi_stanza(i: int) -> Array:
	return s["stanze"][i]["t"] if i >= 0 else []

func e_aa(r: int, c: int) -> bool:
	return "aa" in tipi_stanza(stanza_di(r, c))

func dado(id: int) -> Dictionary:
	for d in s["dadi"]:
		if d["id"] == id:
			return d
	for d in s["robot"]:
		if d["id"] == id:
			return d
	return {}

func nave(id: int) -> Dictionary:
	for n in s["navi"]:
		if n["id"] == id:
			return n
	return {}

func e_robot(id: int) -> bool:
	for d in s["robot"]:
		if d["id"] == id:
			return true
	return false

func lavoratore_in(r: int, c: int) -> Dictionary:
	for d in s["dadi"]:
		if d["st"] == "piazzato" and d["r"] == r and d["c"] == c:
			return d
	return {}

func robot_in(r: int, c: int) -> Dictionary:
	for d in s["robot"]:
		if d["r"] == r and d["c"] == c:
			return d
	return {}

func cella_libera(r: int, c: int) -> bool:
	return lavoratore_in(r, c).is_empty() and robot_in(r, c).is_empty()

func cella_cielo(r: int, c: int) -> String:
	if r < 0 or r >= righe_cielo():
		return ""
	var x: String = s["cielo"][r]["celle"][c]
	if scen() == "tempesta" and [r, c] in s["sc"]["coperte"]:
		return ""
	return x

func nave_in(r: int, c: int) -> Dictionary:
	for n in s["navi"]:
		if n["st"] == "cielo" and n["r"] == r and n["c"] == c:
			return n
	return {}

func navi_cielo() -> Array:
	var a: Array = []
	for n in s["navi"]:
		if n["st"] == "cielo":
			a.append(n)
	return a

func navi_in_attesa() -> Array:
	var a: Array = []
	for n in s["navi"]:
		if n["st"] == "madre":
			a.append(n)
	return a

func _bianca_dalla_riserva(k: int) -> int:
	var fatte := 0
	for n in s["navi"]:
		if fatte >= k:
			break
		if n["col"] == "bianca" and n["st"] == "riserva":
			n["st"] = "madre"
			fatte += 1
	return fatte

func max_robot() -> int:
	if citta_id() == "newyork" and not danneggiata():
		return 1
	if citta_id() == "tokyo" and not danneggiata():
		return 1
	return 2

func ha_personaggio(id: String) -> int:
	for i in s["personaggi"].size():
		if s["personaggi"][i]["id"] == id:
			return i
	return -1

func sabotata(c: int) -> bool:
	return scen() == "sabotatore" and int(s["sc"].get("col", -1)) == c and s["fase"] == "stanze"

# ---------------------------------------------------------------- turno e fase dei dadi

func _inizio_turno() -> void:
	s["fase"] = "dadi"
	var t := {"scavo_usato": false, "esc_mosso": false, "energia_su": false, "primo": false,
		"bonus_tipo": {}, "bonus_tutti": 0, "cairo": false, "sydney": false, "rio": false, "stanze_iniziate": false,
		"caccia_abbattute": -1, "wang_bonus": false, "trattieni": false, "lavati": false, "pieter": false,
		"singapore": false, "rinforzi": 0}
	s["t"] = t
	var fisso_pechino := citta_id() == "pechino"
	var bloccato: bool = scen() == "rinforzi" and s["sc"]["pila"].size() > 0
	if bloccato:
		t["rinforzi"] = s["sc"]["pila"].pop_back()
		_log("Rinforzi: segnalino %d." % t["rinforzi"])
	var washington := citta_id() == "washington" and not danneggiata()
	for d in s["dadi"]:
		d["st"] = "mano"; d["r"] = -1; d["c"] = -1; d["scavo"] = false; d["fisso"] = false; d["sotto_esc"] = false
		if d["col"] == "grigio" and bloccato:
			d["st"] = "bloccato"
			bloccato = false
			continue
		if d["col"] == "grigio" and fisso_pechino:
			d["fisso"] = true
			d["v"] = 0
			fisso_pechino = false
			continue
		if d["col"] == "bianco" and washington:
			d["v"] = 6
			washington = false
			continue
		d["v"] = _d6()
	eventi.append({"t": "tiro"})

func dadi_in_mano() -> Array:
	var a: Array = []
	for d in s["dadi"]:
		if d["st"] == "mano":
			a.append(d)
	return a

func colonna_ha_lavoratore(c: int) -> bool:
	var giovanni := citta_id() == "johannesburg"
	for d in s["dadi"]:
		if d["st"] == "piazzato" and d["c"] == c:
			if giovanni and d["scavo"]:
				continue
			return true
	return false

## Restituisce "" se il dado può essere piazzato nella cella, altrimenti il motivo.
func perche_no(id: int, r: int, c: int) -> String:
	if s["fase"] != "dadi" or finita():
		return "Non è la Fase dei Dadi."
	var d := dado(id)
	if d.is_empty() or d.get("st", "") != "mano":
		return "Dado non disponibile."
	var v: int = int(d["v"])
	if d.get("fisso", false):
		if _valori_pechino().is_empty():
			return "Prima piazza un dado %s." % ("lavoratore" if danneggiata() else "grigio")
		v = 6
	if r < 0 or r >= RIGHE_BASE or c < 0 or c >= COLONNE:
		return "Fuori dalla base."
	var giovanni := citta_id() == "johannesburg"
	if scavata(r, c):
		if colonna_ha_lavoratore(c):
			return "In questa colonna c'è già un dado lavoratore."
		if not lavoratore_in(r, c).is_empty():
			return "Spazio occupato."
		return ""
	var dist := _indice_percorso(r, c) - int(s["esc"])
	if dist < 1:
		return "Spazio non scavato."
	if s["t"]["scavo_usato"]:
		return "Puoi piazzare un solo dado su uno spazio non scavato per turno."
	if colonna_ha_lavoratore(c) and not giovanni:
		return "In questa colonna c'è già un dado lavoratore."
	if d.get("fisso", false):
		var mx := 0
		for x in _valori_pechino():
			mx = max(mx, x)
		if dist > mx:
			return "Il dado non basta a raggiungere questo spazio."
		return ""
	if dist > v:
		return "Servono almeno %d punti per scavare fin qui." % dist
	return ""

func _valori_pechino() -> Array:
	var a: Array = []
	for d in s["dadi"]:
		if d["st"] == "piazzato" and (danneggiata() or d["col"] == "grigio"):
			if not int(d["v"]) in a:
				a.append(int(d["v"]))
	return a

func valori_pechino() -> Array:
	return _valori_pechino()

func celle_legali(id: int) -> Array:
	var a: Array = []
	for r in RIGHE_BASE:
		for c in COLONNE:
			if perche_no(id, r, c) == "":
				a.append([r, c])
	return a

## Piazza un dado lavoratore. `pechino`: valore da copiare per il dado fisso di Pechino.
func piazza(id: int, r: int, c: int, pechino: int = 0) -> bool:
	if perche_no(id, r, c) != "":
		return false
	eventi.clear()
	var d := dado(id)
	if d.get("fisso", false):
		var vals := _valori_pechino()
		if not pechino in vals:
			pechino = vals.max()
		d["v"] = pechino
		d["fisso"] = false
	var v: int = int(d["v"])
	var robo := robot_in(r, c)
	if not robo.is_empty():
		s["robot"].erase(robo)
		_log("Robot rimosso per far posto al dado.")
	d["st"] = "piazzato"; d["r"] = r; d["c"] = c
	d["scavo"] = not scavata(r, c)
	if d["scavo"]:
		s["t"]["scavo_usato"] = true
	_log("Dado %s %d nella colonna %d%s." % [d["col"], v, c + 1, " (scavo)" if d["scavo"] else ""])
	# contaminazione
	if scen() == "contaminazione":
		_contamina(r, c)
	# evacuazione: salva i civili
	var aa: bool = e_aa(r, c) and not d["scavo"]
	if scen() == "evacuazione" and aa:
		var ct: Array = s["sc"]["citta"]
		if v in ct:
			ct.erase(v)
			_log("Civili salvati (segnalino %d)." % v)
	# Città del Messico: lo scavo avanza subito
	if d["scavo"] and citta_id() == "messico":
		var dist := _indice_percorso(r, c) - int(s["esc"])
		if dist <= (5 if danneggiata() else 4):
			s["esc"] = _indice_percorso(r, c)
			s["t"]["esc_mosso"] = true
			d["sotto_esc"] = true
			_log("Città del Messico: l'escavatore avanza subito di %d." % dist)
	var passi := v - (1 if aa else 0)
	_scendi_colonna(c, passi, true)
	if finita():
		return true
	if d["col"] == "bianco":
		var nuovi: Array = []
		for x in s["dadi"]:
			if x["st"] == "mano" and not x.get("fisso", false):
				x["v"] = _d6()
				nuovi.append(str(x["v"]))
		if not nuovi.is_empty():
			_log("Dado bianco piazzato: rilancio dei dadi rimasti, escono %s." % ", ".join(nuovi))
			eventi.append({"t": "tiro"})
	if dadi_in_mano().is_empty():
		_fine_dadi()
	return true

func _contamina(r: int, c: int) -> void:
	var sc: Dictionary = s["sc"]
	for k in sc["celle"]:
		if k["r"] == r and k["c"] == c:
			_log("Spazio contaminato: la base subisce 1 danno.")
			_danno(1)
			break
	if s["t"]["primo"]:
		return
	s["t"]["primo"] = true
	if sc["pila"].size() > 0:
		var v: int = sc["pila"].pop_back()
		sc["celle"].append({"r": r, "c": c, "v": v, "su": true})
		_log("Contaminazione: segnalino %d sotto il primo dado." % v)
	else:
		var mi := -1
		for i in sc["celle"].size():
			var k: Dictionary = sc["celle"][i]
			if k["su"] and (mi < 0 or k["v"] < sc["celle"][mi]["v"]):
				mi = i
		if mi >= 0:
			var k: Dictionary = sc["celle"][mi]
			k["r"] = r; k["c"] = c; k["su"] = false
			_log("Contaminazione: il segnalino %d si sposta sotto il primo dado." % k["v"])

func _fine_dadi() -> void:
	var t: Dictionary = s["t"]
	if int(t["rinforzi"]) > 0:
		var vuote: Array = []
		for c in COLONNE:
			if not colonna_ha_lavoratore(c):
				vuote.append(c)
		if vuote.size() > 0:
			var migliore: int = vuote[0]
			var meno := 99
			for c in vuote:
				var k := 0
				for n in navi_cielo():
					if n["c"] == c:
						k += 1
				if k < meno:
					meno = k
					migliore = c
			_log("Rinforzi: le navi della colonna %d scendono di %d." % [migliore + 1, t["rinforzi"]])
			_scendi_colonna(migliore, int(t["rinforzi"]), true)
			if finita():
				return
	if scen() == "sabotatore":
		var pila: Array = s["sc"]["pila"]
		var col: int = pila.pop_back() - 1
		s["sc"]["col"] = col
		_log("Sabotatore: colonna %d sabotata." % (col + 1))
		var aa := false
		for d in s["dadi"]:
			if d["st"] == "piazzato" and d["c"] == col and e_aa(d["r"], d["c"]):
				aa = true
		if aa:
			_scendi_colonna(col, 1, false)
			if finita():
				return
	s["fase"] = "stanze"
	_log("Fase delle Stanze.")

# ---------------------------------------------------------------- movimento delle navi

func _scendi_colonna(c: int, passi: int, innesca: bool) -> void:
	if passi <= 0:
		return
	var lista: Array = []
	for n in s["navi"]:
		if n["st"] == "cielo" and n["c"] == c:
			lista.append(n)
	lista.sort_custom(func(a, b): return a["r"] < b["r"])
	var bloccate := {}
	for n in lista:
		var da: int = n["r"]
		var a: int = da + passi
		_attraversa(n, da, a)
		n["r"] = a
		eventi.append({"t": "muovi", "id": n["id"], "da": [da, c], "a": [a, c]})
		if scen() == "satelliti":
			for sat in s["sc"]["sat"].duplicate():
				if sat[1] == c and sat[0] > da and sat[0] <= a:
					s["sc"]["sat"].erase(sat)
					s["ricerca"] = max(0, int(s["ricerca"]) - 1)
					_log("Satellite distrutto: la ricerca arretra di 1.")
					if sat[0] == a:
						bloccate[n["id"]] = true
	for n in lista:
		if finita():
			return
		if n["st"] != "cielo":
			continue
		if _fuori_cielo(n["r"]):
			_colpisce(n)
		elif innesca and not bloccate.has(n["id"]):
			_effetto(n)

func _fuori_cielo(r: int) -> bool:
	return r >= righe_cielo() or s["cielo"][r]["vuoto"]

## Tempesta: i segnalini sugli spazi lasciati o attraversati tornano sulla nave madre.
func _attraversa(n: Dictionary, da: int, a: int) -> void:
	if scen() != "tempesta":
		return
	var cop: Array = s["sc"]["coperte"]
	for rr in range(da, a):
		var k := [rr, n["c"]]
		if k in cop:
			cop.erase(k)
			s["sc"]["madre"] = int(s["sc"]["madre"]) + 1
			_log("Tempesta: un segnalino torna sulla nave madre.")

func _effetto(n: Dictionary) -> void:
	var r: int = n["r"]
	var c: int = n["c"]
	var x := cella_cielo(r, c)
	match x:
		">", "<":
			var nc := c + (1 if x == ">" else -1)
			if nc >= 0 and nc < COLONNE and nave_in(r, nc).is_empty():
				if scen() == "tempesta" and [r, c] in s["sc"]["coperte"]:
					s["sc"]["coperte"].erase([r, c])
					s["sc"]["madre"] = int(s["sc"]["madre"]) + 1
				n["c"] = nc
				eventi.append({"t": "muovi", "id": n["id"], "da": [r, c], "a": [r, nc]})
		"M":
			_log("Una nave innesca la nave madre!")
			_madre_avanza(false)
		"Pp", "Pc":
			var b: int = s["cielo"][r]["blocco"]
			for rr in righe_cielo():
				if s["cielo"][rr]["blocco"] != b:
					continue
				for cc in COLONNE:
					if (rr != r or cc != c) and s["cielo"][rr]["celle"][cc] == x:
						if rr >= int(s["M"]) and nave_in(rr, cc).is_empty():
							n["r"] = rr
							n["c"] = cc
							eventi.append({"t": "tele", "id": n["id"], "da": [r, c], "a": [rr, cc]})
							_log("Teletrasporto!")
						return

func _colpisce(n: Dictionary) -> void:
	var dmg := 2 if (n["col"] == "arancione" and scen() == "kamikaze") else 1
	n["st"] = "madre"
	n["r"] = -1
	eventi.append({"t": "colpo", "id": n["id"], "c": n["c"]})
	_log("Una nave colpisce la città: %d dann%s." % [dmg, "o" if dmg == 1 else "i"])
	if scen() == "evacuazione":
		var k: int = s["sc"]["citta"].size()
		if k > 0:
			_log("Civili perduti: %d danni extra." % k)
			s["sc"]["citta"].clear()
			dmg += k
	_danno(dmg)

func _danno(k: int) -> void:
	if k <= 0 or finita():
		return
	var prima: int = s["danni"]
	s["danni"] = int(s["danni"]) + k
	eventi.append({"t": "danno"})
	if citta_id() == "roswell" and danneggiata() and prima == 0 and not s.get("roswell_fatto", false):
		s["roswell_fatto"] = true
		_log("Roswell: la ricerca avanza di 1 spazio.")
		_avanza_ricerca_libera(1)
	_controlla()

func soglia_danni() -> int:
	var lim: int = s["danni_limite"]
	if scen() == "reattore":
		lim -= max(0, int(s["sc"]["k"]) - 1)
	return lim

func _controlla() -> void:
	if finita():
		return
	if int(s["danni"]) >= soglia_danni():
		_fine("sconfitta", "La base è stata distrutta.")
	elif int(s["ricerca"]) >= s["traccia"].size() - 1:
		_fine("vittoria", "La ricerca è completa: hai respinto l'invasione!")

func _fine(esito: String, motivo: String) -> void:
	s["esito"] = esito
	s["motivo"] = motivo
	s["fase"] = "fine"
	_log(motivo)
	eventi.append({"t": "fine", "esito": esito})

func _abbatti(n: Dictionary) -> void:
	var r: int = n["r"]
	var c: int = n["c"]
	eventi.append({"t": "abbattuta", "id": n["id"], "pos": [r, c]})
	if n["col"] == "bianca" or (n["col"] == "arancione" and scen() == "finale"):
		n["st"] = "riserva"
	else:
		n["st"] = "madre"
	n["r"] = -1
	if scen() == "tempesta":
		var cop: Array = s["sc"]["coperte"]
		var preso := false
		for k in cop.duplicate():
			if k[1] == c:
				cop.erase(k)
				preso = true
				break
		if not preso and int(s["sc"]["madre"]) > 0:
			s["sc"]["madre"] = int(s["sc"]["madre"]) - 1
			preso = true
		if preso:
			cop.append([r, c])

# ---------------------------------------------------------------- ricerca

func _passi_ricerca(valore: int) -> int:
	var i: int = s["ricerca"]
	var tot := 0
	var p := 0
	var tr: Array = s["traccia"]
	while i + 1 < tr.size() and tot + int(tr[i + 1]["v"]) <= valore:
		i += 1
		tot += int(tr[i]["v"])
		p += 1
	return p

func passi_ricerca(valore: int) -> int:
	return _passi_ricerca(valore)

func _avanza_ricerca(passi: int) -> void:
	if passi <= 0:
		return
	s["ricerca"] = min(int(s["ricerca"]) + passi, s["traccia"].size() - 1)
	eventi.append({"t": "ricerca"})
	_log("Ricerca: avanzi di %d spazi%s." % [passi, "o" if passi == 1 else ""])
	if scen() == "pericolosa" and passi > 1:
		_log("Ricerca pericolosa: la base subisce 1 danno.")
		_danno(1)
	_controlla()

func _avanza_ricerca_libera(passi: int) -> void:
	s["ricerca"] = min(int(s["ricerca"]) + passi, s["traccia"].size() - 1)
	eventi.append({"t": "ricerca"})
	_controlla()

# ---------------------------------------------------------------- fase delle stanze

## Elenco dei dadi in una stanza (lavoratori piazzati non di scavo e robot non esauriti).
func dadi_stanza(i: int) -> Array:
	var a: Array = []
	for cc in s["stanze"][i]["celle"]:
		var w := lavoratore_in(cc[0], cc[1])
		if not w.is_empty() and not w["scavo"]:
			a.append(w)
			continue
		var ro := robot_in(cc[0], cc[1])
		if not ro.is_empty() and not ro["esausto"]:
			a.append(ro)
	return a

func stanza_piena(i: int) -> bool:
	var st: Dictionary = s["stanze"][i]
	return dadi_stanza(i).size() == st["celle"].size()

func ha_lavoratore(i: int) -> bool:
	for d in dadi_stanza(i):
		if not e_robot(d["id"]):
			return true
	return false

func valore_dado(d: Dictionary) -> int:
	var v: int = int(d["v"])
	if not e_robot(d["id"]) and sabotata(int(d["c"])):
		v -= 1
	return v

## Valore base della stanza (somma dei dadi + modificatore + bonus città).
func valore_stanza(i: int) -> int:
	var st: Dictionary = s["stanze"][i]
	var v: int = int(st["mod"])
	var robot := 0
	for d in dadi_stanza(i):
		v += valore_dado(d)
		if e_robot(d["id"]):
			robot += 1
	if citta_id() == "newyork" and robot > 0:
		v += robot if danneggiata() else 1
	return v

func valore_effetto(i: int, tipo: String) -> int:
	var v := valore_stanza(i) + int(s["t"]["bonus_tutti"]) + int(s["t"]["bonus_tipo"].get(tipo, 0))
	if tipo == "comando" and citta_id() == "mosca":
		v += 2 if danneggiata() else 1
	if tipo == "caccia" and s["t"]["wang_bonus"]:
		v += 3
	return v

func effetti(i: int) -> Array:
	var a: Array = []
	for t in tipi_stanza(i):
		if t in TIPI_EFFETTO:
			a.append(t)
	return a

func attivabile(i: int) -> String:
	if s["fase"] != "stanze" or finita():
		return "Non è la Fase delle Stanze."
	var st: Dictionary = s["stanze"][i]
	if effetti(i).is_empty():
		return "Questa stanza non ha effetti."
	if not stanza_piena(i):
		return "Tutti gli spazi della stanza devono avere un dado."
	if int(st["costo"]) > int(s["energia"]):
		return "Energia insufficiente (servono %d)." % st["costo"]
	return ""

func stanze_attivabili() -> Array:
	var a: Array = []
	for i in s["stanze"].size():
		if attivabile(i) == "":
			a.append(i)
	return a

## Risolve una stanza. opz: {ordine:[tipi], passi:int, robot_dest:[r,c], robot_rimuovi:id, comando:{id:n},
## parigi:id, rosse:bool}
func risolvi(i: int, opz: Dictionary = {}) -> bool:
	if attivabile(i) != "":
		return false
	eventi.clear()
	var st: Dictionary = s["stanze"][i]
	s["t"]["stanze_iniziate"] = true
	_paga(int(st["costo"]))
	var usati := dadi_stanza(i)
	var ordine: Array = opz.get("ordine", effetti(i))
	var valori := {}
	for t in effetti(i):
		valori[t] = max(0, valore_effetto(i, t))
	_log("Stanza %s di valore %d." % [_nome_stanza(i), valori.values().max()])
	_consuma(usati)
	for t in ordine:
		if finita():
			break
		_effetto_stanza(t, int(valori[t]), opz, usati)
	s["t"]["wang_bonus"] = false
	return true

func _nome_stanza(i: int) -> String:
	var n: Array = []
	for t in tipi_stanza(i):
		n.append(NOMI_TIPO.get(t, t))
	return "/".join(n)

func _paga(k: int) -> void:
	if k > 0:
		s["energia"] = int(s["energia"]) - k
		eventi.append({"t": "energia"})

## Rimuove i lavoratori usati e fa decrescere i robot usati.
func _consuma(usati: Array) -> void:
	var seul := 0
	if citta_id() == "seul":
		seul = 3 if danneggiata() else 2
	for d in usati:
		if e_robot(d["id"]):
			if citta_id() == "avana":
				s["robot"].erase(d)
				continue
			if int(d["v"]) <= seul:
				d["esausto"] = true
				continue
			d["v"] = int(d["v"]) - 1
			if int(d["v"]) <= 0:
				s["robot"].erase(d)
			else:
				d["esausto"] = true
		else:
			d["st"] = "usato"
	eventi.append({"t": "dadi"})

func _effetto_stanza(t: String, v: int, opz: Dictionary, usati: Array) -> void:
	match t:
		"energia":
			_energia(v)
		"ricerca":
			var p := _passi_ricerca(v)
			if opz.has("passi"):
				p = clamp(int(opz["passi"]), 0, p)
			if p == 0:
				var i: int = s["ricerca"]
				if i + 1 < s["traccia"].size():
					_log("Ricerca: valore %d insufficiente, il prossimo spazio costa %d." % [v, s["traccia"][i + 1]["v"]])
			_avanza_ricerca(p)
		"caccia":
			_caccia(v, opz)
		"robot":
			_assembla(clamp(v, 1, 6), opz, false)
		"comando":
			_comando(v, opz.get("comando", {}), usati)

func _energia(v: int) -> void:
	if v <= 0:
		return
	var prima: int = s["energia"]
	s["energia"] = min(int(s["energia"]) + v, int(s["energia_max"]))
	if int(s["energia"]) > prima:
		s["t"]["energia_su"] = true
	eventi.append({"t": "energia"})
	_log("Energia +%d (ora %d)." % [int(s["energia"]) - prima, s["energia"]])

func bersagli_caccia(v: int, rosse: bool) -> Array:
	var a: Array = []
	for n in navi_cielo():
		var x := cella_cielo(n["r"], n["c"])
		if x.length() >= 2 and (x[0] == "E" or x[0] == "X"):
			if (x[0] == "X") != rosse:
				continue
			if int(x.substr(1)) <= v:
				a.append(n)
	return a

func _caccia(v: int, opz: Dictionary) -> void:
	var rosse: bool = opz.get("rosse", false)
	if not opz.has("rosse"):
		rosse = bersagli_caccia(v, true).size() > bersagli_caccia(v, false).size()
	var bers := bersagli_caccia(v, rosse)
	# Londra: una nave in più su un'esplosione di poco più alta
	if citta_id() == "londra":
		var extra := 3 if danneggiata() else 1
		var migliore := {}
		for n in navi_cielo():
			if n in bers:
				continue
			var x := cella_cielo(n["r"], n["c"])
			if x.length() >= 2 and (x[0] == "E" or x[0] == "X") and ((x[0] == "X") == rosse):
				var k := int(x.substr(1))
				if k > v and k <= v + extra and (migliore.is_empty() or n["r"] > migliore["r"]):
					migliore = n
		if not migliore.is_empty():
			bers.append(migliore)
	for n in bers:
		_abbatti(n)
	s["t"]["caccia_abbattute"] = bers.size()
	_log("Caccia: %d navi abbattute." % bers.size())

func celle_robot_libere() -> Array:
	var a: Array = []
	for r in RIGHE_BASE:
		for c in COLONNE:
			var i := stanza_di(r, c)
			if i < 0 or not scavata(r, c) or "comando" in tipi_stanza(i):
				continue
			if cella_libera(r, c):
				a.append([r, c])
	return a

func _assembla(v: int, opz: Dictionary, non_esausto: bool) -> void:
	var dest = opz.get("robot_dest", null)
	var libere := celle_robot_libere()
	if s["robot"].size() >= max_robot():
		var rid: int = int(opz.get("robot_rimuovi", -1))
		var rimosso := false
		for ro in s["robot"]:
			if ro["id"] == rid:
				s["robot"].erase(ro)
				libere = celle_robot_libere()
				rimosso = true
				break
		if not rimosso:
			# di solito si ricicla il robot meno utile
			var peggiore := {}
			for ro in s["robot"]:
				if peggiore.is_empty() or int(ro["v"]) < int(peggiore["v"]):
					peggiore = ro
			if peggiore.is_empty() or int(peggiore["v"]) >= v:
				_log("Robot non assemblato: hai già il massimo di robot.")
				return
			s["robot"].erase(peggiore)
			libere = celle_robot_libere()
	if dest == null or not (dest in libere):
		if libere.is_empty():
			_log("Nessuno spazio libero per il robot.")
			return
		dest = _miglior_cella_robot(libere)
	var tokyo := citta_id() == "tokyo"
	var ro := {"id": _id(), "v": v, "r": int(dest[0]), "c": int(dest[1]), "esausto": not (non_esausto or tokyo)}
	s["robot"].append(ro)
	eventi.append({"t": "dadi"})
	_log("Robot di valore %d assemblato." % v)
	if citta_id() == "parigi":
		var pid: int = int(opz.get("parigi", -1))
		var bers := dado(pid)
		if bers.is_empty() or bers.get("st", "piazzato") != "piazzato" or bers == ro:
			bers = {}
			for d in s["dadi"]:
				if d["st"] == "piazzato" and not d["scavo"] and int(d["v"]) < 6 and not sabotata(d["c"]):
					bers = d
					break
		if not bers.is_empty() and (not e_robot(bers["id"]) or danneggiata()):
			bers["v"] = min(6, int(bers["v"]) + 1)
			_log("Parigi: un dado aumenta di 1.")

## Preferisce una cella in una stanza ricerca o caccia ancora vuota.
func _miglior_cella_robot(libere: Array) -> Array:
	var pref := ["ricerca", "caccia", "energia", "robot"]
	for t in pref:
		for cc in libere:
			var i := stanza_di(cc[0], cc[1])
			if t in tipi_stanza(i) and s["stanze"][i]["celle"].size() == 1:
				return cc
	return libere[0]

func _comando(v: int, distr: Dictionary, usati: Array) -> void:
	var resto := v
	var ids := []
	for k in distr.keys():
		ids.append(int(k))
	for id in ids:
		var d := dado(id)
		if d.is_empty() or e_robot(id) or d["st"] != "piazzato" or d["scavo"] or d in usati or sabotata(d["c"]):
			continue
		var k: int = min(int(distr.get(id, distr.get(str(id), 0))), resto, 6 - int(d["v"]))
		if k > 0:
			d["v"] = int(d["v"]) + k
			resto -= k
	if distr.is_empty():
		# distribuzione automatica: alza i dadi nelle stanze ricerca e caccia
		for d in s["dadi"]:
			if resto <= 0:
				break
			if d["st"] == "piazzato" and not d["scavo"] and not sabotata(d["c"]):
				var k: int = min(resto, 6 - int(d["v"]))
				d["v"] = int(d["v"]) + k
				resto -= k
	eventi.append({"t": "dadi"})
	_log("Comando: %d punti distribuiti." % (v - resto))

## Rimuove un dado senza effetto (anche i cannoni antiaerei e i cunicoli).
## opz: {avana: bool} per assemblare un robot esaurito (L'Avana).
func rimuovi(id: int, opz: Dictionary = {}) -> bool:
	if s["fase"] != "stanze":
		return false
	var d := dado(id)
	if d.is_empty() or e_robot(id) or d["st"] != "piazzato":
		return false
	eventi.clear()
	s["t"]["stanze_iniziate"] = true
	var r: int = d["r"]
	var c: int = d["c"]
	d["st"] = "usato"
	eventi.append({"t": "dadi"})
	if citta_id() == "avana" and opz.get("avana", false) and not d["scavo"] and stanza_di(r, c) >= 0 \
			and not "comando" in tipi_stanza(stanza_di(r, c)) and s["robot"].size() < max_robot():
		var v: int = min(6, int(d["v"]) + (1 if danneggiata() else 0))
		s["robot"].append({"id": _id(), "v": v, "r": r, "c": c, "esausto": true})
		_log("L'Avana: robot esaurito di valore %d assemblato." % v)
	return true

func puo_scavare(id: int) -> String:
	var d := dado(id)
	if s["fase"] != "stanze" or d.is_empty() or e_robot(id) or d["st"] != "piazzato" or not d["scavo"]:
		return "Non è un dado di scavo."
	if d.get("sotto_esc", false):
		return "L'escavatore è già avanzato."
	if s["t"]["pieter"]:
		return "Hai già fatto avanzare l'escavatore con Pieter Bernstein."
	if int(s["energia"]) < 1:
		return "Serve 1 energia."
	return ""

func scava(id: int) -> bool:
	if puo_scavare(id) != "":
		return false
	eventi.clear()
	s["t"]["stanze_iniziate"] = true
	var d := dado(id)
	_paga(1)
	var dest := _indice_percorso(d["r"], d["c"])
	var dist := dest - int(s["esc"])
	if sabotata(d["c"]) and int(d["v"]) == dist:
		dest -= 1
	if citta_id() == "johannesburg" and danneggiata():
		dest += 1
	_muovi_esc(dest - int(s["esc"]))
	d["st"] = "usato"
	eventi.append({"t": "dadi"})
	return true

func _muovi_esc(k: int) -> void:
	if k == 0:
		return
	var prima: int = s["esc"]
	s["esc"] = clamp(int(s["esc"]) + k, int(s["esc_inizio"]), RIGHE_BASE * COLONNE - 1)
	if int(s["esc"]) == prima:
		return
	if k > 0:
		s["t"]["esc_mosso"] = true
		_log("L'escavatore avanza di %d spazi." % (int(s["esc"]) - prima))
	else:
		_log("L'escavatore arretra di %d spazi." % (prima - int(s["esc"])))
		for ro in s["robot"].duplicate():
			if not scavata(ro["r"], ro["c"]):
				s["robot"].erase(ro)
				_log("Un robot resta sepolto.")
	eventi.append({"t": "esc"})

## Riparazione della base: un dado su un cunicolo scavato ripara 1 danno.
func puo_riparare(id: int) -> String:
	if scen() != "riparazione" or s["fase"] != "stanze":
		return "x"
	var d := dado(id)
	if d.is_empty() or e_robot(id) or d["st"] != "piazzato" or d["scavo"]:
		return "x"
	if stanza_di(d["r"], d["c"]) >= 0:
		return "Solo sui cunicoli."
	if [d["r"], d["c"]] in s["sc"]["usati"]:
		return "Cunicolo già usato."
	for g in s["sc"]["gettoni"]:
		if int(g) <= valore_dado(d):
			return ""
	return "Nessun segnalino di valore adatto."

func ripara(id: int) -> bool:
	if puo_riparare(id) != "":
		return false
	eventi.clear()
	var d := dado(id)
	var best := -1
	for g in s["sc"]["gettoni"]:
		if int(g) <= valore_dado(d) and int(g) > best:
			best = int(g)
	s["sc"]["gettoni"].erase(best)
	s["sc"]["usati"].append([d["r"], d["c"]])
	s["danni"] = max(0, int(s["danni"]) - 1)
	d["st"] = "usato"
	eventi.append({"t": "danno"})
	eventi.append({"t": "dadi"})
	_log("Base riparata (segnalino %d)." % best)
	return true

## Montreal: risolve insieme più stanze dello stesso tipo.
func risolvi_insieme(lista: Array, tipo: String, opz: Dictionary = {}) -> bool:
	if citta_id() != "montreal" or lista.size() < 2:
		return false
	var costo := 0
	for i in lista:
		if attivabile(i) != "" or not tipo in effetti(i):
			return false
		costo += int(s["stanze"][i]["costo"])
	if costo > int(s["energia"]):
		return false
	eventi.clear()
	s["t"]["stanze_iniziate"] = true
	_paga(costo)
	var tot := 1 if danneggiata() else 0
	var altri: Array = []
	var usati: Array = []
	for i in lista:
		tot += max(0, valore_effetto(i, tipo))
		for t in effetti(i):
			if t != tipo:
				altri.append([t, max(0, valore_effetto(i, t))])
		usati += dadi_stanza(i)
	_log("Montreal: %d stanze %s insieme, valore %d." % [lista.size(), NOMI_TIPO[tipo], tot])
	_consuma(usati)
	_effetto_stanza(tipo, tot, opz, usati)
	for a in altri:
		if not finita():
			_effetto_stanza(a[0], a[1], opz, usati)
	return true

## Trasferisce un dado lavoratore (o un robot) su un altro spazio libero e scavato.
func puo_trasferire(id: int, r: int, c: int) -> bool:
	var d := dado(id)
	if d.is_empty() or not scavata(r, c) or not cella_libera(r, c) or stanza_di(r, c) < 0:
		return false
	if e_robot(id):
		return not "comando" in tipi_stanza(stanza_di(r, c))
	if d["st"] != "piazzato" or d["scavo"] or sabotata(d["c"]):
		return false
	return true

func _trasferisci(id: int, r: int, c: int) -> void:
	var d := dado(id)
	eventi.append({"t": "trasf", "id": id, "da": [d["r"], d["c"]], "a": [r, c]})
	d["r"] = r
	d["c"] = c
	eventi.append({"t": "dadi"})

## Abilità di città che trasferiscono: cairo, sydney, singapore.
func trasferisci_citta(id: int, r: int, c: int) -> bool:
	if not puo_trasferire(id, r, c):
		return false
	var d := dado(id)
	var ok := false
	match citta_id():
		"cairo":
			if s["fase"] == "stanze" and not e_robot(id) and r != d["r"] and c == d["c"] and stanza_di(r, c) != stanza_di(d["r"], d["c"]):
				if danneggiata():
					ok = not s["t"]["cairo"]
				else:
					ok = not s["t"]["cairo"] and not s["t"]["stanze_iniziate"] and e_aa(d["r"], d["c"])
				if ok:
					s["t"]["cairo"] = true
		"sydney":
			if s["fase"] == "stanze" and not e_robot(id) and not s["t"]["sydney"] and "ricerca" in tipi_stanza(stanza_di(r, c)):
				ok = danneggiata() or int(d["v"]) <= 3
				if ok:
					s["t"]["sydney"] = true
		"singapore":
			if e_robot(id):
				if danneggiata():
					ok = not d["esausto"]
				else:
					ok = s["fase"] == "dadi" and dadi_in_mano().size() == _dadi_attivi()
	if not ok:
		return false
	eventi.clear()
	_trasferisci(id, r, c)
	_log("Dado trasferito.")
	return true

func _dadi_attivi() -> int:
	var k := 0
	for d in s["dadi"]:
		if d["st"] != "bloccato":
			k += 1
	return k

## Rio de Janeiro: la nave più in basso torna sulla nave madre.
func navi_rio() -> Array:
	var cand: Array = []
	var basso := -99
	for n in navi_cielo():
		if danneggiata():
			var x := cella_cielo(n["r"], n["c"])
			if x.length() >= 2 and (x[0] == "E" or x[0] == "X"):
				continue
		if n["r"] > basso:
			basso = n["r"]
			cand = [n]
		elif n["r"] == basso:
			cand.append(n)
	return cand

func rio(id: int = -1) -> bool:
	if citta_id() != "rio" or s["fase"] != "stanze" or s["t"]["rio"] or s["t"]["stanze_iniziate"]:
		return false
	var cand := navi_rio()
	if cand.is_empty():
		return false
	var n: Dictionary = cand[0]
	for x in cand:
		if x["id"] == id:
			n = x
	eventi.clear()
	s["t"]["rio"] = true
	n["st"] = "madre"
	eventi.append({"t": "ritorno", "id": n["id"], "pos": [n["r"], n["c"]]})
	n["r"] = -1
	_log("Rio de Janeiro: una nave torna sulla nave madre.")
	return true

## Washington danneggiata: subito dopo il tiro, un dado lavoratore a 6.
func washington(id: int) -> bool:
	if citta_id() != "washington" or not danneggiata() or s["fase"] != "dadi" or s["t"]["lavati"]:
		return false
	if dadi_in_mano().size() != _dadi_attivi():
		return false
	var d := dado(id)
	if d.is_empty() or d["st"] != "mano" or d.get("fisso", false):
		return false
	s["t"]["lavati"] = true
	d["v"] = 6
	eventi.clear()
	eventi.append({"t": "dadi"})
	_log("Washington: un dado impostato su 6.")
	return true

func fine_stanze() -> void:
	if s["fase"] != "stanze" or finita():
		return
	eventi.clear()
	for d in s["dadi"]:
		if d["st"] == "piazzato":
			d["st"] = "usato"
	for ro in s["robot"]:
		ro["esausto"] = false
	_fase_madre()

# ---------------------------------------------------------------- fase della nave madre

func _madre_avanza(azione: bool) -> void:
	var prima: int = s["M"]
	s["M"] = prima + 1
	var M: int = s["M"]
	eventi.append({"t": "madre"})
	# le navi sulla nuova riga tornano sulla nave madre...
	for n in s["navi"]:
		if n["st"] == "cielo" and int(n["r"]) == M:
			n["st"] = "madre"
			eventi.append({"t": "ritorno", "id": n["id"], "pos": [n["r"], n["c"]]})
			n["r"] = -1
		elif n["st"] == "fuori" and int(n.get("fuori_riga", 99)) <= M:
			n["st"] = "madre"
	# ...mentre quelle ancora sui punti di sgancio scendono insieme alla nave madre
	for n in s["navi"]:
		if n["st"] == "cielo" and int(n["r"]) <= prima:
			n["r"] = M
			eventi.append({"t": "muovi", "id": n["id"], "da": [prima, n["c"]], "a": [M, n["c"]]})
	if scen() == "evacuazione":
		var k := str(M)
		if s["sc"]["righe"].has(k):
			var v: int = s["sc"]["righe"][k]
			s["sc"]["righe"].erase(k)
			s["sc"]["citta"].append(v)
			_log("Evacuazione: nuovi civili da salvare (%d)." % v)
	if M >= righe_cielo():
		_fine("sconfitta", "La nave madre ha raggiunto la città.")
		return
	var az: String = s["cielo"][M]["azione"]
	if az == "K":
		_fine("sconfitta", "La nave madre ha raggiunto il teschio: la città è perduta.")
		return
	if azione:
		_azione(az)

func _azione(az: String) -> void:
	if az == "" or finita():
		return
	var k := int(az.substr(1)) if az.length() > 1 else 0
	match az[0]:
		"W":
			var f := _bianca_dalla_riserva(k)
			_log("Nave madre: %d nav%s bianc%s in arrivo." % [f, "e" if f == 1 else "i", "a" if f == 1 else "he"])
		"X":
			_log("Nave madre: l'escavatore arretra di %d." % (-k))
			_muovi_esc(k)
		"S":
			s["ricerca"] = max(0, int(s["ricerca"]) + k)
			eventi.append({"t": "ricerca"})
			_log("Nave madre: la ricerca arretra di %d." % (-k))
		"D":
			_log("Nave madre: la base subisce 1 danno.")
			_danno(1)
		"G":
			_log("Nave madre: tutte le navi scendono di %d." % k)
			for c in COLONNE:
				if finita():
					return
				_scendi_colonna(c, k, false)
		"K":
			_fine("sconfitta", "La città è perduta.")

func _fase_madre() -> void:
	s["fase"] = "madre"
	_log("Fase della Nave Madre.")
	_madre_avanza(true)
	if finita():
		return
	if scen() == "ammiraglia":
		for n in s["navi"]:
			if n["col"] == "arancione" and n["st"] == "cielo" and int(n["r"]) > int(s["M"]):
				var az: String = s["cielo"][n["r"]]["azione"]
				if az == "" or az == "K":
					_log("Nave ammiraglia: scende di 2 spazi.")
					var da: int = n["r"]
					var a := da
					for k in 2:
						if a + 1 < righe_cielo() and not _fuori_cielo(a + 1) and not nave_in(a + 1, n["c"]).is_empty():
							break
						a += 1
					n["r"] = a
					eventi.append({"t": "muovi", "id": n["id"], "da": [da, n["c"]], "a": [n["r"], n["c"]]})
					if _fuori_cielo(n["r"]):
						_colpisce(n)
				else:
					_log("Nave ammiraglia: risolvi anche l'azione della sua riga.")
					_azione(az)
	if finita():
		return
	_sgancio()
	_fine_turno()

func _sgancio() -> void:
	var M: int = s["M"]
	var coda: Array = []
	var ordine := ["arancione", "viola", "bianca"]
	if scen() == "finale":
		ordine = ["viola", "bianca", "arancione"]
	elif scen() == "battaglia":
		ordine = ["viola", "arancione", "bianca"]
	for col in ordine:
		for n in s["navi"]:
			if n["st"] == "madre" and n["col"] == col:
				coda.append(n)
	if s["t"]["trattieni"] and coda.size() > 0:
		var tenuta: Dictionary = coda.pop_front()
		_log("Iz'ox: una nave non viene sganciata.")
		s["t"]["trattieni"] = false
		tenuta["trattenuta"] = true
	while coda.size() > 0:
		var n: Dictionary = coda.pop_front()
		if n["col"] == "arancione" and scen() == "kamikaze":
			var bassa := {}
			for x in navi_cielo():
				if x["col"] == "viola" and int(x["r"]) > M and (bassa.is_empty() or int(x["r"]) > int(bassa["r"])):
					bassa = x
			if not bassa.is_empty():
				n["st"] = "cielo"; n["r"] = bassa["r"]; n["c"] = bassa["c"]
				bassa["st"] = "madre"; bassa["r"] = -1
				eventi.append({"t": "sgancio", "id": n["id"]})
				_log("Nave kamikaze: prende il posto della nave viola più bassa.")
				coda.push_front(bassa)
				continue
		var c := _colonna_sgancio()
		if c < 0:
			break
		n["st"] = "cielo"
		n["r"] = M
		n["c"] = c
		eventi.append({"t": "sgancio", "id": n["id"]})

func _colonna_sgancio() -> int:
	var M: int = s["M"]
	var libere: Array = []
	for c in COLONNE:
		if nave_in(M, c).is_empty():
			libere.append(c)
	if libere.is_empty():
		return -1
	var vuote: Array = []
	for c in libere:
		var k := 0
		for n in navi_cielo():
			if n["c"] == c:
				k += 1
		if k == 0:
			vuote.append(c)
	if vuote.size() > 0:
		return vuote[rng.randi_range(0, vuote.size() - 1)]
	var miglior := -1
	var cand: Array = []
	for c in libere:
		var alta := 999
		for n in navi_cielo():
			if n["c"] == c:
				alta = min(alta, int(n["r"]))
		if alta > miglior:
			miglior = alta
			cand = [c]
		elif alta == miglior:
			cand.append(c)
	return cand[rng.randi_range(0, cand.size() - 1)]

func _fine_turno() -> void:
	for n in s["navi"]:
		n.erase("trattenuta")
	if scen() == "reattore":
		var k: int = s["sc"]["k"]
		if s["t"]["energia_su"]:
			k = min(k + 1, 6)
			_log("Perdita nel reattore: un segnalino sul tracciato danni.")
		elif k > 0:
			k -= 1
			_log("Perdita nel reattore: un segnalino torna via.")
		s["sc"]["k"] = k
		_controlla()
		if finita():
			return
	if scen() == "sabotatore":
		s["sc"]["col"] = -1
		if s["sc"]["pila"].size() <= 1:
			s["sc"]["pila"] = _mescolati([1, 2, 3, 4, 5])
	s["turno"] = int(s["turno"]) + 1
	_log("Turno %d." % s["turno"])
	_inizio_turno()

# ---------------------------------------------------------------- personaggi

func puo_usare(i: int) -> String:
	if finita():
		return "Partita finita."
	var p: Dictionary = s["personaggi"][i]
	if p["usato"]:
		return "Abilità già usata in questa partita."
	var f: String = s["fase"]
	match p["id"]:
		"aumann":
			if f != "dadi" or dadi_in_mano().is_empty():
				return "Si usa nella Fase dei Dadi su dadi non ancora piazzati."
		"almasi", "bernstein", "wanglin":
			if f != "stanze":
				return "Si usa nella Fase delle Stanze."
			if p["id"] == "wanglin" and not p["promosso"] and int(s["t"]["caccia_abbattute"]) < 0:
				return "Prima risolvi un effetto dei caccia."
			if p["id"] == "bernstein" and s["t"]["esc_mosso"]:
				return "L'escavatore si è già mosso in questo turno."
		_:
			if f != "dadi" and f != "stanze":
				return "Non ora."
	return ""

## opz dipende dal personaggio (vedi interfaccia). Restituisce "" se riuscito, altrimenti il motivo.
func usa(i: int, opz: Dictionary) -> String:
	var perche := puo_usare(i)
	if perche != "":
		return perche
	var p: Dictionary = s["personaggi"][i]
	var pr: bool = p["promosso"]
	eventi.clear()
	var esito := ""
	match p["id"]:
		"moss":
			var dist: Dictionary = opz.get("dist", {})
			var tot := 0
			for k in dist.keys():
				var d := dado(int(k))
				var q: int = int(dist[k])
				if d.is_empty() or e_robot(int(k)) or not d["st"] in ["mano", "piazzato"] or q < 0:
					return "Dado non valido."
				if d["st"] == "piazzato" and sabotata(d["c"]):
					return "I dadi nella colonna sabotata non possono essere aumentati."
				if not pr and q > 1:
					return "Ogni dado aumenta di 1."
				tot += q
			if (not pr and (tot != 2 and not (tot == 1 and _dadi_aumentabili() == 1))) or tot > 3 or tot == 0:
				return "Scegli due dadi diversi." if not pr else "Al massimo 3 punti."
			for k in dist.keys():
				var d := dado(int(k))
				d["v"] = min(6, int(d["v"]) + int(dist[k]))
			eventi.append({"t": "dadi"})
		"harper":
			var n := nave(int(opz.get("nave", -1)))
			if n.is_empty() or n["st"] != "cielo":
				return "Scegli una nave nel cielo."
			var x := cella_cielo(n["r"], n["c"])
			if not pr and not (x.length() >= 2 and (x[0] == "E" or x[0] == "X")):
				return "La nave deve trovarsi su uno spazio esplosione."
			_abbatti(n)
		"legrand":
			var p2 := 0
			var tr: Array = s["traccia"]
			var idx: int = s["ricerca"]
			if pr:
				p2 = _passi_ricerca(6)
			elif idx + 1 < tr.size() and int(tr[idx + 1]["v"]) <= 3:
				p2 = 1
			if p2 == 0:
				return "Lo spazio successivo costa troppo."
			_avanza_ricerca(p2)
		"ortego":
			var modo: String = opz.get("modo", "")
			var ro := dado(int(opz.get("robot", -1)))
			match modo:
				"aumenta":
					if ro.is_empty() or not e_robot(ro["id"]):
						return "Scegli un robot."
					ro["v"] = min(6, int(ro["v"]) + (2 if pr else 1))
				"ricarica":
					if ro.is_empty() or not e_robot(ro["id"]):
						return "Scegli un robot."
					ro["esausto"] = false
				"entrambi":
					if not pr or s["robot"].is_empty():
						return "Non disponibile."
					for x in s["robot"]:
						x["v"] = min(6, int(x["v"]) + 1)
				"tutti":
					if not pr or s["robot"].is_empty():
						return "Non disponibile."
					for x in s["robot"]:
						x["esausto"] = false
				_:
					return "Scegli cosa fare."
			eventi.append({"t": "dadi"})
		"aumann":
			var vals: Dictionary = opz.get("valori", {})
			if vals.is_empty() or vals.size() > (3 if pr else 1):
				return "Scegli %s." % ("fino a 3 dadi" if pr else "un dado")
			for k in vals.keys():
				var d := dado(int(k))
				if d.is_empty() or d["st"] != "mano":
					return "Solo dadi non ancora piazzati."
			for k in vals.keys():
				var d := dado(int(k))
				d["v"] = clamp(int(vals[k]), 1, 6)
				d["fisso"] = false
			eventi.append({"t": "dadi"})
		"almasi":
			var lista: Array = opz.get("trasf", [])
			if lista.is_empty() or lista.size() > (2 if pr else 1):
				return "Scegli un trasferimento."
			for tr2 in lista:
				var d := dado(int(tr2[0]))
				if d.is_empty() or e_robot(d["id"]) or not puo_trasferire(d["id"], int(tr2[1]), int(tr2[2])):
					return "Trasferimento non valido."
				if not pr:
					var a := tipi_stanza(stanza_di(d["r"], d["c"]))
					var b := tipi_stanza(stanza_di(int(tr2[1]), int(tr2[2])))
					var comune := false
					for t in a:
						if t in b:
							comune = true
					if not comune:
						return "Lo spazio deve essere dello stesso tipo."
			for tr2 in lista:
				_trasferisci(int(tr2[0]), int(tr2[1]), int(tr2[2]))
		"ruzicka":
			if pr:
				s["t"]["bonus_tutti"] = int(s["t"]["bonus_tutti"]) + 1
			else:
				var tipo: String = opz.get("tipo", "")
				if not tipo in TIPI_EFFETTO:
					return "Scegli un tipo di stanza."
				s["t"]["bonus_tipo"][tipo] = int(s["t"]["bonus_tipo"].get(tipo, 0)) + 1
		"bernstein":
			_energia(2 if pr else 1)
			if opz.get("scava", true):
				_muovi_esc(4 if pr else 2)
				s["t"]["pieter"] = true
		"wanglin":
			var dest = opz.get("dest", null)
			if pr:
				var st := int(opz.get("stanza", -1))
				if st < 0 or attivabile(st) != "" or not "caccia" in effetti(st):
					return "Scegli una stanza dei caccia pronta."
				s["t"]["wang_bonus"] = true
				risolvi(st, opz)
			var k: int = s["t"]["caccia_abbattute"]
			if k > 0 and dest != null and stanza_di(dest[0], dest[1]) >= 0 and "ricerca" in tipi_stanza(stanza_di(dest[0], dest[1])) \
					and scavata(dest[0], dest[1]) and cella_libera(dest[0], dest[1]):
				for d in s["dadi"]:
					if d["st"] == "usato":
						d["st"] = "piazzato"; d["r"] = int(dest[0]); d["c"] = int(dest[1]); d["v"] = min(6, k); d["scavo"] = false
						_log("Wang Lin: un dado di valore %d passa nella ricerca." % min(6, k))
						break
			eventi.append({"t": "dadi"})
		"izox":
			if pr:
				var n := nave(int(opz.get("nave", -1)))
				if n.is_empty() or n["st"] != "cielo" or int(n["r"]) != int(s["M"]):
					return "Scegli una nave su un punto di sgancio."
				n["st"] = "fuori"
				n["fuori_riga"] = int(s["M"]) + 2
				n["r"] = -1
				eventi.append({"t": "ritorno", "id": n["id"], "pos": [s["M"], n["c"]]})
			else:
				s["t"]["trattieni"] = true
		"jang":
			var ids: Array = opz.get("navi", [])
			var dir: String = opz.get("dir", "giu")
			if ids.is_empty() or ids.size() > (2 if pr else 1):
				return "Scegli %s." % ("fino a due navi" if pr else "una nave")
			if not pr and not dir in ["su", "giu"]:
				return "Solo in alto o in basso."
			var dr: int = {"su": -1, "giu": 1, "sx": 0, "dx": 0}[dir]
			var dc: int = {"su": 0, "giu": 0, "sx": -1, "dx": 1}[dir]
			for id in ids:
				var n := nave(int(id))
				if n.is_empty() or n["st"] != "cielo":
					return "Nave non valida."
				var nr: int = int(n["r"]) + dr
				var nc: int = int(n["c"]) + dc
				if nr < int(s["M"]) or _fuori_cielo(nr) or nc < 0 or nc >= COLONNE or not nave_in(nr, nc).is_empty():
					return "Spazio non disponibile."
			for id in ids:
				var n := nave(int(id))
				var da := [n["r"], n["c"]]
				n["r"] = int(n["r"]) + dr
				n["c"] = int(n["c"]) + dc
				eventi.append({"t": "muovi", "id": n["id"], "da": da, "a": [n["r"], n["c"]]})
		"bell":
			if s["robot"].size() >= max_robot() and int(opz.get("robot_rimuovi", -1)) < 0:
				var peggiore := {}
				for ro in s["robot"]:
					if peggiore.is_empty() or int(ro["v"]) < int(peggiore["v"]):
						peggiore = ro
				opz["robot_rimuovi"] = peggiore.get("id", -1)
			_assembla(4 if pr else 3, opz, true)
	p["usato"] = true
	_log("%s usa la sua abilità." % personaggio(p["id"])["nome"])
	_controlla()
	return esito

func _dadi_aumentabili() -> int:
	var k := 0
	for d in s["dadi"]:
		if d["st"] in ["mano", "piazzato"]:
			k += 1
	return k

# ---------------------------------------------------------------- tempesta

func _tempesta_iniziale() -> Array:
	var cop: Array = []
	for c in COLONNE:
		var best := []
		var bv := 99
		for r in s["cielo"].size():
			var x: String = s["cielo"][r]["celle"][c]
			if x.length() >= 2 and (x[0] == "E" or x[0] == "X"):
				var v := int(x.substr(1))
				if v < bv or (v == bv):
					bv = v
					best = [r, c]
		if not best.is_empty():
			cop.append(best)
	return cop

# ---------------------------------------------------------------- difficoltà

## Livello di difficoltà come nel regolamento: stelle nere meno stelle gialle.
static func difficolta(cfg: Dictionary) -> float:
	var D := dati()
	var nere := 0.0
	for ti in cfg.get("cielo", []):
		nere += float(D["cielo"][ti["t"]][int(ti["lato"])]["stelle"])
	if cfg.get("scenario", "") != "":
		nere += 1
	var gialle := 0.0
	if cfg.get("danneggiata", false):
		gialle += 0.5
	for p in cfg.get("personaggi", []):
		gialle += 1.0 if p.get("promosso", false) else 0.5
	return nere - gialle
