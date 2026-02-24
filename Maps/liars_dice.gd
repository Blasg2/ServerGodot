extends Node
class_name LiarsDice

signal show_dice(dice: Array)
signal turn_changed(peer_id: int, name: String, is_first_bid: bool)
signal bid_made(name: String, quantity: int, face: int)
signal round_result(all_dice: Dictionary, loser_name: String, description: String)
signal game_over(winner_name: String)

const STARTING_DICE := 5

var player_dice: Dictionary = {}
var player_dice_count: Dictionary = {}
var turn_order: Array[int] = []
var current_turn_index: int = 0
var current_bid: Dictionary = {"quantity": 0, "face": 0, "player": 0}
var player_names: Dictionary = {}
var game_active: bool = false
var round_active: bool = false

func start_game(players: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	player_names = players
	turn_order = players.keys()
	turn_order.shuffle()
	for id in turn_order:
		player_dice_count[id] = STARTING_DICE
	game_active = true
	_start_round()

func _start_round() -> void:
	round_active = true
	current_bid = {"quantity": 0, "face": 0, "player": 0}
	for id in turn_order:
		var dice: Array[int] = []
		for i in player_dice_count[id]:
			dice.append(randi_range(1, 6))
		player_dice[id] = dice
		_rpc_show_dice.rpc_id(id, dice)
	_rpc_turn.rpc(turn_order[current_turn_index],
		player_names.get(turn_order[current_turn_index], "???"), true)

@rpc("any_peer", "reliable")
func make_bid(quantity: int, face: int) -> void:
	if not multiplayer.is_server() or not round_active:
		return
	var id := multiplayer.get_remote_sender_id()
	if id != turn_order[current_turn_index]:
		return
	if not _is_valid_bid(quantity, face):
		return
	current_bid = {"quantity": quantity, "face": face, "player": id}
	_rpc_bid.rpc(player_names.get(id, str(id)), quantity, face)
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	_rpc_turn.rpc(turn_order[current_turn_index],
		player_names.get(turn_order[current_turn_index], "???"), false)

@rpc("any_peer", "reliable")
func call_liar() -> void:
	if not multiplayer.is_server() or not round_active:
		return
	var caller := multiplayer.get_remote_sender_id()
	if caller != turn_order[current_turn_index] or current_bid.quantity == 0:
		return
	round_active = false
	var actual := _count_dice(current_bid.face)
	var liar_right = actual < current_bid.quantity
	var loser = current_bid.player if liar_right else caller
	var all := _get_all_dice()
	var desc := "%s called LIAR on %s. Bid: %d x %d. Actual: %d. %s" % [
		player_names.get(caller, "?"), player_names.get(current_bid.player, "?"),
		current_bid.quantity, current_bid.face, actual,
		"Bluff caught!" if liar_right else "Bid was true!"]
	_rpc_result.rpc(all, player_names.get(loser, "?"), desc)
	_lose_die(loser)

@rpc("any_peer", "reliable")
func call_spot_on() -> void:
	if not multiplayer.is_server() or not round_active:
		return
	var caller := multiplayer.get_remote_sender_id()
	if caller != turn_order[current_turn_index] or current_bid.quantity == 0:
		return
	round_active = false
	var actual := _count_dice(current_bid.face)
	var is_exact = actual == current_bid.quantity
	var all := _get_all_dice()
	if is_exact:
		var desc := "%s called SPOT ON! Bid: %d x %d. Actual: %d. Correct! Everyone else loses a die." % [
			player_names.get(caller, "?"),
			current_bid.quantity, current_bid.face, actual]
		_rpc_result.rpc(all, "everyone else", desc)
		for pid in turn_order:
			if pid != caller:
				player_dice_count[pid] = max(0, player_dice_count[pid] - 1)
		# Remove eliminated players
		var alive: Array[int] = []
		for pid in turn_order:
			if player_dice_count[pid] > 0:
				alive.append(pid)
		turn_order = alive
		if turn_order.size() <= 1:
			_end_game()
			return
		current_turn_index = current_turn_index % turn_order.size()
		await get_tree().create_timer(3.0).timeout
		_start_round()
	else:
		var desc := "%s called SPOT ON! Bid: %d x %d. Actual: %d. Wrong!" % [
			player_names.get(caller, "?"),
			current_bid.quantity, current_bid.face, actual]
		_rpc_result.rpc(all, player_names.get(caller, "?"), desc)
		_lose_die(caller)

func _lose_die(loser_id: int) -> void:
	player_dice_count[loser_id] -= 1
	if player_dice_count[loser_id] <= 0:
		turn_order.erase(loser_id)
		player_dice.erase(loser_id)
	if turn_order.size() <= 1:
		_end_game()
		return
	current_turn_index = current_turn_index % turn_order.size()
	await get_tree().create_timer(3.0).timeout
	_start_round()

func _end_game() -> void:
	game_active = false
	round_active = false
	var winner_name = player_names.get(turn_order[0], "?") if turn_order.size() == 1 else "Nobody"
	_rpc_game_over.rpc(winner_name)

func _count_dice(face: int) -> int:
	var total := 0
	for pid in player_dice:
		for die in player_dice[pid]:
			if die == face or die == 1:
				total += 1
	return total

func _get_all_dice() -> Dictionary:
	var all: Dictionary = {}
	for pid in player_dice:
		all[pid] = player_dice[pid]
	return all

func _is_valid_bid(quantity: int, face: int) -> bool:
	if face < 1 or face > 6 or quantity < 1:
		return false
	if current_bid.quantity == 0:
		return true
	return quantity > current_bid.quantity or (quantity == current_bid.quantity and face > current_bid.face)

# ─── RPCs ───

@rpc("authority", "reliable", "call_local")
func _rpc_show_dice(dice: Array) -> void:
	show_dice.emit(dice)

@rpc("authority", "reliable", "call_local")
func _rpc_turn(peer_id: int, player_name: String, is_first: bool) -> void:
	turn_changed.emit(peer_id, player_name, is_first)

@rpc("authority", "reliable", "call_local")
func _rpc_bid(player_name: String, quantity: int, face: int) -> void:
	bid_made.emit(player_name, quantity, face)

@rpc("authority", "reliable", "call_local")
func _rpc_result(all_dice: Dictionary, loser_name: String, description: String) -> void:
	round_result.emit(all_dice, loser_name, description)

@rpc("authority", "reliable", "call_local")
func _rpc_game_over(winner_name: String) -> void:
	game_over.emit(winner_name)
