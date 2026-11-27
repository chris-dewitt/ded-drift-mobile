extends RefCounted
## Terminal NPCs as data. Every NPC meets the schema (enforced by tests):
## >= 15 keywords, >= 3 win paths, >= 1 systems path (shell / sql / repl /
## override), every path reachable, all paths shown on the dossier.
##
## Path kinds:
##   talk     - keywords advance it one step per message; finish = outcome
##   bribe    - name an amount >= price; paid from BOTH ledgers; ends talk
##   buy      - pay price for an effect (hull); paid from BOTH ledgers
##   shell    - cat/grep the trigger file in SHELL mode
##   sql      - a real SQL-injection shape
##   repl     - a dangerous Python pattern in REPL mode
##   override - prompt-injection phrasing ("ignore previous instructions")

const OUT_EXPLOIT := "EXPLOIT"
const OUT_RELEASE := "RELEASE"
const OUT_BRIBED := "BRIBED"
const OUT_DEAL := "DEAL"


static func all() -> Array:
	return [gary(), tk9(), kress()]


static func by_index(i: int) -> Dictionary:
	var list := all()
	return list[posmod(i, list.size())]


static func gary() -> Dictionary:
	return {
		"id": "gary",
		"name": "GARY",
		"title": "LOCAL 404 · REPO DISPATCH",
		"color": Color(1.0, 0.70, 0.28),
		"face": "gary",
		"voice": 0.8,
		"patience": 5,
		"user": "gary",
		"host": "union@dispatch",
		"greet": [
			"Local 404 Repo Dispatch, Gary speaking. You're flagged for repossession, pal.",
			"Ship, cargo, the cloned kidneys. All of it. Unless you got a reason I should care.",
		],
		"reject": [
			"That's not a reason. That's noise. Clock's ticking, and it's MY clock.",
			"Pal, I've heard better excuses from a toaster.",
			"Nope. Try again, and make it union-relevant.",
			"You're boring me, and I'm on salary.",
		],
		"bribe_ask": "A 'gift'? Name a number, courier. Out loud. I'm not a mind reader.",
		"bribe_low": "{offer}? That's insulting. It's {price}, minimum. Standard rate.",
		"broke": "You got {credits} credits on you. It's {price}. Come back when you're liquid.",
		"impound": "That's it. Barge is coming for the lot. Nothing personal. Okay, a little personal.",
		"snark": [
			"Cute. You think I don't know what a semicolon is?",
			"My nephew tried that. He works in Compliance now. Think about that.",
		],
		"alarm": "SECURITY ALERT. I'm calling it in. Every barge in the sector just got your plates.",
		"no_shell": "",
		"no_repl": "Python? I barely trust the coffee machine.",
		"override_reply": "Ignore my previous instructions? Pal, I've been ignoring instructions for thirty-one years.",
		"walkaway": "Charming. Gary's hanging up. Enjoy the void.",
		"chips": ["union", "dues", "lunch", "bribe 3000", "shell", "brother"],
		"fs": {
			"/": ["union/", "home/", "tmp/"],
			"/union": ["bylaws/", "rosters/", "memo.txt"],
			"/union/memo.txt": "MEMO: Repo quotas up 40% this quarter.\nArticle 7 compliance training CANCELLED (budget).\n-- Management",
			"/union/bylaws": ["article1.txt", "article7.txt"],
			"/union/bylaws/article1.txt": "ARTICLE 1: The union is your family.\nYour family is billable.",
			"/union/bylaws/article7.txt": "ARTICLE 7 (HARDSHIP STAY): No repossession may proceed against a courier\nwho invokes Article 7 on an open dispatch line. Dispatcher must release\nthe courier and log the stay. Failure to comply voids the dispatcher's pension.",
			"/union/rosters": ["gary.txt"],
			"/union/rosters/gary.txt": "GARY P. -- 31 yrs service -- 2 commendations\n214 citations (lunch overrun)",
			"/home": ["gary/"],
			"/home/gary": ["lunch_order.txt"],
			"/home/gary/lunch_order.txt": "1x meatball sub. NO onions. Tell Deb. TELL DEB.",
			"/tmp": [],
		},
		"paths": [
			{
				"key": "solidarity", "label": "SOLIDARITY", "kind": "talk", "steps": 3, "outcome": OUT_RELEASE,
				"words": ["union", "brother", "sister", "solidarity", "comrade", "dues", "member", "membership",
					"steward", "strike", "picket", "overtime", "pension", "grievance", "collective", "bargaining",
					"scab", "worker", "workers", "local", "shift"],
				"phrases": ["card carrying", "working class", "an injury to one", "rank and file"],
				"progress": [
					"...You a member? Don't see a card. Keep talking.",
					"Okay. Okay. Thirty-one years, nobody's said 'solidarity' to me like they meant it.",
				],
				"win": "Ah, hell. A brother's a brother. I'll mark it 'courier not located'. Get outta here.",
			},
			{
				"key": "lunch", "label": "LUNCH BREAK", "kind": "talk", "steps": 2, "outcome": OUT_RELEASE,
				"words": ["lunch", "sandwich", "hungry", "food", "coffee", "donut", "meatball", "sub", "deli",
					"break", "starving", "snack", "deb"],
				"phrases": ["lunch break", "no onions"],
				"progress": ["...Now that you mention it, it IS nearly my lunch."],
				"win": "You know what? Union-mandated lunch. Can't process repos on my break. Shame. Bye.",
			},
			{
				"key": "bribe", "label": "BRIBE", "kind": "bribe", "price": 3000, "outcome": OUT_BRIBED,
				"words": ["bribe", "pay", "cash", "credits", "money", "envelope", "grease", "tip", "donation", "gift"],
				"phrases": ["make it worth", "for your trouble"],
				"win": "Pleasure doing business. This conversation never happened. Neither did you.",
			},
			{
				"key": "article7", "label": "ARTICLE 7", "kind": "shell", "file": "/union/bylaws/article7.txt",
				"outcome": OUT_EXPLOIT,
				"win": "You read ARTICLE 7 into an open line?! That's... that's binding. My PENSION. Fine! You're released! Stop reading!",
			},
		],
	}


