# res://script/serverOnly/authentication.gd
class_name Authentication
extends RefCounted

const DB_PATH = "res://data/game_data.db"

## Validate login credentials against database
## Returns account data if valid, empty dictionary if invalid
static func validate_login(username: String, password: String) -> Dictionary:
	var db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.QUIET  # Changed from VERBOSE
	
	if not db.open_db():
		push_error("Failed to open database!")
		return {}
	
	var password_hash = password.sha256_text()
	var query = "username = '%s' AND password_hash = '%s'" % [username, password_hash]
	var accounts = db.select_rows("accounts", query, ["id", "username", "created_at"])
	
	db.close_db()
	
	if accounts.size() == 0:
		print("❌ Login failed - invalid credentials")
		return {}
	
	print("✓ Login successful: ", accounts[0]["username"])
	return accounts[0]
