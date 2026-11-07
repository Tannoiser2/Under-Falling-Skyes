## Il tabellone in 3D: tessere originali (nave madre, cielo, città, base), navi e escavatore modellati
## in Blender, dadi, segnalini. Tutte le misure in unità: 1 unità = 100 pixel delle tessere.
class_name Tavolo
extends Node3D

const LARGO := 9.6
const RIGA := 1.3
const ALTO_CITTA := 2.95
const MEZZA_BASE := 5.2
const MADRE_W := 7.18
const MADRE_H := 8.09

const COL_DADO := {"grigio": Color(0.55, 0.56, 0.6), "bianco": Color(0.95, 0.95, 0.93), "blu": Color(0.12, 0.42, 0.9)}

var m: Motore
var righe := 0
var z_citta := 0.0
var z_base := 0.0
var nodi_navi := {}
var nodi_dadi := {}
var nodo_esc: Node3D
var nodo_madre: MeshInstance3D
var segn_ricerca: Node3D
var segn_energia: Node3D
var segn_danni: Node3D
var gettoni: Node3D
var luci: Node3D
var evid: Node3D
var tex_cache := {}
var scena_nave := {}
var font: FontFile

func _tex(path: String) -> Texture2D:
	if not tex_cache.has(path):
		tex_cache[path] = load(path)
	return tex_cache[path]

## Livelli di visibilità: 1 = cielo, 2 = base, 3 = entrambi. Ogni inquadratura vede solo la sua parte
## del tabellone, così la base non compare anche sotto il cielo (e viceversa).
const STRATO_CIELO := 1
const STRATO_BASE := 2
const STRATO_TUTTI := 3

