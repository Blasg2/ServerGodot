# res://server/authentication.gd
class_name Authentication
extends RefCounted

const DB_PATH = "res://data/game_data.db"

## Validate login credentials against database
## Returns account data dictionary if valid, empty dictionary if invalid
static func validate_login(username: String, password: String) -> Dictionary:
	print("\n=== VALIDATING LOGIN ===")
	print("Username: ", username)
	
	var db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.VERBOSE
	
	if not db.open_db():
		push_error("Failed to open database!")
		return {}
	
	# Hash the provided password
	var password_hash = password.sha256_text()
	print("Password hash: ", password_hash)
	
	# Query for matching account
	var query = "username = '%s' AND password_hash = '%s'" % [username, password_hash]
	var accounts = db.select_rows("accounts", query, ["id", "username", "created_at"])
	
	db.close_db()
	
	if accounts.size() == 0:
		print("❌ Login failed - invalid credentials")
		print("========================\n")
		return {}
	
	var account = accounts[0]
	print("✓ Login successful!")
	print("Account ID: ", account["id"])
	print("Username: ", account["username"])
	print("Created: ", account["created_at"])
	print("========================\n")
	
	return account
