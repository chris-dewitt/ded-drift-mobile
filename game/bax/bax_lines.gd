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


static func pick(bank: Array) -> String:
	return bank[randi() % bank.size()]


static func sector_start(sector: int) -> String:
	if sector <= 1:
		return pick(FIRST_SECTOR)
	return pick(SECTOR_START) % sector
