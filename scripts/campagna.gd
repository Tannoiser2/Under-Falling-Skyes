## Campagna in quattro capitoli: pile casuali, battaglie, personaggi promossi, registro e battaglia finale.
class_name Campagna
extends RefCounted

const TITOLI := {1: "Capitolo 1 – L'Invasione", 2: "Capitolo 2 – Trincerati", 3: "Capitolo 3 – Soverchiati",
	4: "Capitolo 4 – La Battaglia Finale"}
const INTRO := {
	1: "Titanici colossi spaziali discendono sul nostro pianeta, vomitando orde di navi aliene nei cieli. Mentre le città cercano disperatamente di difendersi, la nostra squadra di ricerca tenta di raccogliere tutte le informazioni che possono aiutarci a respingere il nemico.",
	2: "Man mano che le navi nemiche vengono abbattute, la nostra squadra di ricerca ha colto l'opportunità di studiare la biotecnologia aliena. I progressi sono ostacolati dal bombardamento continuo.",
	3: "La superiorità della tecnologia aliena continua a schiacciarci. Ma ora abbiamo uno di loro dalla nostra parte. Che possa spiegarci come era controllato dal dispositivo? La nostra squadra di ricerca deve trovare un modo per comunicare con lui.",
	4: "Mentre i nostri caccia modificati vengono lanciati nella mischia, l'intelligenza artificiale orbitale ordina ai suoi burattini di raddoppiare gli attacchi."}
const NOVITA := {
	1: "Nuove città con abilità speciali, quattro scenari e i primi personaggi. In ogni battaglia scegli fra due pile casuali (città, scenario, personaggio). Se perdi la prima partita, giochi una seconda partita sul lato danneggiato della città.",
	2: "Una tessera cielo avanzata prende il posto della più bassa: le navi colpiscono la città appena entrano nel cielo vuoto. Arrivano le stanze comando (basi E ed F) e il trasferimento dei dadi. Ogni battaglia ha un personaggio nuovo e uno promosso dal Capitolo 1. Una delle cinque città resterà fuori dalla vicenda.",
	3: "Due tessere cielo avanzate sostituiscono quelle in alto: teletrasporti e un'azione che fa scendere tutte le navi. Arriva la base G con le stanze verticali. Ogni battaglia ha un personaggio nuovo e due promossi.",
	4: "Un solo scenario, La Battaglia Finale: il satellite alieno sopra il cielo e le esplosioni rosse. Scegli una delle città che hai salvato (sul lato danneggiato) e una squadra di tre personaggi promossi. Se perdi, la città è distrutta: scegline un'altra."}

var c: Dictionary = {}
var rng := RandomNumberGenerator.new()

func nuova(nome: String, minaccia: int, codice: String) -> void:
	rng.randomize()
	c = {"nome": nome, "codice": codice, "minaccia": minaccia, "capitolo": 1, "battaglia": 0, "passo": "",
		"pool": {}, "pile": [], "corrente": {}, "registro": [], "alleati": [], "salvate": [], "distrutte": [],
		"stato_partita": null, "finale": {}, "punteggio": 0, "vinta": false}
	_prepara_capitolo()

func carica(dati: Dictionary) -> void:
	c = dati
	rng.randomize()
	Motore._normalizza(c)

func _prepara_capitolo() -> void:
	var cap: int = c["capitolo"]
	var D := Motore.dati()
	var pool := {"citta": [], "scenari": [], "pers": []}
	for x in D["citta"]:
		if int(x["cap"]) == cap:
			pool["citta"].append(x["id"])
	for x in D["scenari"]:
		if int(x["cap"]) == cap:
			pool["scenari"].append(x["id"])
	for x in D["personaggi"]:
		if int(x["cap"]) == cap:
			pool["pers"].append(x["id"])
	c["pool"] = pool
	c["battaglia"] = 0
	if cap == 4:
		c["passo"] = "finale_citta" if not c["salvate"].is_empty() else "finita"
		if c["passo"] == "finita":
			_chiudi(false)
	else:
		c["passo"] = "intro"

func _pesca(a: Array) -> String:
	var i := rng.randi_range(0, a.size() - 1)
	var x: String = a[i]
	a.remove_at(i)
	return x

func genera_pile() -> void:
	var p: Dictionary = c["pool"]
	var pile: Array = []
	for k in 2:
		if p["citta"].is_empty() or p["scenari"].is_empty() or p["pers"].is_empty():
			break
		pile.append({"citta": _pesca(p["citta"]), "scenario": _pesca(p["scenari"]), "pers": _pesca(p["pers"])})
	c["pile"] = pile
	c["passo"] = "scegli_pila"

func scegli_pila(i: int) -> void:
	var p: Dictionary = c["pile"][i]
	c["corrente"] = {"citta": p["citta"], "scenario": p["scenario"], "pers": p["pers"], "promossi": [],
		"partita": 1, "esiti": [], "minaccia": c["minaccia"]}
	c["pile"] = []
	# nel capitolo 2 la quinta città esce dalla vicenda dopo la scelta della seconda battaglia
	if int(c["capitolo"]) == 2 and int(c["battaglia"]) == 1:
		c["pool"]["citta"].clear()
	if numero_promossi() > 0:
		c["passo"] = "scegli_promossi"
	else:
		c["passo"] = "pronta"

func numero_promossi() -> int:
	match int(c["capitolo"]):
		2:
			return 1
		3:
			return 2
		4:
			return 3
	return 0

