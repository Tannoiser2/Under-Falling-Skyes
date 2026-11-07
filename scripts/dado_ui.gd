## Un dado disegnato nel vassoio (niente caratteri speciali: i punti sono cerchi).
class_name DadoUI
extends Control

signal premuto

var valore := 1
var colore := "grigio"
var fisso := false
var bloccato := false
var scelto := false
var _sopra := false

const COL := {"grigio": Color(0.55, 0.56, 0.6), "bianco": Color(0.95, 0.95, 0.93), "blu": Color(0.12, 0.42, 0.9)}

func _ready() -> void:
	custom_minimum_size = Vector2(66, 66 + (14 if colore == "bianco" else 0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _sopra = true; queue_redraw())
	mouse_exited.connect(func(): _sopra = false; queue_redraw())
	if bloccato:
		tooltip_text = "Dado sotto la pila dei rinforzi"
	elif fisso:
		tooltip_text = "Pechino: prende il valore di un dado già piazzato"

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not bloccato:
		premuto.emit()

func _draw() -> void:
	var r := Rect2(Vector2(5, 5), Vector2(size.x - 10, size.x - 10))
	if colore == "bianco" and not bloccato:
		var f := get_theme_default_font()
		draw_string(f, Vector2(0, size.y - 2), "RILANCIA", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(0.95, 0.85, 0.4))
	if scelto:
		draw_rect(r.grow(5), Color(0.9, 0.12, 0.42), true)
	elif _sopra and not bloccato:
		draw_rect(r.grow(3), Color(0.3, 0.82, 0.95), true)
	var base: Color = COL.get(colore, Color.GRAY)
	if bloccato:
		base = base.darkened(0.5)
	draw_rect(r, base, true)
	draw_rect(r, base.darkened(0.4), false, 2.0)
	var pip := Color(0.08, 0.08, 0.1) if colore != "blu" else Color.WHITE
	var c := r.get_center()
	var k := r.size.x * 0.26
	if fisso or bloccato:
		draw_line(c + Vector2(-k, -k * 0.35), c + Vector2(k, -k * 0.35), pip, 4)
		draw_line(c + Vector2(-k, k * 0.35), c + Vector2(k, k * 0.35), pip, 4)
		return
	var pos := {1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]],
		5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]]}
	for p in pos.get(clamp(valore, 1, 6), []):
		draw_circle(c + Vector2(p[0], p[1]) * k, r.size.x * 0.085, pip)