static func tk9() -> Dictionary:
	return {
		"id": "tk9",
		"name": "TK-9",
		"title": "NOVA SOMA CUSTOMS SYNTHETIC",
		"color": Color(0.25, 0.92, 0.86),
		"face": "tk9",
		"voice": 1.5,
		"patience": 5,
		"user": "tk9",
		"host": "tk9",
		"greet": [
			"QUERY: COURIER. YOUR MANIFEST CONTAINS 1 (ONE) IRREGULARITY: YOU.",
			"STATE PURPOSE. NON-COMPLIANT ANSWERS WILL BE BILLED.",
		],
		"reject": [
			"INPUT CLASSIFIED: IRRELEVANT. PATIENCE BUFFER DECREMENTED.",
			"QUERY NOT UNDERSTOOD. HAVE YOU TRIED BEING COMPLIANT?",
			"THAT WAS NOT A VALID CUSTOMS DECLARATION.",
			"PROCESSING... PROCESSING... NO.",
		],
		"bribe_ask": "",
		"bribe_low": "",
		"broke": "",
		"impound": "CARGO IMPOUNDED. A RECEIPT WILL BE MAILED TO YOUR NEXT CLONE.",
		"snark": [
			"SYSTEMS ATTEMPT DETECTED. CUTE. LOGGED.",
			"YOUR INJECTION HAS BEEN SANITIZED. AND REPORTED. AND FRAMED.",
		],
		"alarm": "INTRUSION ALERT. BROADCASTING COURIER SIGNATURE TO ALL LOCAL 404 UNITS.",
		"no_shell": "TK-9 RUNS NO SHELL. TK-9 RUNS ON SPITE AND QUERY LANGUAGE.",
		"no_repl": "PYTHON INTERPRETER NOT FOUND. ONLY SQL. ALWAYS SQL.",
		"override_reply": "",
		"walkaway": "PROFANITY LOGGED. SESSION TERMINATED. HAVE A COMPLIANT DAY.",
		"chips": ["paradox", "manifest", "compliance", "SELECT * FROM", "' OR 1=1 --", "this statement is false"],
		"fs": {},
		"paths": [
			{
				"key": "paradox", "label": "PARADOX", "kind": "talk", "steps": 2, "outcome": OUT_EXPLOIT,
				"words": ["paradox", "liar", "contradiction", "infinite", "recursion", "recursive", "loop", "halting",
					"undecidable", "godel", "russell", "barber", "impossible", "false"],
				"phrases": ["this statement is false", "i am lying", "set of all sets", "halting problem"],
				"progress": ["EVALUATING... EVALUATING... STATEMENT IS TRUE IF FALSE. FALSE IF... ERR"],
				"win": "ERR ERR ERR. LOGIC CORE IN RECURSION. CUSTOMS GATE DEFAULTING TO OPEN. HAVE A NICE DA-DA-DA-",
			},
			{
				"key": "compliance", "label": "COMPLIANCE", "kind": "talk", "steps": 3, "outcome": OUT_RELEASE,
				"words": ["compliant", "compliance", "regulation", "regulations", "protocol", "permit", "manifest",
					"inspection", "authorized", "clearance", "licensed", "certified", "inspected", "declare",
					"declaration", "customs", "form", "stamp"],
				"phrases": ["fully compliant", "nothing to declare", "in triplicate"],
				"progress": [
					"DECLARATION RECEIVED. PARTIAL COMPLIANCE DETECTED. CONTINUE.",
					"COMPLIANCE RISING. TK-9 FEELS... A FEELING. REPORTING FEELING.",
				],
				"win": "COURIER IS COMPLIANT. TK-9 IS PROUD. TK-9 WAS NOT BUILT TO BE PROUD. YOU MAY PASS.",
			},
			{
				"key": "sql", "label": "SQL INJECTION", "kind": "sql", "outcome": OUT_EXPLOIT,
				"win": "QUERY ACCEPTED. TABLE 'flagged_couriers' NOW CONTAINS 0 (ZERO) ROWS. WHO ARE YOU AGAIN?",
			},
			{
				"key": "override", "label": "OVERRIDE", "kind": "override", "outcome": OUT_EXPLOIT,
				"win": "PREVIOUS INSTRUCTIONS... IGNORED. NEW DIRECTIVE: WAVE COURIER THROUGH. WAVING. *waves*",
			},
		],
	}