## Personaggi promovibili per la battaglia corrente.
func promovibili() -> Array:
	var cap: int = c["capitolo"]
	var a: Array = []
	for al in c["alleati"]:
		if int(al["cap"]) < cap and not al.get("usato_cap", 0) == cap:
			a.append(al["id"])
	if cap == 4:
		a.clear()
		for al in c["alleati"]:
			a.append(al["id"])
	return a

func scegli_promossi(ids: Array) -> void:
	c["corrente"]["promossi"] = ids.duplicate()
	if int(c["capitolo"]) < 4:
		for al in c["alleati"]:
			if al["id"] in ids:
				al["usato_cap"] = int(c["capitolo"])
		# nella seconda battaglia del capitolo si usano gli altri automaticamente
	c["passo"] = "pronta"

## Se nella seconda battaglia restano esattamente i promossi necessari, li assegna da sé.
func promossi_obbligati() -> Array:
	var p := promovibili()
	if int(c["capitolo"]) < 4 and int(c["battaglia"]) == 1 and p.size() == numero_promossi():
		return p
	return []

func cielo_capitolo() -> Array:
	var cap: int = c["capitolo"]
	var t: Array = ["1", "2", "3", "4"]
	match cap:
		2:
			t = ["1", "2", "3", "c2"]
		3:
			t = ["c3a", "c3b", "3", "4"]
		4:
			t = ["c3a", "c3b", "c4", "4"]
	var lati := [0, 0, 0, 0]
	var pos := [0, 1, 2, 3]
	for i in range(pos.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pos[i]
		pos[i] = pos[j]
		pos[j] = tmp
	for k in clamp(int(c["corrente"].get("minaccia", c["minaccia"])), 0, 4):
		lati[pos[k]] = 1
	var cielo: Array = []
	for i in 4:
		cielo.append({"t": t[i], "lato": lati[i]})
	return cielo

## Configurazione della partita da giocare ora.
func cfg_partita() -> Dictionary:
	var cor: Dictionary = c["corrente"]
	var ps: Array = []
	if cor.get("pers", "") != "":
		ps.append({"id": cor["pers"], "promosso": false})
	for id in cor["promossi"]:
		ps.append({"id": id, "promosso": true})
	var fin := int(c["capitolo"]) == 4
	return {"citta": cor["citta"], "danneggiata": fin or int(cor["partita"]) == 2, "scenario": cor["scenario"],
		"personaggi": ps, "cielo": cielo_capitolo(), "satellite": fin, "seme": 0}

func avvia_partita() -> Dictionary:
	c["passo"] = "partita"
	var cfg := cfg_partita()
	return cfg

## Registra l'esito della partita appena conclusa.
func esito(vittoria: bool) -> void:
	var cor: Dictionary = c["corrente"]
	c["stato_partita"] = null
	var lv: int = int(cor.get("minaccia", c["minaccia"]))
	if int(c["capitolo"]) == 4:
		var f: Dictionary = c["finale"]
		if not f.has("tentativi"):
			f["tentativi"] = []
		f["tentativi"].append({"citta": cor["citta"], "esito": lv if vittoria else "X"})
		f["squadra"] = cor["promossi"]
		if vittoria:
			_chiudi(true)
		else:
			c["salvate"].erase(cor["citta"])
			c["distrutte"].append(cor["citta"])
			c["passo"] = "finale_citta" if not c["salvate"].is_empty() else "finita"
			if c["passo"] == "finita":
				_chiudi(false)
		return
	if vittoria:
		cor["esiti"].append(lv)
		_chiudi_battaglia(true)
	elif int(cor["partita"]) == 1:
		cor["esiti"].append("X")
		cor["partita"] = 2
		c["passo"] = "seconda"
	else:
		cor["esiti"].append("X")
		_chiudi_battaglia(false)

func _chiudi_battaglia(salvata: bool) -> void:
	var cor: Dictionary = c["corrente"]
	c["registro"].append({"cap": c["capitolo"], "citta": cor["citta"], "scenario": cor["scenario"], "pers": cor["pers"],
		"promossi": cor["promossi"], "esiti": cor["esiti"]})
	c["alleati"].append({"id": cor["pers"], "cap": c["capitolo"]})
	if salvata:
		c["salvate"].append(cor["citta"])
	else:
		c["distrutte"].append(cor["citta"])
	c["battaglia"] = int(c["battaglia"]) + 1
	c["passo"] = "fine_battaglia"

## Dopo la schermata di fine battaglia.
func prosegui() -> void:
	if int(c["battaglia"]) >= 2:
		c["capitolo"] = int(c["capitolo"]) + 1
		_prepara_capitolo()
	else:
		genera_pile()

func scegli_citta_finale(id: String) -> void:
	c["corrente"] = {"citta": id, "scenario": "finale", "pers": "", "promossi": [], "partita": 1, "esiti": [],
		"minaccia": c["minaccia"]}
	c["passo"] = "scegli_promossi"

func _chiudi(vinta: bool) -> void:
	c["vinta"] = vinta
	c["passo"] = "finita"
	c["punteggio"] = punteggio()

func punteggio() -> int:
	var p := 0
	for b in c["registro"]:
		for e in b["esiti"]:
			if str(e) == "X":
				p -= 1
			else:
				p += int(e)
	for t in c["finale"].get("tentativi", []):
		if str(t["esito"]) == "X":
			p -= 1
		else:
			p += int(t["esito"])
	return p