func strato(n: Node, l: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = l
	for ch in n.get_children():
		strato(ch, l)

func _strato_z(z: float) -> int:
	if z >= z_base - 0.3:
		return STRATO_BASE
	return STRATO_CIELO

func _piano(tex: Texture2D, w: float, h: float, pos: Vector3, alza := 0.0, sbiad := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if sbiad:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position = pos + Vector3(0, alza, 0)
	add_child(mi)
	return mi

func _box(dim: Vector3, col: Color, pos: Vector3, emiss := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = dim
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.4
	if emiss > 0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emiss
	mi.material_override = mat
	mi.position = pos
	return mi

func _cilindro(r: float, h: float, col: Color, emiss := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	mi.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.35
	mat.metallic = 0.2
	if emiss > 0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emiss
	mi.material_override = mat
	return mi

## Segnalino dei tracciati: anello scuro, disco bianco luminoso e centro colorato, ben visibile
## anche sopra i cerchi colorati delle tessere.
func _segnalino(col: Color) -> Node3D:
	var n := Node3D.new()
	var a := _cilindro(0.5, 0.2, Color(0.02, 0.02, 0.05))
	n.add_child(a)
	var b := _cilindro(0.4, 0.26, Color(1, 1, 1), 1.2)
	n.add_child(b)
	var c := _cilindro(0.22, 0.32, col, 1.5)
	n.add_child(c)
	return n

func _etichetta(testo: String, dim := 64, col := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = testo
	l.font = font
	l.font_size = dim
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.double_sided = true
	return l

# ---------------------------------------------------------------- coordinate

func z_riga(r: int) -> float:
	return RIGA * r + RIGA * 0.5

func pos_cielo(r: int, c: int) -> Vector3:
	return Vector3(-2.88 + 1.44 * c, 0.0, z_riga(r))

func pos_base(r: int, c: int) -> Vector3:
	var z := z_base + 0.867 + 1.733 * (r % 3) + (MEZZA_BASE if r >= 3 else 0.0)
	return Vector3(-2.755 + 1.39 * c, 0.0, z)

func pos_ricerca(i: int) -> Vector3:
	var tr: Dictionary = m.s["traccia"][i]
	match tr["tipo"]:
		"cielo":
			return Vector3(-4.2, 0, z_riga(int(tr["r"])))
		"citta":
			return Vector3(-4.08, 0, z_citta + 0.68)
		_:
			var ha_num: bool = m.s["traccia"].size() > 1 and m.s["traccia"][1]["tipo"] == "citta"
			return Vector3(-4.08, 0, z_citta + (1.95 if ha_num else 0.75))

func pos_energia(v: int) -> Vector3:
	if v <= 4:
		return Vector3(-4.15, 0, z_base + 0.97 + 0.92 * v)
	return Vector3(-4.15, 0, z_base + MEZZA_BASE + 0.45 + 0.93 * (v - 5))

func pos_danno(i: int) -> Vector3:
	var kt: int = m.s["danni_su"]
	var inizio := z_base + 4.62 - 1.0 * kt
	if i <= kt:
		return Vector3(4.15, 0, inizio + i)
	return Vector3(4.15, 0, z_base + MEZZA_BASE + 0.45 + 1.0 * (i - kt - 1))

func z_madre() -> float:
	return RIGA * (int(m.s["M"]) + 1)

func aabb_cielo() -> AABB:
	var top := z_madre() - 3.2
	return AABB(Vector3(-LARGO / 2 - 0.4, 0, top), Vector3(LARGO + 2.2, 0.5, z_citta + ALTO_CITTA - top))

func aabb_base() -> AABB:
	return AABB(Vector3(-LARGO / 2 - 0.1, 0, z_base - 0.15), Vector3(LARGO + 0.2, 0.5, MEZZA_BASE * 2 + 0.3))

func aabb_tutto() -> AABB:
	return AABB(Vector3(-LARGO / 2, 0, -MADRE_H + 2), Vector3(LARGO, 0.5, z_base + MEZZA_BASE * 2 + MADRE_H - 2))

## Converte un punto sul piano del tavolo in una cella.
func cella_da_punto(p: Vector3) -> Dictionary:
	if p.z >= z_base and p.z < z_base + MEZZA_BASE * 2:
		var c := int(floor((p.x + 2.755 + 0.695) / 1.39))
		var zz := p.z - z_base
		var meta := 1 if zz >= MEZZA_BASE else 0
		var rr := int(floor((zz - meta * MEZZA_BASE) / 1.733))
		if c >= 0 and c < 5 and rr >= 0 and rr < 3:
			return {"zona": "base", "r": rr + 3 * meta, "c": c}
	if p.z >= 0 and p.z < righe * RIGA:
		var c := int(floor((p.x + 2.88 + 0.72) / 1.44))
		var r := int(floor(p.z / RIGA))
		if c >= 0 and c < 5:
			return {"zona": "cielo", "r": r, "c": c}
	if p.z < 0:
		var c := int(floor((p.x + 2.88 + 0.72) / 1.44))
		if c >= 0 and c < 5:
			return {"zona": "cielo", "r": int(m.s["M"]), "c": c}
	return {}

# ---------------------------------------------------------------- costruzione

func costruisci(motore: Motore) -> void:
	m = motore
	for ch in get_children():
		ch.queue_free()
	nodi_navi.clear()
	nodi_dadi.clear()
	font = load("res://assets/font/ChakraPetch-Bold.ttf")
	for k in ["nave_viola", "nave_bianca", "nave_arancione"]:
		scena_nave[k] = load("res://assets/modelli/%s.glb" % k)
	righe = m.righe_cielo()
	var cfg: Dictionary = m.s["cfg"]
	var D := Motore.dati()
	# tavolo
	var t := _piano(_tex("res://assets/ui/tavolo.webp"), 80, 80, Vector3(0, -0.05, 12))
	(t.material_override as StandardMaterial3D).uv1_scale = Vector3(3, 3, 1)
	(t.material_override as StandardMaterial3D).albedo_color = Color(0.55, 0.55, 0.6)
	strato(t, STRATO_TUTTI)
	# cielo
	var z := 0.0
	if cfg.get("satellite", false):
		strato(_piano(_tex("res://assets/tessere/satellite.webp"), LARGO, RIGA * 2, Vector3(0, 0, RIGA)), STRATO_CIELO)
		z = RIGA * 2
	for ti in cfg["cielo"]:
		var img: String = D["cielo"][ti["t"]][int(ti["lato"])]["img"]
		strato(_piano(_tex("res://assets/tessere/%s.webp" % img), LARGO, MEZZA_BASE, Vector3(0, 0, z + MEZZA_BASE / 2)), STRATO_CIELO)
		z += MEZZA_BASE
	z_citta = z
	var nome_c: String = cfg["citta"] + ("_d" if cfg.get("danneggiata", false) else "")
	strato(_piano(_tex("res://assets/citta/%s.webp" % nome_c), LARGO, ALTO_CITTA, Vector3(0, 0, z + ALTO_CITTA / 2)), STRATO_CIELO)
	z_base = z + ALTO_CITTA + 0.12
	var ct := Motore.citta(cfg["citta"])
	strato(_piano(_tex("res://assets/tessere/base_%s_su.webp" % ct["su"]), LARGO, MEZZA_BASE, Vector3(0, 0, z_base + MEZZA_BASE / 2)), STRATO_BASE)
	strato(_piano(_tex("res://assets/tessere/base_%s_giu.webp" % ct["giu"]), LARGO, MEZZA_BASE, Vector3(0, 0, z_base + MEZZA_BASE * 1.5)), STRATO_BASE)
	# nave madre (tessera originale)
	nodo_madre = _piano(_tex("res://assets/tessere/nave_madre.webp"), MADRE_W, MADRE_H, Vector3.ZERO, 0.03)
	nodo_madre.position = Vector3(0, 0.03, z_madre() - MADRE_H / 2)
	strato(nodo_madre, STRATO_CIELO)
	# segnalini dei tracciati
	segn_ricerca = _segnalino(Color(0.2, 1.0, 0.35))
	add_child(segn_ricerca)
	strato(segn_ricerca, STRATO_CIELO)
	segn_energia = _segnalino(Color(1.0, 0.8, 0.0))
	add_child(segn_energia)
	strato(segn_energia, STRATO_BASE)
	segn_danni = _segnalino(Color(1.0, 0.1, 0.3))
	add_child(segn_danni)
	strato(segn_danni, STRATO_BASE)
	nodo_esc = load("res://assets/modelli/escavatore.glb").instantiate()
	nodo_esc.scale = Vector3.ONE * 1.25
	add_child(nodo_esc)
	strato(nodo_esc, STRATO_BASE)
	gettoni = Node3D.new()
	add_child(gettoni)
	evid = Node3D.new()
	add_child(evid)
	_luci()
	aggiorna(false)

func _luci() -> void:
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-62, -28, 0)
	sole.light_energy = 1.05
	sole.shadow_enabled = true
	sole.directional_shadow_max_distance = 80
	add_child(sole)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.9)
	e.ambient_light_energy = 0.75
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	env.environment = e
	add_child(env)

# ---------------------------------------------------------------- aggiornamento

func _muovi(n: Node3D, dest: Vector3, anim: bool, durata := 0.35) -> void:
	if not anim or n.position.distance_to(dest) < 0.01:
		n.position = dest
		return
	var tw := create_tween()
	tw.tween_property(n, "position", dest, durata).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func aggiorna(anim := true) -> void:
	if m == null:
		return
	_muovi(nodo_madre, Vector3(0, 0.03, z_madre() - MADRE_H / 2), anim, 0.5)
	_muovi(segn_ricerca, pos_ricerca(int(m.s["ricerca"])) + Vector3(0, 0.12, 0), anim)
	_muovi(segn_energia, pos_energia(int(m.s["energia"])) + Vector3(0, 0.12, 0), anim)
	_muovi(segn_danni, pos_danno(min(int(m.s["danni"]), int(m.s["danni_limite"]))) + Vector3(0, 0.12, 0), anim)
	var pe: Array = m.s["percorso"][min(int(m.s["esc"]), 29)]
	var pesc := pos_base(pe[0], pe[1]) + Vector3(0, 0.05, 0)
	_muovi(nodo_esc, pesc, anim)
	nodo_esc.rotation_degrees.y = 180.0 if int(pe[0]) % 2 == 0 else 0.0
	_aggiorna_navi(anim)
	_aggiorna_dadi(anim)
	_aggiorna_gettoni()

func _pos_nave(n: Dictionary, i_attesa: int, i_riserva: int, totale_attesa: int) -> Vector3:
	match n["st"]:
		"cielo":
			return pos_cielo(int(n["r"]), int(n["c"])) + Vector3(0, 0.3, 0)
		"madre":
			var w := 1.1
			var x0 := -w * (totale_attesa - 1) / 2.0
			return Vector3(x0 + w * i_attesa, 0.45, z_madre() - 2.3)
		"riserva":
			return Vector3(5.55, 0.3, z_madre() - 3.0 + i_riserva * 1.0)
		"fuori":
			return Vector3(-5.8, 0.3, z_riga(int(n.get("fuori_riga", 0))))
	return Vector3.ZERO

func _aggiorna_navi(anim: bool) -> void:
	var attesa := m.navi_in_attesa()
	var ia := 0
	var ir := 0
	for n in m.s["navi"]:
		var id: int = n["id"]
		var nodo: Node3D = nodi_navi.get(id, null)
		if nodo == null:
			nodo = scena_nave["nave_" + n["col"]].instantiate()
			nodo.scale = Vector3.ONE * 1.15
			add_child(nodo)
			strato(nodo, STRATO_CIELO)
			nodi_navi[id] = nodo
			nodo.position = _pos_nave(n, 0, 0, 1)
			anim = anim
		var dest := _pos_nave(n, ia, ir, attesa.size())
		if n["st"] == "madre":
			ia += 1
			nodo.scale = Vector3.ONE * 0.8
		elif n["st"] == "riserva":
			ir += 1
			nodo.scale = Vector3.ONE * 0.75
		else:
			nodo.scale = Vector3.ONE * 1.15
		_muovi(nodo, dest, anim, 0.45)

func _mat_faccia(col: String, v: int) -> StandardMaterial3D:
	var key := "%s_%d" % [col, v]
	if tex_cache.has(key):
		return tex_cache[key]
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var base: Color = COL_DADO[col]
	img.fill(base)
	var pip := Color(0.08, 0.08, 0.1) if col != "blu" else Color(1, 1, 1)
	var pos := {1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]],
		5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]]}
	for p in pos.get(clamp(v, 1, 6), []):
		var cx: int = 48 + p[0] * 25
		var cy: int = 48 + p[1] * 25
		for y in range(-10, 11):
			for x in range(-10, 11):
				if x * x + y * y <= 90:
					img.set_pixel(cx + x, cy + y, pip)
	# bordo
	for i in 96:
		for k in 3:
			img.set_pixel(i, k, base.darkened(0.35)); img.set_pixel(i, 95 - k, base.darkened(0.35))
			img.set_pixel(k, i, base.darkened(0.35)); img.set_pixel(95 - k, i, base.darkened(0.35))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.3
	tex_cache[key] = mat
	return mat

