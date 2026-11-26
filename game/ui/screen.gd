extends RefCounted
## Screen helpers shared by HUD, touch controls and menus.


## Safe area (camera cut-out, rounded corners) in canvas coordinates.
## Only meaningful on phones; on desktop the whole view is safe.
static func safe_rect(vp: Viewport) -> Rect2:
	var view := vp.get_visible_rect()
	if not OS.has_feature("mobile"):
		return view
	var screen_safe := Rect2(DisplayServer.get_display_safe_area())
	if not screen_safe.has_area():
		return view
	var to_canvas := vp.get_final_transform().affine_inverse()
	var safe: Rect2 = to_canvas * screen_safe
	var clipped := safe.intersection(view)
	return clipped if clipped.has_area() else view
