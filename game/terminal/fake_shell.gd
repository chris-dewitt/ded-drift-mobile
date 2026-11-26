extends RefCounted
## Fake Linux shell over an NPC's authored filesystem (a Dictionary of
## path -> Array (directory listing) or String (file text)). Whitelisted
## commands only; nothing here ever touches the real OS.

const COMMANDS := ["ls", "cd", "cat", "pwd", "whoami", "grep", "help", "sudo", "clear", "exit", "echo"]


static func resolve(cwd: String, arg: String) -> String:
	var parts: Array[String] = []
	if not arg.begins_with("/"):
		for p in cwd.split("/", false):
			parts.append(p)
	for p in arg.split("/", false):
		if p == "." or p == "":
			continue
		if p == "..":
			if not parts.is_empty():
				parts.pop_back()
			continue
		parts.append(p)
	return "/" + "/".join(PackedStringArray(parts))


## Returns {"out": String, "cwd": String, "read": path of a file shown with
## cat/grep (or ""), "sudo": bool, "exit": bool, "clear": bool}.
static func run(line: String, fs: Dictionary, cwd: String, user: String) -> Dictionary:
	var res := {"out": "", "cwd": cwd, "read": "", "sudo": false, "exit": false, "clear": false}
	var args := Array(line.strip_edges().split(" ", false))
	if args.is_empty():
		return res
	var cmd: String = args[0]
	args.remove_at(0)
	match cmd:
		"ls":
			var target := resolve(cwd, args[0] if args.size() > 0 else ".")
			var node = fs.get(target)
			if node == null:
				res["out"] = "ls: cannot access '%s': No such file or directory" % target
			elif node is Array:
				res["out"] = "  ".join(PackedStringArray(node)) if not node.is_empty() else "(empty)"
			else:
				res["out"] = target.get_file()
		"cd":
			var target := resolve(cwd, args[0] if args.size() > 0 else "/")
			if fs.get(target) is Array:
				res["cwd"] = target
			else:
				res["out"] = "cd: %s: Not a directory" % target
		"cat":
			if args.is_empty():
				res["out"] = "cat: missing operand"
			else:
				var target := resolve(cwd, args[0])
				var node = fs.get(target)
				if node is String:
					res["out"] = node
					res["read"] = target
				elif node is Array:
					res["out"] = "cat: %s: Is a directory" % target
				else:
					res["out"] = "cat: %s: No such file or directory" % target
		"grep":
			if args.size() < 2:
				res["out"] = "usage: grep PATTERN FILE"
			else:
				var target := resolve(cwd, args[1])
				var node = fs.get(target)
				if node is String:
					var hits: Array[String] = []
					for l in node.split("\n"):
						if l.to_lower().contains(String(args[0]).to_lower()):
							hits.append(l)
					res["out"] = "\n".join(PackedStringArray(hits)) if not hits.is_empty() else ""
					if not hits.is_empty():
						res["read"] = target
				else:
					res["out"] = "grep: %s: No such file" % target
		"pwd":
			res["out"] = cwd
		"whoami":
			res["out"] = user
		"echo":
			res["out"] = " ".join(PackedStringArray(args))
		"help":
			res["out"] = "commands: " + " ".join(PackedStringArray(COMMANDS))
		"sudo":
			res["sudo"] = true
			res["out"] = "%s is not in the sudoers file. This incident will be reported." % "courier"
		"clear":
			res["clear"] = true
		"exit":
			res["exit"] = true
		_:
			res["out"] = "%s: command not found" % cmd
	return res