func _nodo_dado(col: String) -> Node3D:
	var n := Node3D.new()
	var corpo := _box(Vector3(0.82, 0.82, 0.82), COL_DADO[col], Vector3(0, 0.41, 0))
	n.add_child(corpo)
	var faccia := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.8, 0.8)
	faccia.mesh = q
	faccia.position = Vector3(0, 0.825, 0)
	faccia.name = "faccia"
	n.add_child(faccia)
	add_child(n)
	strato(n, STRATO_BASE)
	return n

func _aggiorna_dadi(anim: bool) -> void:
	var visti := {}
	for d in m.s["dadi"]:
		if d["st"] != "piazzato":
			continue
		visti[d["id"]] = true
		var col: String = d["col"]
		var n: Node3D = nodi_dadi.get(d["id"], null)
		if n == null:
			n = _nodo_dado(col)
			nodi_dadi[d["id"]] = n
			n.position = pos_base(d["r"], d["c"]) + Vector3(0, 3, 0)
		(n.get_node("faccia") as MeshInstance3D).material_override = _mat_faccia(col, int(d["v"]))
		n.rotation_degrees.y = 0
		_muovi(n, pos_base(d["r"], d["c"]), anim, 0.3)
	for ro in m.s["robot"]:
		var id: int = ro["id"]
		visti[id] = true
		var n: Node3D = nodi_dadi.get(id, null)
		if n == null:
			n = _nodo_dado("blu")
			nodi_dadi[id] = n
			n.position = pos_base(ro["r"], ro["c"]) + Vector3(0, 3, 0)
		(n.get_node("faccia") as MeshInstance3D).material_override = _mat_faccia("blu", int(ro["v"]))
		n.rotation_degrees.y = 45.0 if ro["esausto"] else 0.0
		_muovi(n, pos_base(ro["r"], ro["c"]), anim, 0.3)
	for id in nodi_dadi.keys():
		if not visti.has(id):
			nodi_dadi[id].queue_free()
			nodi_dadi.erase(id)

