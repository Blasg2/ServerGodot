@tool
extends Node

# No preload needed! SQLite is a global class
var db_path: String = "res://data/game_data.db"  

# Configure your accounts here
var accounts_to_create = [
	{"username": "alice", "password": "alice123", "scene": "res://scenes/characters/character.tscn"},
	{"username": "bob", "password": "bob456", "scene": "res://scenes/characters/character.tscn"},
	{"username": "charlie", "password": "charlie789", "scene": "res://scenes/characters/character.tscn"},
	{"username": "dave", "password": "dave000", "scene": "res://scenes/characters/character.tscn"},
	{"username": "eve", "password": "eve111", "scene": "res://scenes/characters/character.tscn"},
]

# Just check this box to run
@export var run_script: bool = false:
	set(value):
		if value:
			_create_accounts()
		run_script = false

func _create_accounts():
	print("\n=== CREATING ACCOUNTS ===")
	
	# SQLite is a global class - just use it directly!
	var db = SQLite.new()
	db.path = db_path
	db.verbosity_level = SQLite.VERBOSE  # It's SQLite.VERBOSE, not a subclass
	db.open_db()
	
	var created = 0
	var skipped = 0
	
	for account in accounts_to_create:
		# Check if exists
		var existing = db.select_rows("accounts", "username = '" + account.username + "'", ["id"])
		if existing.size() > 0:
			print("⚠ Skipped: " + account.username + " (already exists)")
			skipped += 1
			continue
		
		# Hash password
		var password_hash = account.password.sha256_text()
		var timestamp = Time.get_datetime_string_from_system()
		
		# Insert account
		db.insert_row("accounts", {
			"username": account.username,
			"password_hash": password_hash,
			"created_at": timestamp
		})
		
		var account_id = db.last_insert_rowid
		
		# Create player data
		db.insert_row("player_data", {
			"account_id": account_id,
			"money": 100,
			"position_x": 0.0,
			"position_y": 2.0,
			"position_z": 0.0,
			"character_scene": account.scene
		})
		
		print("✓ Created: " + account.username + " (ID: " + str(account_id) + ")")
		created += 1
	
	db.close_db()
	
	print("\n=== DONE ===")
	print("Created: ", created, " | Skipped: ", skipped)
	print("============\n")
