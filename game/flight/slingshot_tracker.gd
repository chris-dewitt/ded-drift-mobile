extends RefCounted
## Detects a slingshot: the ship enters a well's band, dives close to the core
## without hitting it, and exits with real speed. One tracker per well.

const CLOSE_FACTOR := 2.6
const MIN_EXIT_SPEED := 140.0

var band := 200.0
var core := 50.0
var inside := false
var min_r := INF
var spoiled := false


func _init(band_radius := 200.0, core_radius := 50.0) -> void:
	band = band_radius
	core = core_radius


## Call every step with the ship's distance to the well centre and its speed.
## Returns true exactly once, on the step the ship exits after a good pass.
func update(r: float, speed: float) -> bool:
	if not inside:
		if r < band:
			inside = true
			spoiled = false
			min_r = r
		return false
	min_r = minf(min_r, r)
	if r < band:
		return false
	inside = false
	return not spoiled and min_r < core * CLOSE_FACTOR and speed >= MIN_EXIT_SPEED


## The ship hit the core: this pass can't count.
func cancel() -> void:
	spoiled = true