func _gettone(pos: Vector3, testo: String, col: Color, dim := 0.32) -> void:
	var g := _cilindro(dim, 0.1, col, 0.4)
	g.position = pos + Vector3(0, 0.06, 0)
	gettoni.add_child(g)
	strato(g, _strato_z(pos.z))
	if testo != "":
		var l := _etichetta(testo, 56)
		l.position = pos + Vector3(0, 0.13, 0)
		gettoni.add_child(l)
		strato(l, _strato_z(pos.z))

func _aggiorna_gettoni() -> void:
	for ch in gettoni.get_children():
		ch.queue_free()
	var sc: Dictionary = m.s["sc"]
	var rosa := Color(0.9, 0.2, 0.55)
	var azz := Color(0.25, 0.75, 0.95)
	match m.scen():
		"satelliti":
			for sat in sc["sat"]:
				_gettone(pos_cielo(sat[0], sat[1]) + Vector3(0.45, 0, -0.35), "", azz, 0.22)
		"evacuazione":
			for k in sc["righe"].keys():
				_gettone(Vector3(5.2, 0, z_riga(int(k))), "", rosa, 0.28)
			var i := 0
			for v in sc["citta"]:
				_gettone(Vector3(-1.5 + i * 0.75, 0, z_citta + 2.4), str(v), azz, 0.3)
				i += 1
		"tempesta":
			for k in sc["coperte"]:
				_gettone(pos_cielo(k[0], k[1]), "", rosa, 0.42)
		"contaminazione":
			for k in sc["celle"]:
				_gettone(pos_base(k["r"], k["c"]) + Vector3(-0.42, 0, -0.42), str(k["v"]) if k["su"] else "", azz, 0.22)
		"sabotatore":
			if int(sc.get("col", -1)) >= 0:
				var p := pos_base(0, int(sc["col"]))
				_gettone(Vector3(p.x, 0, z_base - 0.05), str(int(sc["col"]) + 1), rosa, 0.3)
		"riparazione":
			for k in sc["usati"]:
				_gettone(pos_base(k[0], k[1]), "", azz, 0.3)
		"reattore":
			for i in int(sc["k"]):
				_gettone(pos_danno(int(m.s["danni_limite"]) - i) + Vector3(0, 0.25, 0), "", rosa, 0.28)