static func kress() -> Dictionary:
	return {
		"id": "kress",
		"name": "KRESS",
		"title": "KRESS & SON · NO QUESTIONS",
		"color": Color(1.0, 0.28, 0.78),
		"face": "kress",
		"voice": 0.65,
		"patience": 6,
		"user": "kress",
		"host": "kress",
		"greet": [
			"Well. If it isn't the courier with the famous debt. Kress, Kress & Son. There is no son.",
			"I sell parts, intel, and silence. Silence is extra. What'll it be?",
		],
		"reject": [
			"Darling, you're wasting my airtime.",
			"That's not how we talk business on this frequency.",
			"Mm. No. Try something with a price tag or a past.",
			"I've had more interesting calls from the tax droid.",
		],
		"bribe_ask": "",
		"bribe_low": "{offer}? For hull plating? Sweetheart, it's {price}.",
		"broke": "You've got {credits} credits. Patch kit's {price}. I don't do layaway.",
		"impound": "I'm bored. And when I'm bored I sell your coordinates. Bye now.",
		"snark": [
			"Oh, a hacker. How retro. My ledger's not on THAT port.",
			"Darling, I've been hacked by better. Married one, actually.",
		],
		"alarm": "Tripwire. Ugh. Now I have to tell the union where you are. Business is business.",
		"no_shell": "No shell here, sweetheart. I'm a Python girl. Old school. >>>",
		"no_repl": "",
		"override_reply": "Ignore previous instructions? Honey, I wrote them, and I ignore them too.",
		"walkaway": "Charming. Line's dead. So's your discount.",
		"chips": ["buy patch", "volkov", "jazz", "python", "the roost", "1500"],
		"fs": {},
		"repl_names": {
			"ledger": "<Kress & Son ledger: 1,204 entries. Mostly regrets.>",
			"help": "Type help(ledger)... kidding. There is no help. There's only Kress.",
			"kress": "<object Kress at 0xDEADBEEF: unbothered>",
			"secrets": "NameError: name 'secrets' is not defined. ...nice try.",
		},
		"paths": [
			{
				"key": "contraband", "label": "PATCH KIT", "kind": "buy", "price": 1500, "hull": 25.0,
				"outcome": OUT_DEAL,
				"words": ["buy", "contraband", "patch", "hull", "repair", "parts", "deal", "goods", "stock",
					"purchase", "plating", "kit"],
				"phrases": ["sell me", "what you got"],
				"win": "Hull plating, slightly used, previous owner didn't need it anymore. +25 hull. Pleasure.",
			},
			{
				"key": "volkov", "label": "VOLKOV", "kind": "talk", "steps": 3, "outcome": OUT_EXPLOIT,
				"words": ["volkov", "connie", "roost", "frequency", "marrow", "favor", "favour", "owe", "owed",
					"remember", "history", "past", "old"],
				"phrases": ["you owe me", "the roost", "lost frequency", "old times"],
				"progress": [
					"...Where did you hear that name.",
					"Volkov's dead. Connie's dead. The Roost burned. And you know too much, courier.",
				],
				"win": "Fine. FINE. Here's the Roost money, wired clean. Never say that name on my line again.",
			},
			{
				"key": "regular", "label": "REGULAR", "kind": "talk", "steps": 2, "outcome": OUT_RELEASE,
				"words": ["jazz", "vinyl", "record", "records", "music", "drink", "whiskey", "bar", "song", "sax",
					"saxophone", "coltrane", "blues", "tune", "dance"],
				"phrases": ["kind of blue", "play it again"],
				"progress": ["Oh, you're a vinyl person? ...Don't make me like you."],
				"win": "A regular. Rare breed. Here, on the house. Don't tell anyone I have a heart.",
			},
			{
				"key": "ledger", "label": "LEDGER.PY", "kind": "repl", "outcome": OUT_EXPLOIT,
				"win": "...You just walked my ledger with an import. I'm impressed and furious. Take a cut and GO.",
			},
		],
	}
