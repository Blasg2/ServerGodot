@tool
extends Node

var db_path: String = "res://data/game_data.db"

var accounts_to_create = [
	{"username": "Gui", "password": "9739"},
	{"username": "Gariba", "password": "1234"},
	{"username": "Joj", "password": "swaggin2"},
	{"username": "Iusaf", "password": "ninja13#"},
	{"username": "Lil", "password": "linkpinscher"},
]

@export var run_script: bool = false:
	set(value):
		if value:
			_create_accounts()
		run_script = false

func _create_accounts():
	print("\n=== CREATING ACCOUNTS ===")
	
	var db = SQLite.new()
	db.path = db_path
	db.verbosity_level = SQLite.VERBOSE
	db.open_db()
	
	# Create tables
	db.query("CREATE TABLE IF NOT EXISTS accounts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		created_at TEXT NOT NULL
	)")
	
	db.query("CREATE TABLE IF NOT EXISTS charStats (
		Username TEXT PRIMARY KEY,
		CurrentLevel TEXT NOT NULL DEFAULT 'level1',
		Money INTEGER NOT NULL DEFAULT 100,
		X REAL NOT NULL DEFAULT 0.0,
		Y REAL NOT NULL DEFAULT 0.0,
		Z REAL NOT NULL DEFAULT 0.0
	)")
	
	var created = 0
	var skipped = 0
	
	for account in accounts_to_create:
		db.query_with_bindings("SELECT id FROM accounts WHERE username = ?", [account.username])
		if db.query_result.size() > 0:
			print("Skipped: " + account.username + " (already exists)")
			skipped += 1
			continue
		
		# Salt = username, so: sha256(password + username)
		var password_hash = (account.password + account.username).sha256_text()
		var timestamp = Time.get_datetime_string_from_system()
		
		db.insert_row("accounts", {
			"username": account.username,
			"password_hash": password_hash,
			"created_at": timestamp
		})
		print("Insert result: ", db.error_message)

		db.insert_row("charStats", {
			"Username": account.username,
			"CurrentLevel": "level1",
			"Money": 100,
			"X": 0.0,
			"Y": 0.0,
			"Z": 0.0
		})
		
		print("Created: " + account.username)
		created += 1
	
	db.close_db()
	
	print("\n=== DONE ===")
	print("Created: ", created, " | Skipped: ", skipped)
