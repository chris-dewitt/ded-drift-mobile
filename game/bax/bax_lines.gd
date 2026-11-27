extends RefCounted
## Bax line banks for flight. Cockney, sarcastic, on your side. Tone reference:
## docs/BAX_VOICE.md in the original Dead-Drift repo.

const FIRST_SECTOR := [
	"Right, guv. Left thumb points us, right thumb pushes. Try not to hit anythin' expensive.",
]
const SECTOR_START := [
	"Sector %d. Smells like debt in here.",
	"Sector %d. Same rusty bucket, fresh new ways to die.",
	"Sector %d. Keep the pointy end forward, yeah?",
]
const SLINGSHOT := [
	"Ooh, lovely slingshot! Engines are singin', guv.",
	"Whipped round that like a pro. Overdrive's yours.",
	"Gravity, mate. Free speed. Nobody bills you for it. Yet.",
]
const BARGE_SPOTTED := [
	"Repo barge! Local 404. Gary's lot. Leg it!",
	"Union barge inbound. They've got paperwork AND harpoons.",
]
const CLAMPED := [
	"They've harpooned us! Thrust away hard or shoot the barge!",
	"Tether's on! Pull, guv, PULL! Or shoot it, that works too.",
]
const SNAPPED := [
	"Tether snapped! Ha! Tell Gary to file a grievance.",
	"Free! That harpoon's comin' out of his overtime.",
]
const STUNNED := [
	"Barge is seein' stars. Go, go, go!",
	"That's a stunned barge. Bit of salvage for us, ta.",
]
const HULL_LOW := [
	"Hull's under thirty. I can see space through the floor, guv.",
]
const CORE := [
	"That's a gravity well, not a car wash!",
	"Mind the singularity, it doesn't do refunds.",
]
const RAIDERS := [
	"Krellborn raiders! Pirates with dental plans. Shoot 'em!",
	"Pirate fighters, guv. They're fast, but they're made of tinfoil.",
]
const DRONES := [
	"Compliance drones. Little flying fines. Don't let 'em touch us!",
	"Nova Soma drones inbound. They explode. Like their interest rates.",
]
const ALERTED := [
	"Every barge in the sector's got our plates thanks to that alarm. Fly like you mean it!",
]
const JUMP_READY := [
	"Gate's hot! Hit JUMP when you're clear.",
]
const JUMP_CLAMPED := [
	"Can't jump with a harpoon in us! Snap it first.",
]
const PATCH := [
	"Patch kit. Duct tape of the gods.",
]
const SCRAP := [
	"Scrap! That's... four percent of one payment. Lovely.",
	"More scrap. We're practically landed gentry.",
]


# --- terminal -------------------------------------------------------------
const TERMINAL := {
	"open": ["Right, let me do the talkin'. Kidding. You type. I'll judge."],
	"progress": ["Ooh, that landed. Keep pullin' that thread.", "They're warmin' up. Don't get clever now."],
	"reject": ["Nope. Read the dossier, guv, it's right there.", "That went down like a lead balloon."],
	"systems_fail": ["Careful! Three strikes and the alarm goes.", "They saw that comin' a mile off."],
	"shell": ["A shell! Have a nose around. ls, cd, cat. Mind the sudo."],
	"repl": ["Python, is it? Go on then, hacker. Try an import."],
	"bribe_ask": ["Name a number. Not a big one. We're poor."],
	"broke": ["We can't afford that, guv. We can't afford anythin'."],
	"override_fail": ["That trick only works on robots, mate."],
	"outcome_exploit": ["EXPLOIT! Ha! Five grand and they thanked us for it!"],
	"outcome_release": ["Released! Polite AND paid. Who are you?"],
	"outcome_bribed": ["Paid off. Cheaper than a funeral. Slightly."],
	"outcome_deal": ["New plating! Smells like the previous owner's regrets."],
	"outcome_impound": ["Impounded! Lovely. Half our credits, gone. Brilliant."],
	"outcome_alarm": ["ALARM! Every barge in the sector's comin' for us now!"],
	"outcome_walkaway": ["...Well. That's one way to end a call."],
}


static func terminal(beat: String) -> String:
	var bank: Array = TERMINAL.get(beat, [])
	return pick(bank) if not bank.is_empty() else ""


static func pick(bank: Array) -> String:
	return bank[randi() % bank.size()]


static func sector_start(sector: int) -> String:
	if sector <= 1:
		return pick(FIRST_SECTOR)
	return pick(SECTOR_START) % sector
