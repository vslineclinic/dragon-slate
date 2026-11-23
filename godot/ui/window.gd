extends RefCounted
## PC 창: 첫 실행 때 작업 영역의 85% 크기(16:9)로 가운데에 연다. F11로 전체 화면을 켜고 끈다.


static func fit_first_time() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var height: int = int(usable.size.y * 0.85)
	var width: int = int(height * 16.0 / 9.0)
	if width > usable.size.x * 0.85:
		width = int(usable.size.x * 0.85)
		height = int(width * 9.0 / 16.0)
	DisplayServer.window_set_size(Vector2i(width, height))
	DisplayServer.window_set_position(usable.position + (usable.size - Vector2i(width, height)) / 2)


static func handle_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_F11:
		return false
	if OS.has_feature("mobile"):
		return false
	var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	return true
