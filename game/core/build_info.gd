extends RefCounted
## Build identity shown on screen so playtest feedback names an exact build.
## CI rewrites BUILD and COMMIT before export; local runs stay "dev"/"local".

const VERSION := "0.2.0"
const BUILD := "dev"
const COMMIT := "local"


static func label() -> String:
	return "v%s · %s" % [VERSION, BUILD]


static func full_label() -> String:
	return "v%s · %s · %s" % [VERSION, BUILD, COMMIT]
