extends RefCounted
## Per-sector tuning for the five sectors of a chapter.

const NAMES := ["THE SHALLOWS", "SLAG BELT", "GRAVE ORBIT", "404 TERRITORY", "NOVA SOMA APPROACH"]
const DURATION := [40.0, 48.0, 56.0, 64.0, 72.0]
const WELLS := [2, 3, 3, 4, 4]
const DEBRIS := [10, 14, 17, 20, 24]
const PICKUPS := [5, 5, 4, 4, 4]
const BARGES := [1, 1, 1, 2, 2]
const BARGE_DELAY := [20.0, 8.0, 6.0, 5.0, 4.0]  # sector 1: barge shows up halfway


static func for_sector(sector: int) -> Dictionary:
	var i := clampi(sector, 1, 5) - 1
	return {
		"name": NAMES[i],
		"duration": DURATION[i],
		"wells": WELLS[i],
		"debris": DEBRIS[i],
		"pickups": PICKUPS[i],
		"barges": BARGES[i],
		"barge_delay": BARGE_DELAY[i],
	}
