## Salvataggi delle partite su Firebase (Realtime Database), con chiamate REST:
## funziona sia nell'app sia nella versione web. Accesso anonimo: nessuna registrazione,
## ogni dispositivo riceve un identificativo. Chi conosce il codice di una partita può riprenderla.
##
## Stesso progetto Firebase degli altri giochi della ludoteca, con la radice "underfallingskies":
## "campagne/<codice>" per le campagne e "partite/<codice>" per le partite singole.
## La partita viene salvata come un unico testo JSON: così Firebase non trasforma in liste
## i dizionari con chiavi numeriche e non perde quelli vuoti.
extends Node

const API_KEY := "AIzaSyCf1NQodB-J3OrdU_gHYQ1I6VJtXBk1ciU"
const DB_URL := "https://flammerouge-f8669-default-rtdb.europe-west1.firebasedatabase.app"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key="
const ROOT := "underfallingskies"
const SESSIONE := "user://online_ufs.cfg"

var db_url := DB_URL
var uid := ""
var id_token := ""
var refresh_token := ""
var token_at := 0.0
var ultimo_errore := ""
## Disattiva la rete (prove automatiche, oppure gioco offline).
var offline := false

func _init() -> void:
	var t := OS.get_environment("UFS_DB_URL")
	if t == "off":
		offline = true
	elif t != "":
		db_url = t

func _richiesta(metodo: int, url: String, corpo = null, modulo := false) -> Dictionary:
	if offline:
		return {"code": 0, "data": null}
	var http := HTTPRequest.new()
	http.timeout = 25.0
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var h := PackedStringArray(["Content-Type: application/x-www-form-urlencoded" if modulo else "Content-Type: application/json"])
	var testo := ""
	if corpo != null:
		testo = corpo if modulo else JSON.stringify(corpo)
	var err := http.request(url, h, metodo, testo)
	if err != OK:
		http.queue_free()
		ultimo_errore = "richiesta non partita (%d)" % err
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var txt: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var dati = JSON.parse_string(txt) if txt != "" else null
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		ultimo_errore = "rete non raggiungibile (%d)" % res[0]
		return {"code": 0, "data": null}
	if res[1] >= 300:
		ultimo_errore = "errore %d: %s" % [res[1], txt.substr(0, 160)]
	return {"code": res[1], "data": dati}

func accedi() -> bool:
	if offline:
		return false
	if id_token != "":
		return await _rinnova()
	var c := ConfigFile.new()
	c.load(SESSIONE)
	var rt: String = c.get_value("s", "refresh", "")
	if rt != "":
		var r := await _richiesta(HTTPClient.METHOD_POST, REFRESH_URL + API_KEY, "grant_type=refresh_token&refresh_token=" + rt.uri_encode(), true)
		if r["code"] == 200 and r["data"] is Dictionary and r["data"].get("id_token", "") != "":
			id_token = r["data"]["id_token"]
			refresh_token = r["data"].get("refresh_token", rt)
			uid = r["data"].get("user_id", "")
			token_at = Time.get_unix_time_from_system()
			_ricorda()
			return true
	var r2 := await _richiesta(HTTPClient.METHOD_POST, AUTH_URL + API_KEY, {"returnSecureToken": true})
	if r2["code"] != 200 or not (r2["data"] is Dictionary):
		return false
	id_token = r2["data"].get("idToken", "")
	refresh_token = r2["data"].get("refreshToken", "")
	uid = r2["data"].get("localId", "")
	token_at = Time.get_unix_time_from_system()
	_ricorda()
	return id_token != ""

func _ricorda() -> void:
	var c := ConfigFile.new()
	c.load(SESSIONE)
	c.set_value("s", "refresh", refresh_token)
	c.save(SESSIONE)

## Il gettone dura un'ora: dopo 50 minuti lo si rinnova.
func _rinnova() -> bool:
	if refresh_token == "" or Time.get_unix_time_from_system() - token_at < 3000:
		return true
	var r := await _richiesta(HTTPClient.METHOD_POST, REFRESH_URL + API_KEY, "grant_type=refresh_token&refresh_token=" + refresh_token.uri_encode(), true)
	if r["code"] != 200 or not (r["data"] is Dictionary):
		id_token = ""
		return await accedi()
	id_token = r["data"].get("id_token", id_token)
	refresh_token = r["data"].get("refresh_token", refresh_token)
	token_at = Time.get_unix_time_from_system()
	_ricorda()
	return true

func _url(p: String) -> String:
	return "%s/%s.json?auth=%s" % [db_url, p, id_token]

## Salva un testo JSON in "<ramo>/<codice>" (ramo: "campagne" o "partite"). true se Firebase conferma.
func salva(ramo: String, codice: String, dati: Dictionary, nome: String = "") -> bool:
	if codice == "" or not await accedi():
		return false
	var corpo := {
		"json": JSON.stringify(dati),
		"nome": nome.substr(0, 60),
		"aggiornata": int(Time.get_unix_time_from_system()),
		"uid": uid,
	}
	var r := await _richiesta(HTTPClient.METHOD_PUT, _url(ROOT + "/" + ramo + "/" + codice), corpo)
	return r["code"] == 200

## Carica dal codice; null se non esiste o la rete non risponde.
func carica(ramo: String, codice: String):
	if codice == "" or not await accedi():
		return null
	var r := await _richiesta(HTTPClient.METHOD_GET, _url(ROOT + "/" + ramo + "/" + codice))
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return null
	var x = JSON.parse_string(str(r["data"].get("json", "")))
	return x if x is Dictionary else null