# ---------------------------------------------------------------- evidenziazioni ed effetti

func pulisci_evidenza() -> void:
	for ch in evid.get_children():
		ch.queue_free()

func evidenzia_base(celle: Array, col: Color) -> void:
	for cc in celle:
		var b := _box(Vector3(1.25, 0.04, 1.55), Color(col.r, col.g, col.b, 0.3), pos_base(cc[0], cc[1]) + Vector3(0, 0.03, 0), 0.8)
		(b.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		evid.add_child(b)
		strato(b, STRATO_BASE)

func evidenzia_cielo(celle: Array, col: Color) -> void:
	for cc in celle:
		var b := _box(Vector3(1.35, 0.04, 1.2), Color(col.r, col.g, col.b, 0.3), pos_cielo(cc[0], cc[1]) + Vector3(0, 0.03, 0), 0.8)
		(b.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		evid.add_child(b)
		strato(b, STRATO_CIELO)

func esplosione(pos: Vector3, col := Color(1.0, 0.55, 0.1)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	p.mesh = sm
	p.position = pos + Vector3(0, 0.4, 0)
	add_child(p)
	strato(p, _strato_z(pos.z))
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func lampo_citta() -> void:
	var b := _box(Vector3(LARGO, 0.05, ALTO_CITTA), Color(1, 0.1, 0.2, 0.6), Vector3(0, 0.08, z_citta + ALTO_CITTA / 2), 2.0)
	(b.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(b)
	strato(b, STRATO_CIELO)
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector3(1, 1, 1.05), 0.5)
	tw.tween_callback(b.queue_free)
	esplosione(Vector3(randf_range(-3, 3), 0, z_citta + 1.4), Color(1, 0.2, 0.25))

## Gestisce gli eventi del motore (esplosioni, colpi alla città).
func eventi(lista: Array) -> void:
	for e in lista:
		match e["t"]:
			"abbattuta":
				esplosione(pos_cielo(e["pos"][0], e["pos"][1]))
			"colpo":
				lampo_citta()
