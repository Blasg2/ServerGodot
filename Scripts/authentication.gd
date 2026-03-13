# res://script/serverOnly/authentication.gd
class_name Authentication
extends RefCounted


## Validate login credentials against database
## Returns account data if valid, empty dictionary if invalid
static func validate_login(username: String, password: String) -> Dictionary:
	var password_hash = (password + username).sha256_text()
	t.sql.query_with_bindings(
		"SELECT id, username, created_at FROM accounts WHERE username = ? AND password_hash = ?",
		[username, password_hash]
	)
	var accounts = t.sql.query_result
		
	if accounts.size() == 0:
		print("❌ Login failed - invalid credentials")
		return {}
	
	print("✓ Login successful: ", accounts[0]["username"])
	return accounts[0]
