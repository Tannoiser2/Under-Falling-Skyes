## Giocatore automatico semplice: serve per le partite di prova e per il suggerimento.
class_name IA
extends RefCounted

var m: Motore

func _init(motore: Motore) -> void:
	m = motore

## Valuta il piazzamento di un dado in una cella (più alto = meglio).
func punteggio(id: int, r: int, c: int) -> float:
	var s := m.s
	var d := m.dado(id)
	var v: int = int(d["v"])
	if d.get("fisso", false):
		v = m.valori_pechino().max() if not m.valori_pechino().is_empty() else 1
	var scav := m.scavata(r, c)
	var aa := m.e_aa(r, c) and scav
	var passi := v - (1 if aa else 0)
	var p := 0.0
	var N := m.righe_cielo()
	for n in m.navi_cielo():
		if n["c"] != c:
			continue
		var nr: int = int(n["r"]) + passi
		if nr >= N or s["cielo"][min(nr, N - 1)]["vuoto"]:
			p -= 60.0
			continue
		var x := m.cella_cielo(nr, c)
		if x == "M":
			p -= 18.0
		elif x.length() >= 2 and (x[0] == "E" or x[0] == "X"):
			p += 6.0 - float(int(x.substr(1)))
		p -= float(passi) * (1.0 + float(nr) / float(N)) * 1.2
	if not scav:
		return p + (10.0 if int(s["energia"]) >= 1 else -5.0)
	var i := m.stanza_di(r, c)
	if i < 0:
		return p - 2.0
	var st: Dictionary = s["stanze"][i]
	var costo: int = int(st["costo"])
	var en := _energia_prevista()
	if costo > en and not "energia" in st["t"]:
		return p - 25.0
	if st["celle"].size() > 1:
		var vuote := 0
		for cc in st["celle"]:
			if m.cella_libera(cc[0], cc[1]) and not (cc[0] == r and cc[1] == c):
				vuote += 1
		if vuote > 0 and m.dadi_in_mano().size() <= vuote:
			return p - 25.0
	var val := float(v + int(st["mod"]))
	for t in st["t"]:
		match t:
			"aa":
				p += 4.0 if passi < v else 0.0
			"ricerca":
				p += val * 2.4 - float(costo) * 0.8
				if st["celle"].size() > 1:
					p += 3.0
			"caccia":
				var k := 0
				for n in m.navi_cielo():
					var x := m.cella_cielo(n["r"], n["c"])
					if x.length() >= 2 and x[0] in ["E", "X"] and int(x.substr(1)) <= int(val) + 1:
						k += 1
				p += float(k) * 7.0 + val * 0.5 - float(costo)
			"energia":
				p += val * (3.0 if en < 3 else 0.8)
			"robot":
				p += val * 1.2 - float(costo)
			"comando":
				p += val * 0.9 - float(costo)
	return p

func _energia_prevista() -> int:
	var en: int = int(m.s["energia"])
	for i in m.s["stanze"].size():
		var st: Dictionary = m.s["stanze"][i]
		var pieno := true
		var val: int = int(st["mod"])
		for cc in st["celle"]:
			var w := m.lavoratore_in(cc[0], cc[1])
			if w.is_empty():
				pieno = false
			else:
				val += int(w["v"])
		if pieno:
			if "energia" in st["t"]:
				en += max(0, val)
			en -= int(st["costo"])
	return en

## Mossa rapida: solo euristica.
func mossa_veloce() -> Array:
	var best := []
	var bp := -1e9
	for d in m.dadi_in_mano():
		for cc in m.celle_legali(d["id"]):
			var p := punteggio(d["id"], cc[0], cc[1])
			if p > bp:
				bp = p
				best = [d["id"], cc[0], cc[1]]
	return best

## Mossa ragionata: prova le migliori candidate giocando il resto del turno in modo rapido.
func mossa_dadi(candidati := 10) -> Array:
	var lista: Array = []
	for d in m.dadi_in_mano():
		for cc in m.celle_legali(d["id"]):
			lista.append([punteggio(d["id"], cc[0], cc[1]), d["id"], cc[0], cc[1]])
	if lista.is_empty():
		return []
	lista.sort_custom(func(a, b): return a[0] > b[0])
	var testo := JSON.stringify(m.s)
	var best := []
	var bp := -1e18
	for k in min(candidati, lista.size()):
		var mv: Array = lista[k]
		var prova := Motore.new()
		prova.carica(JSON.parse_string(testo))
		prova.rng.seed = 777 + k
		prova.piazza(mv[1], mv[2], mv[3])
		var ia2 := IA.new(prova)
		var g := 0
		while prova.s["fase"] == "dadi" and g < 10:
			g += 1
			var mv2 := ia2.mossa_veloce()
			if mv2.is_empty():
				break
			prova.piazza(mv2[0], mv2[1], mv2[2])
		if prova.s["fase"] == "stanze":
			ia2.gioca_stanze(false, false)
		var p: float = valuta(prova) + float(mv[0]) * 0.05
		if p > bp:
			bp = p
			best = [mv[1], mv[2], mv[3]]
	return best

