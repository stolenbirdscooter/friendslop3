extends Node
## Session + roster. Host is authoritative for the balloon, parcels and the day;
## each client owns its own courier.

const PORT := 24680
const MAX_PEERS := 5 # six windbags total

signal roster_changed
signal joined_session(world_seed: int, state: Dictionary)
signal left_session(reason: String)
signal peer_registered(id: int)
signal peer_left(id: int)

var my_name := "Windbag"
var my_color := 0
var roster := {} # id -> {name, color}
var online := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _drop("Couldn't reach that post office."))
	multiplayer.server_disconnected.connect(func(): _drop("The host's balloon drifted away."))

func me() -> int:
	return multiplayer.get_unique_id()

func is_host() -> bool:
	return multiplayer.is_server()

func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	roster = {1: {"name": my_name, "color": my_color}}
	roster_changed.emit()

func start_host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PEERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	roster = {1: {"name": my_name, "color": my_color}}
	roster_changed.emit()
	return OK

func start_join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address if address != "" else "127.0.0.1", PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	return OK

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	roster = {}

func _drop(reason: String) -> void:
	leave()
	left_session.emit(reason)

func _on_connected() -> void:
	_register.rpc_id(1, my_name, my_color)

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if roster.has(id):
		roster.erase(id)
		roster_changed.emit()
		peer_left.emit(id)

@rpc("any_peer", "reliable")
func _register(pname: String, pcolor: int) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	pname = pname.strip_edges().left(16)
	if pname == "":
		pname = "Windbag"
	roster[id] = {"name": pname, "color": clampi(pcolor, 0, Pal.RUBBER.size() - 1)}
	_sync_roster.rpc(roster)
	roster_changed.emit()
	peer_registered.emit(id)

@rpc("authority", "reliable")
func _sync_roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()

## Host -> new client: here's the world. Client then builds it and says ready.
func welcome(id: int, world_seed: int, state: Dictionary) -> void:
	_welcome.rpc_id(id, world_seed, state)

@rpc("authority", "reliable")
func _welcome(world_seed: int, state: Dictionary) -> void:
	joined_session.emit(world_seed, state)

func pname(id: int) -> String:
	return roster.get(id, {}).get("name", "Someone")

func pcolor(id: int) -> Color:
	return Pal.RUBBER[roster.get(id, {}).get("color", 0)]