## Valutazione di uno stato (più alto = meglio).
static func valuta(x: Motore) -> float:
	var s := x.s
	if s["esito"] == "sconfitta":
		return -10000.0
	if s["esito"] == "vittoria":
		return 10000.0
	var N := x.righe_cielo()
	var v := float(s["ricerca"]) * 14.0 - float(s["danni"]) * 16.0 + float(min(int(s["energia"]), 6)) * 3.5 + float(s["esc"]) * 1.5
	v -= float(s["M"]) * 6.0
	for n in x.navi_cielo():
		var f := float(n["r"]) / float(N)
		var cc := x.cella_cielo(n["r"], n["c"])
		v -= f * f * 10.0
		if cc == "M":
			v -= 4.0
	# stanze già complete: cosa produrranno
	var en := int(s["energia"])
	for i in s["stanze"].size():
		var st: Dictionary = s["stanze"][i]
		if x.effetti(i).is_empty():
			continue
		var pieno := true
		var lav := false
		for c in st["celle"]:
			var w := x.lavoratore_in(c[0], c[1])
			if w.is_empty() or w["scavo"]:
				if x.robot_in(c[0], c[1]).is_empty():
					pieno = false
			else:
				lav = true
		if not pieno or not lav:
			continue
		var val := x.valore_stanza(i)
		for t in st["t"]:
			match t:
				"energia":
					v += float(min(val, int(s["energia_max"]) - int(s["energia"]))) * 3.0
					en += val
				"ricerca":
					v += float(x.passi_ricerca(val)) * 12.0 - float(st["costo"]) * 1.2
				"caccia":
					var k := 0.0
					for n in x.navi_cielo():
						var e := x.cella_cielo(n["r"], n["c"])
						if e.length() >= 2 and e[0] in ["E", "X"] and int(e.substr(1)) <= val:
							k += 1.0 + float(n["r"]) / float(N) * 3.0
					v += k * 5.0 - float(st["costo"]) * 1.0
				"robot":
					v += float(min(val, 6)) * 1.8 - float(st["costo"])
				"comando":
					v += float(val) * 1.0 - float(st["costo"])
		en -= int(st["costo"])
	for d in s["dadi"]:
		if d["st"] == "piazzato" and d["scavo"]:
			v += 4.0
			en -= 1
	if en < 0:
		v += float(en) * 6.0
	return v

## Gioca la Fase delle Stanze per intero.
func gioca_stanze(personaggi := true, chiudi := true) -> void:
	var guardia := 0
	while m.s["fase"] == "stanze" and guardia < 60:
		guardia += 1
		if m.citta_id() == "rio" and not m.s["t"]["rio"] and not m.s["t"]["stanze_iniziate"]:
			if m.rio():
				continue
		if personaggi and _usa_personaggio():
			continue
		var fatto := false
		for pref in ["energia", "comando", "caccia", "ricerca", "robot"]:
			for i in m.stanze_attivabili():
				if pref in m.effetti(i):
					var opz := {}
					if "comando" in m.effetti(i):
						opz["comando"] = {}
					m.risolvi(i, opz)
					fatto = true
					break
			if fatto:
				break
		if fatto:
			continue
		for d in m.s["dadi"]:
			if d["st"] == "piazzato" and m.puo_scavare(d["id"]) == "":
				m.scava(d["id"])
				fatto = true
				break
			if d["st"] == "piazzato" and m.puo_riparare(d["id"]) == "":
				m.ripara(d["id"])
				fatto = true
				break
		if fatto:
			continue
		break
	if m.s["fase"] == "stanze" and chiudi:
		m.fine_stanze()

func _usa_personaggio() -> bool:
	for i in m.s["personaggi"].size():
		if m.puo_usare(i) != "":
			continue
		var p: Dictionary = m.s["personaggi"][i]
		var opz := {}
		match p["id"]:
			"harper":
				var navi := m.navi_cielo()
				navi.sort_custom(func(a, b): return a["r"] > b["r"])
				for n in navi:
					var x := m.cella_cielo(n["r"], n["c"])
					if p["promosso"] or (x.length() >= 2 and x[0] in ["E", "X"]):
						if int(n["r"]) >= m.righe_cielo() - 4:
							opz["nave"] = n["id"]
							break
				if not opz.has("nave"):
					continue
			"moss":
				var ids: Array = []
				for d in m.s["dadi"]:
					if d["st"] == "piazzato" and not d["scavo"] and int(d["v"]) < 6:
						ids.append(d["id"])
				if ids.size() < 2:
					continue
				opz["dist"] = {ids[0]: 1, ids[1]: 1} if not p["promosso"] else {ids[0]: 2, ids[1]: 1}
			"ortego":
				if m.s["robot"].is_empty():
					continue
				opz = {"modo": "aumenta", "robot": m.s["robot"][0]["id"]}
			"almasi", "aumann", "jang":
				continue
			"wanglin":
				if p["promosso"]:
					var st := -1
					for k in m.stanze_attivabili():
						if "caccia" in m.effetti(k):
							st = k
					if st < 0:
						continue
					opz["stanza"] = st
				var libere := m.celle_robot_libere()
				for cc in libere:
					if "ricerca" in m.tipi_stanza(m.stanza_di(cc[0], cc[1])):
						opz["dest"] = cc
						break
				if not opz.has("dest") and not p["promosso"]:
					continue
			"izox":
				if p["promosso"]:
					for n in m.navi_cielo():
						if int(n["r"]) == int(m.s["M"]):
							opz["nave"] = n["id"]
							break
					if not opz.has("nave"):
						continue
			"ruzicka":
				opz["tipo"] = "ricerca"
		if m.usa(i, opz) == "":
			return true
	return false

## Gioca un intero turno (dadi + stanze). Restituisce false se la partita è finita.
func turno() -> bool:
	var guardia := 0
	while m.s["fase"] == "dadi" and guardia < 20:
		guardia += 1
		var mv := mossa_dadi()
		if mv.is_empty():
			push_error("Nessuna mossa legale nella fase dei dadi")
			return false
		m.piazza(mv[0], mv[1], mv[2])
	if m.s["fase"] == "stanze":
		gioca_stanze()
	return not m.finita()
